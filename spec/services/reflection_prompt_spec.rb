require "rails_helper"

RSpec.describe ReflectionPrompt do
  it "共通プロンプトを先頭に含める" do
    common_prompt = Rails.root.join("config/prompts/reflection.txt").read

    result = described_class.call(speaking_style: "casual")

    expect(result).to start_with(common_prompt)
  end

  it "タメ口と対話途中の指示を追加する" do
    result = described_class.call(speaking_style: "casual")

    expect(result).to include(
      "やわらかく落ち着いたタメ口で話してください。",
      "今回は対話途中の返信です。"
    )
    expect(result).not_to include("今回は通常対話の最終返信です。")
  end

  it "敬語の指定時にタメ口固定の指示を含めない" do
    result = described_class.call(speaking_style: "polite")

    expect(result).to include("やわらかく落ち着いた敬語で話してください。")
    expect(result).not_to include(
      "やわらかく落ち着いたタメ口で話してください。",
      "最終返信でも、落ち着いたタメ口"
    )
  end

  it "最終返信の指示でも安全上の例外を優先する" do
    result = described_class.call(speaking_style: "polite", final_reply: true)

    expect(result).to include(
      "今回は通常対話の最終返信です。",
      "【安全を優先する例外】は最終返信の制約より優先します。"
    )
    expect(result).not_to include("今回は対話途中の返信です。")
  end

  it "未対応の話し方を指定するとエラーになる" do
    expect {
      described_class.call(speaking_style: "unknown")
    }.to raise_error(KeyError)
  end
end
