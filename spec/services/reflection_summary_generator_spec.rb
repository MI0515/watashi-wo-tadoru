require "rails_helper"

RSpec.describe ReflectionSummaryGenerator do
  let(:reflection) { create(:reflection) }
  let(:client) { instance_double(OpenaiClient) }
  let(:service) { described_class.new(reflection: reflection, client: client) }
  let(:summary) do
    {
      "title" => "友達との会話で残った気持ち",
      "insight" => "言葉の内容より、話の聞かれ方が気になっていたのかもしれない"
    }
  end
  let(:usage) do
    instance_double(
      OpenAI::Models::Responses::ResponseUsage,
      input_tokens: 100,
      output_tokens: 60
    )
  end
  let(:response) do
    instance_double(
      OpenAI::Models::Responses::Response,
      id: "response-summary-test",
      usage: usage,
      output_text: summary.to_json
    )
  end

  before do
    allow(client).to receive(:call).and_return(response)
  end

  it "対話記録と文体を渡して2項目を取得し、まとめの使用量を記録する" do
    create(:reflection_message, reflection: reflection, position: 1)
    create(
      :reflection_message,
      reflection: reflection,
      role: :user,
      position: 2,
      content: "話を聞いてほしかった"
    )

    expect(client).to receive(:call) do |instructions:, input:, text_format:|
      expect(instructions).to include("やわらかく落ち着いたタメ口")
      record = JSON.parse(input.sole.fetch(:content))
      expect(record.fetch("initial_text")).to eq(reflection.initial_text)
      expect(record.fetch("messages").map { |message| message.fetch("role") })
        .to eq(%w[assistant user])
      expect(record.fetch("messages").last.fetch("content"))
        .to eq("話を聞いてほしかった")
      expect(text_format.fetch(:schema).fetch(:required))
        .to eq(%w[title insight])
      response
    end

    expect(service.call).to eq(summary)

    log = reflection.api_usage_logs.sole
    expect(log).to be_request_kind_summary
    expect(log).to be_status_succeeded
    expect(log.initial_reply).to be false
    expect(log.input_tokens).to eq(100)
    expect(log.output_tokens).to eq(60)
  end

  [
    "JSONではない",
    '{"title":"項目不足"}',
    '{"title":"題","insight":1}'
  ].each do |text|
    it "不正なまとめ形式を失敗として記録する（#{text}）" do
      allow(response).to receive(:output_text).and_return(text)

      expect {
        service.call
      }.to raise_error(OpenaiClient::ResponseError)

      log = reflection.api_usage_logs.sole
      expect(log).to be_status_failed
      expect(log.output_tokens).to eq(60)
    end
  end

  it "全体停止中はまとめ生成でも通信と履歴作成をしない" do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("AI_ENABLED", "true").and_return("false")
    expect(client).not_to receive(:call)

    expect {
      expect {
        service.call
      }.to raise_error(AiUsagePolicy::StoppedError)
    }.not_to change(ApiUsageLog, :count)
  end
end
