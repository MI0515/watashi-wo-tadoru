require "rails_helper"

RSpec.describe ReflectionDialogue do
  let(:reflection) { create(:reflection) }
  let(:client) { instance_double(OpenaiClient) }
  let(:response) { instance_double(OpenAI::Models::Responses::Response) }
  let(:service) { described_class.new(reflection: reflection, client: client) }

  before do
    allow(client).to receive(:call).and_return(response)
  end

  it "感情未選択では初回入力を1回だけ送り、取得した返答を返す" do
    expect(client).to receive(:call).with(
      instructions: ReflectionPrompt.call(speaking_style: "casual"),
      input: [
        {
          role: :user,
          content: "選択した感情：なし\n\n最初の入力：\n#{reflection.initial_text}"
        }
      ]
    ).and_return(response)

    expect(service.call).to equal(response)
  end

  it "選択感情を表示順に並べて渡す" do
    later = create(:emotion, name: "不安", display_order: 2)
    earlier = create(:emotion, name: "モヤモヤ", display_order: 1)
    reflection.emotions = [ later, earlier ]

    expect(client).to receive(:call) do |instructions:, input:|
      expect(input.first[:content]).to start_with("選択した感情：モヤモヤ・不安")
    end

    service.call
  end

  it "対象の振り返りの履歴だけを発言順に並べ、役割と本文をそのまま渡す" do
    create(
      :reflection_message,
      reflection: reflection,
      role: :user,
      position: 2,
      content: "相談してほしかった。\n一方的だったのが嫌だった。"
    )
    create(
      :reflection_message,
      reflection: reflection,
      role: :assistant,
      position: 1,
      content: "どんなところが引っかかった？"
    )

    another = create(
      :reflection,
      user: reflection.user,
      companion: reflection.companion
    )
    create(:reflection_message, reflection: another, content: "別の対話の内容")

    expect(client).to receive(:call) do |instructions:, input:|
      expect(input.size).to eq(3)
      expect(input.drop(1)).to eq(
        [
          { role: :assistant, content: "どんなところが引っかかった？" },
          {
            role: :user,
            content: "相談してほしかった。\n一方的だったのが嫌だった。"
          }
        ]
      )
    end

    service.call
  end

  it "設定変更後も開始時のミツメイトの文体を使い、最終返信の指定を反映する" do
    reflection.companion.update!(speaking_style: "polite")

    other_companion = create(
      :companion,
      personality_type: reflection.companion.personality_type,
      appearance_type: "female",
      speaking_style: "casual"
    )
    reflection.user.update!(companion: other_companion)

    expect(client).to receive(:call) do |instructions:, input:|
      expect(instructions).to eq(
        ReflectionPrompt.call(speaking_style: "polite", final_reply: true)
      )
    end

    service.call(final_reply: true)
  end

  it "返答を取得してもメッセージを保存せず、振り返りを変更しない" do
    reflection
    before_attributes = reflection.attributes

    expect {
      service.call
    }.not_to change(ReflectionMessage, :count)

    expect(reflection.reload.attributes).to eq(before_attributes)
  end

  it "通信処理のエラーをそのまま呼び出し元へ伝える" do
    error = OpenAI::Errors::APITimeoutError.new(
      url: URI("https://api.openai.com/v1/responses")
    )
    allow(client).to receive(:call).and_raise(error)

    expect {
      service.call
    }.to raise_error(OpenAI::Errors::APITimeoutError) { |raised|
      expect(raised).to equal(error)
    }
  end
end
