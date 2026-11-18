require "rails_helper"

RSpec.describe ReflectionRetry do
  let(:reflection) { create(:reflection, ai_response_status: :failed) }
  let(:dialogue) { instance_double(ReflectionDialogue) }
  let(:response) do
    instance_double(
      OpenAI::Models::Responses::Response,
      output_text: "再試行で生成したAIの返答"
    )
  end
  let(:service) do
    described_class.new(reflection: reflection, dialogue: dialogue)
  end
  let(:user_message) do
    create(:reflection_message, reflection: reflection, position: 1)
    create(
      :reflection_message,
      reflection: reflection,
      role: :user,
      content: "相談してほしかった",
      position: 2
    )
  end

  before do
    allow(dialogue).to receive(:call).and_return(response)
  end

  it "初回返信の失敗では、最初のAI返信だけを保存する" do
    reflection

    expect {
      service.call(last_message_id: nil)
    }.to change(ReflectionMessage, :count).by(1)

    message = reflection.reflection_messages.sole

    expect(message).to be_assistant
    expect(message.position).to eq(1)
    expect(message.content).to eq("再試行で生成したAIの返答")
    expect(reflection.reload).to be_ai_response_idle
    expect(reflection.ai_response_started_at).to be_nil
  end

  it "追加返信の失敗では利用者の発言を増やさず、成功後の同じ再試行を拒否する" do
    message_id = user_message.id.to_s
    expect(dialogue).to receive(:call).once.and_return(response)

    expect {
      service.call(last_message_id: message_id)
    }.to change(ReflectionMessage, :count).by(1)

    expect(reflection.reflection_messages.where(role: :user).count).to eq(1)

    reply = reflection.reflection_messages.order(:position).last
    expect(reply).to be_assistant
    expect(reply.position).to eq(3)

    expect {
      expect {
        service.call(last_message_id: message_id)
      }.to raise_error(described_class::NotReadyError)
    }.not_to change(ReflectionMessage, :count)

    expect(reflection.reload).to be_ai_response_idle
  end

  it "再試行中の別リクエストを拒否し、元の生成状態を変更しない" do
    message_id = user_message.id

    expect(dialogue).to receive(:call).once.with(final_reply: false, retrying: true) do
      expect(reflection.reload).to be_ai_response_processing
      started_at = reflection.ai_response_started_at
      expect(started_at).not_to be_nil

      other_service = described_class.new(
        reflection: Reflection.find(reflection.id),
        dialogue: dialogue
      )

      expect {
        expect {
          other_service.call(last_message_id: message_id)
        }.to raise_error(described_class::InProgressError)
      }.not_to change(ReflectionMessage, :count)

      expect(reflection.reload).to be_ai_response_processing
      expect(reflection.ai_response_started_at).to eq(started_at)

      response
    end

    expect {
      service.call(last_message_id: message_id)
    }.to change(ReflectionMessage, :count).by(1)

    expect(reflection.reload).to be_ai_response_idle
  end

  it "再試行も通信に失敗した場合、保存済みの発言を残して失敗状態へ戻す" do
    message_id = user_message.id
    error = OpenAI::Errors::APITimeoutError.new(
      url: URI("https://api.openai.com/v1/responses")
    )
    allow(dialogue).to receive(:call).and_raise(error)

    expect {
      expect {
        service.call(last_message_id: message_id)
      }.to raise_error(OpenAI::Errors::APITimeoutError)
    }.not_to change(ReflectionMessage, :count)

    expect(reflection.reload).to be_ai_response_failed
    expect(reflection.ai_response_started_at).not_to be_nil
    expect(reflection.reflection_messages.order(:position).last)
      .to eq(user_message)
  end

  it "現在の最後の発言とIDが違う場合は再試行しない" do
    user_message
    old_message_id = reflection.reflection_messages.find_by(position: 1).id
    expect(dialogue).not_to receive(:call)

    expect {
      expect {
        service.call(last_message_id: old_message_id)
      }.to raise_error(described_class::NotReadyError)
    }.not_to change(ReflectionMessage, :count)

    expect(reflection.reload).to be_ai_response_failed
  end

  it "完了済みの振り返りでは再試行しない" do
    reflection.update!(status: :completed)
    expect(dialogue).not_to receive(:call)

    expect {
      expect {
        service.call(last_message_id: nil)
      }.to raise_error(described_class::NotReadyError)
    }.not_to change(ReflectionMessage, :count)
  end

  it "失敗状態でない場合は再試行しない" do
    reflection.update!(ai_response_status: :idle)
    expect(dialogue).not_to receive(:call)

    expect {
      expect {
        service.call(last_message_id: nil)
      }.to raise_error(described_class::NotReadyError)
    }.not_to change(ReflectionMessage, :count)
  end
end
