require "rails_helper"

RSpec.describe ReflectionSummary do
  let(:reflection) { create(:reflection) }
  let(:generator) { instance_double(ReflectionSummaryGenerator) }
  let(:service) { described_class.new(reflection: reflection, generator: generator) }
  let(:summary) do
    {
      "title" => "会話のあとに残った気持ち",
      "valued_thing" => "自分の話も聞いてほしかった",
      "insight" => "話の聞かれ方が気になっていたのかもしれない"
    }
  end

  before do
    allow(generator).to receive(:call).and_return(summary)
  end

  it "まとめを保存して対話中のままにし、再送で生成し直さない" do
    prepare_dialogue
    expect(generator).to receive(:call).once.with(retrying: false).and_return(summary)

    expect {
      expect(service.call).to eq(reflection)
      service.call
    }.not_to change(ReflectionMessage, :count)

    expect(reflection.reload.attributes.slice(*summary.keys)).to eq(summary)
    expect(reflection).to be_summary_available
    expect(reflection).to be_in_progress
    expect(reflection.completed_at).to be_nil
    expect(reflection).to be_ai_response_idle
  end

  it "生成中の別リクエストを拒否しても元の生成を失敗にしない" do
    prepare_dialogue

    expect(generator).to receive(:call).once do
      other = described_class.new(
        reflection: Reflection.find(reflection.id),
        generator: generator
      )
      expect { other.call }.to raise_error(described_class::InProgressError)
      expect(reflection.reload).to be_ai_response_processing
      summary
    end

    service.call

    expect(reflection.reload).to be_summary_available
    expect(reflection).to be_ai_response_idle
  end

  it "生成失敗ではまとめを保存せず、履歴がある場合は再試行として生成する" do
    prepare_dialogue
    error = OpenAI::Errors::APITimeoutError.new(
      url: URI("https://api.openai.com/v1/responses")
    )
    allow(generator).to receive(:call).and_raise(error)

    expect { service.call }.to raise_error(OpenAI::Errors::APITimeoutError)
    expect(reflection.reload).to be_ai_response_failed
    expect(reflection).not_to be_summary_available

    # 生成処理は代役なので、実際の失敗時に残るAPI履歴を用意する
    create(
      :api_usage_log,
      user: reflection.user,
      reflection: reflection,
      request_kind: :summary,
      initial_reply: false,
      status: :timed_out,
      response_id: nil,
      input_tokens: nil,
      output_tokens: nil
    )
    expect(generator).to receive(:call).with(retrying: true).and_return(summary)

    service.call

    expect(reflection.reload).to be_summary_available
    expect(reflection).to be_in_progress
  end

  it "通常対話の終了前には生成しない" do
    create(:reflection_message, reflection: reflection, position: 1)
    expect(generator).not_to receive(:call)

    expect { service.call }.to raise_error(described_class::NotReadyError)
    expect(reflection.reload).to be_ai_response_idle
  end

  def prepare_dialogue
    %w[assistant user assistant user assistant user assistant].each_with_index do |role, index|
      create(
        :reflection_message,
        reflection: reflection,
        role: role,
        position: index + 1
      )
    end
  end
end
