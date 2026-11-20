require "rails_helper"

RSpec.describe ReflectionReply do
  let(:reflection) { create(:reflection) }
  let(:reply_to_id) do
    reflection.reflection_messages.find_by(position: 1)&.id
  end
  let(:dialogue) { instance_double(ReflectionDialogue) }
  let(:response) do
    instance_double(
      OpenAI::Models::Responses::Response,
      output_text: "次のAIの返答"
    )
  end
  let(:service) do
    described_class.new(reflection: reflection, dialogue: dialogue)
  end

  before do
    allow(dialogue).to receive(:call).and_return(response)
  end

  it "利用者の発言を先に保存し、AIの返答を次の発言順で保存する" do
    create(:reflection_message, reflection: reflection, position: 1)
    text = "相談してほしかった。\n一方的だったのが嫌だった。"

    expect(dialogue).to receive(:call).with(final_reply: false) do
      message = reflection.reflection_messages.order(:position).last
      expect(message).to be_user
      expect(message.content).to eq(text)
      response
    end

    result = nil

    expect {
      result = service.call(reply_to_id: reply_to_id, content: text)
    }.to change(ReflectionMessage, :count).by(2)

    expect(result).to be_assistant
    expect(result.position).to eq(3)
    expect(result.content).to eq("次のAIの返答")
    expect(reflection.reflection_messages.order(:position).pluck(:position))
      .to eq([ 1, 2, 3 ])

    expect(reflection.reload).to be_ai_response_idle
    expect(reflection.ai_response_started_at).to be_nil
  end

  [ "   ", "あ" * 401 ].each do |content|
    it "入力が空白だけ、または400文字超過なら保存・送信しない（#{content.length}文字）" do
      create(:reflection_message, reflection: reflection, position: 1)
      expect(dialogue).not_to receive(:call)

      expect {
        expect {
          service.call(reply_to_id: reply_to_id, content: content)
        }.to raise_error(ActiveRecord::RecordInvalid)
      }.not_to change(ReflectionMessage, :count)
    end
  end

  it "最初のAI返答がない場合は保存・送信しない" do
    reflection
    expect(dialogue).not_to receive(:call)

    expect {
      expect {
        service.call(reply_to_id: reply_to_id, content: "少し話したい")
      }.to raise_error(described_class::NotReadyError)
    }.not_to change(ReflectionMessage, :count)
  end

  it "最後の利用者の発言にAIが返答していなければ、追加の発言を保存・送信しない" do
    create(
      :reflection_message,
      reflection: reflection,
      role: :user,
      position: 1
    )
    expect(dialogue).not_to receive(:call)

    expect {
      expect {
        service.call(reply_to_id: reply_to_id, content: "もうひとこと")
      }.to raise_error(described_class::NotReadyError)
    }.not_to change(ReflectionMessage, :count)
  end

  it "完了済みの振り返りには保存・送信しない" do
    create(:reflection_message, reflection: reflection, position: 1)
    reflection.update!(status: :completed)
    expect(dialogue).not_to receive(:call)

    expect {
      expect {
        service.call(reply_to_id: reply_to_id, content: "もうひとこと")
      }.to raise_error(described_class::NotReadyError)
    }.not_to change(ReflectionMessage, :count)
  end

  it "通信に失敗しても利用者の発言は残す" do
    create(:reflection_message, reflection: reflection, position: 1)
    error = OpenAI::Errors::APITimeoutError.new(
      url: URI("https://api.openai.com/v1/responses")
    )
    allow(dialogue).to receive(:call).and_raise(error)

    expect {
      expect {
        service.call(reply_to_id: reply_to_id, content: "この入力を残したい")
      }.to raise_error(OpenAI::Errors::APITimeoutError)
    }.to change(ReflectionMessage, :count).by(1)

    message = reflection.reflection_messages.order(:position).last
    expect(message).to be_user
    expect(message.position).to eq(2)
    expect(message.content).to eq("この入力を残したい")
    expect(reflection.reload).to be_ai_response_failed
    expect(reflection.ai_response_started_at).not_to be_nil
  end

  it "3回目の追加返信では最終返信を指定する" do
    %w[assistant user assistant user assistant].each_with_index do |role, index|
      create(
        :reflection_message,
        reflection: reflection,
        role: role,
        position: index + 1
      )
    end
    last_message = reflection.reflection_messages.order(:position).last

    expect(dialogue).to receive(:call)
      .with(final_reply: true)
      .and_return(response)

    service.call(reply_to_id: last_message.id, content: "少し整理できた")
  end

  it "生成中の追加送信を拒否し、発言とAPI呼び出しを重複させない" do
    create(:reflection_message, reflection: reflection, position: 1)

    expect(dialogue).to receive(:call).once.with(final_reply: false) do
      expect(reflection.reload).to be_ai_response_processing
      started_at = reflection.ai_response_started_at
      expect(started_at).not_to be_nil

      other_service = described_class.new(
        reflection: Reflection.find(reflection.id),
        dialogue: dialogue
      )

      expect {
        expect {
          other_service.call(reply_to_id: reply_to_id, content: "重複した入力")
        }.to raise_error(described_class::InProgressError)
      }.not_to change(ReflectionMessage, :count)

      expect(reflection.reload).to be_ai_response_processing
      expect(reflection.ai_response_started_at).to eq(started_at)

      response
    end

    expect {
      service.call(reply_to_id: reply_to_id, content: "相談してほしかった")
    }.to change(ReflectionMessage, :count).by(2)

    expect(reflection.reload).to be_ai_response_idle
    expect(reflection.ai_response_started_at).to be_nil
  end
  it "返信完了後に同じ送信が届いても、発言とAPI呼び出しを重複させない" do
    first_reply = create(
      :reflection_message,
      reflection: reflection,
      position: 1
    )
    expect(dialogue).to receive(:call).once.and_return(response)

    service.call(content: "相談してほしかった", reply_to_id: first_reply.id)

    expect {
      expect {
        service.call(
          content: "相談してほしかった",
          reply_to_id: first_reply.id
        )
      }.to raise_error(described_class::NotReadyError)
    }.not_to change(ReflectionMessage, :count)

    expect(reflection.reload).to be_ai_response_idle
  end

  it "返信先IDが未指定なら保存・送信しない" do
    create(:reflection_message, reflection: reflection, position: 1)
    expect(dialogue).not_to receive(:call)

    expect {
      expect {
        service.call(content: "少し話したい", reply_to_id: nil)
      }.to raise_error(described_class::NotReadyError)
    }.not_to change(ReflectionMessage, :count)
  end

  it "4回目の追加返信は保存もAPI送信もしない" do
    %w[assistant user assistant user assistant user assistant].each_with_index do |role, index|
      create(
        :reflection_message,
        reflection: reflection,
        role: role,
        position: index + 1
      )
    end
    last_message = reflection.reflection_messages.order(:position).last
    expect(dialogue).not_to receive(:call)

    expect {
      expect {
        service.call(reply_to_id: last_message.id, content: "もうひとこと")
      }.to raise_error(described_class::LimitReachedError)
    }.not_to change(ReflectionMessage, :count)
  end
end
