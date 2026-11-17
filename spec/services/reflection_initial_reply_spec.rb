require "rails_helper"

RSpec.describe ReflectionInitialReply do
  let(:reflection) { create(:reflection) }
  let(:dialogue) { instance_double(ReflectionDialogue) }
  let(:response) do
    instance_double(
      OpenAI::Models::Responses::Response,
      output_text: "最初のAIの返答"
    )
  end
  let(:service) do
    described_class.new(reflection: reflection, dialogue: dialogue)
  end

  it "最初のAI返答だけを発言順1番として保存する" do
    expect(dialogue).to receive(:call).with(no_args).and_return(response)
    reflection

    expect {
      service.call
    }.to change(ReflectionMessage, :count).by(1)

    message = reflection.reflection_messages.sole

    expect(message).to be_assistant
    expect(message.position).to eq(1)
    expect(message.content).to eq("最初のAIの返答")
    expect(reflection.reflection_messages.where(role: :user)).to be_empty
    expect(reflection.reload).to be_ai_response_idle
    expect(reflection.ai_response_started_at).to be_nil
  end

  it "保存済みなら再生成・追加保存せず、既存の初回返答を返す" do
    existing = create(
      :reflection_message,
      reflection: reflection,
      role: :assistant,
      position: 1
    )
    expect(dialogue).not_to receive(:call)

    expect {
      expect(service.call).to eq(existing)
    }.not_to change(ReflectionMessage, :count)
  end

  it "生成に失敗した場合は返答を保存せず、振り返り自体は残す" do
    error = OpenAI::Errors::APITimeoutError.new(
      url: URI("https://api.openai.com/v1/responses")
    )
    allow(dialogue).to receive(:call).and_raise(error)
    reflection

    expect {
      expect {
        service.call
      }.to raise_error(OpenAI::Errors::APITimeoutError)
    }.not_to change(ReflectionMessage, :count)

    expect(reflection.reload).to be_persisted
    expect(reflection).to be_ai_response_failed
    expect(reflection.ai_response_started_at).not_to be_nil
  end

  it "生成中の別リクエストを拒否し、進行中の生成状態を変更しない" do
    expect(dialogue).to receive(:call).once do
      expect(reflection.reload).to be_ai_response_processing
      started_at = reflection.ai_response_started_at
      expect(started_at).not_to be_nil

      other_service = described_class.new(
        reflection: Reflection.find(reflection.id),
        dialogue: dialogue
      )

      expect {
        other_service.call
      }.to raise_error(described_class::InProgressError)

      expect(reflection.reload).to be_ai_response_processing
      expect(reflection.ai_response_started_at).to eq(started_at)

      response
    end

    expect {
      service.call
    }.to change(ReflectionMessage, :count).by(1)

    expect(reflection.reload).to be_ai_response_idle
    expect(reflection.ai_response_started_at).to be_nil
  end
end
