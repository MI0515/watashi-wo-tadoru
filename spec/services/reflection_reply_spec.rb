require "rails_helper"

RSpec.describe ReflectionReply do
  let(:reflection) { create(:reflection) }
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
      result = service.call(content: text)
    }.to change(ReflectionMessage, :count).by(2)

    expect(result).to be_assistant
    expect(result.position).to eq(3)
    expect(result.content).to eq("次のAIの返答")
    expect(reflection.reflection_messages.order(:position).pluck(:position))
      .to eq([ 1, 2, 3 ])
  end

  [ "   ", "あ" * 401 ].each do |content|
    it "入力が空白だけ、または400文字超過なら保存・送信しない（#{content.length}文字）" do
      create(:reflection_message, reflection: reflection, position: 1)
      expect(dialogue).not_to receive(:call)

      expect {
        expect {
          service.call(content: content)
        }.to raise_error(ActiveRecord::RecordInvalid)
      }.not_to change(ReflectionMessage, :count)
    end
  end

  it "最初のAI返答がない場合は保存・送信しない" do
    reflection
    expect(dialogue).not_to receive(:call)

    expect {
      expect {
        service.call(content: "少し話したい")
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
        service.call(content: "もうひとこと")
      }.to raise_error(described_class::NotReadyError)
    }.not_to change(ReflectionMessage, :count)
  end

  it "完了済みの振り返りには保存・送信しない" do
    create(:reflection_message, reflection: reflection, position: 1)
    reflection.update!(status: :completed)
    expect(dialogue).not_to receive(:call)

    expect {
      expect {
        service.call(content: "もうひとこと")
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
        service.call(content: "この入力を残したい")
      }.to raise_error(OpenAI::Errors::APITimeoutError)
    }.to change(ReflectionMessage, :count).by(1)

    message = reflection.reflection_messages.order(:position).last
    expect(message).to be_user
    expect(message.position).to eq(2)
    expect(message.content).to eq("この入力を残したい")
  end

  it "最終返信の指定を対話サービスへ渡す" do
    create(:reflection_message, reflection: reflection, position: 1)

    expect(dialogue).to receive(:call)
      .with(final_reply: true)
      .and_return(response)

    service.call(content: "少し整理できた", final_reply: true)
  end
end
