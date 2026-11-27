require "rails_helper"

RSpec.describe "振り返りから記録の削除まで", type: :system do
  let(:companion) { create(:companion) }
  let!(:user) do
    create(
      :user,
      nickname: "七海",
      personality_type: companion.personality_type,
      companion: companion,
      onboarding_completed_at: Time.current
    )
  end
  let!(:emotion) { create(:emotion, name: "モヤモヤ") }
  let(:ai_client) { instance_double(OpenaiClient) }
  let(:summary_title) { "話を聞いてほしかった気持ち" }
  let(:summary_insight) { "相談なしで決められたことが引っかかっていた。" }
  let(:dialogue_texts) do
    [
      "どんな場面が思い浮かぶ？",
      "会話の進み方で気になったことはある？",
      "相手にはどうしてほしかった？",
      "決める前に相談してほしかったことが見えてきたね。"
    ]
  end
  let(:ai_responses) do
    texts = dialogue_texts + [
      { title: summary_title, insight: summary_insight }.to_json
    ]

    texts.each_with_index.map do |text, index|
      instance_double(
        OpenAI::Models::Responses::Response,
        id: "response-system-#{index}",
        usage: nil,
        output_text: text
      )
    end
  end

  before do
    # system specでも本物のAPIへ接続せず、固定の返答を順番に返す
    allow(OpenaiClient).to receive(:new).and_return(ai_client)
    allow(ai_client).to receive(:call).and_return(*ai_responses)

    visit new_user_session_path
    fill_in "メールアドレス", with: user.email
    fill_in "パスワード", with: "test123"
    click_button "ログイン"

    expect(page).to have_current_path(home_path)
    expect(page).to have_css(".hello", text: "おかえり、七海")
  end

  it "対話とまとめを保存し、一覧・詳細から確認して削除できる" do
    click_link "振り返りを始める"

    expect(page).to have_current_path(new_reflection_path)
    check "モヤモヤ", allow_label_click: true
    fill_in "今、どんなことが浮かんでる？",
            with: "友達と話したあと、モヤモヤした。"
    click_button "ミツメイトと振り返る"

    expect(page).to have_css(".message.assistant .bubble", text: dialogue_texts[0])

    replies = [
      "予定を変えられたときかも。",
      "相談なしで決められたのが嫌だった。",
      "決める前に一言聞いてほしかった。"
    ]

    replies.each_with_index do |reply, index|
      fill_in "ミツメイトへの返答", with: reply
      click_button "送信"

      expect(page).to have_css(
        ".message.assistant .bubble",
        text: dialogue_texts[index + 1]
      )
    end

    expect(page).to have_no_field("ミツメイトへの返答")
    click_button "まとめる"

    expect(page).to have_css(".summary-title", text: summary_title)
    expect(page).to have_content(summary_insight)
    expect(page).to have_css(".feeling-tags", text: "モヤモヤ")

    fill_in "自分の言葉で残しておきたいこと（任意）",
            with: "次は自分の希望も伝えたい。"
    click_button "保存してホームへ"

    expect(page).to have_current_path(home_path)
    expect(page).to have_content("振り返りを保存しました。")
    click_link "記録を見る"

    expect(page).to have_current_path(records_path)
    within(".record-list") do
      click_link text: summary_title
    end

    expect(page).to have_css("#record-title", text: summary_title)
    expect(page).to have_content("友達と話したあと、モヤモヤした。")
    expect(page).to have_content(summary_insight)
    expect(page).to have_content("次は自分の希望も伝えたい。")

    click_button "この記録を削除"

    expect(page).to have_css("dialog.delete-dialog[open]")
    within("dialog.delete-dialog") do
      click_button "削除する"
    end

    expect(page).to have_current_path(records_path)
    expect(page).to have_content("記録を削除しました。")
    expect(page).to have_content("保存した記録はまだありません。")
    expect(page).to have_no_css(".record-item")
    expect(ai_client).to have_received(:call).exactly(5).times
  end

  it "AIの呼び出しに失敗すると、入力内容を残してエラーと再試行ボタンを表示する" do
    allow(ai_client).to receive(:call).and_raise(
      OpenaiClient::ResponseError.new(
        "テスト用のAPIエラー",
        response: ai_responses.first
      )
    )

    click_link "振り返りを始める"

    expect(page).to have_current_path(new_reflection_path)
    fill_in "今、どんなことが浮かんでる？",
            with: "友達と話したあと、モヤモヤした。"
    click_button "ミツメイトと振り返る"

    expect(page).to have_css(
      ".initial-text",
      text: "友達と話したあと、モヤモヤした。"
    )

    within('.response-state[role="alert"]') do
      expect(page).to have_content(
        "返答を取得できませんでした。入力内容は会話に保存されています。"
      )
      expect(page).to have_button("もう一度返答を受け取る")
    end

    expect(ai_client).to have_received(:call).once
  end
end
