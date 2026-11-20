require "rails_helper"

RSpec.describe "振り返りのまとめ", type: :request do
  let(:companion) { create(:companion) }
  let(:user) do
    create(
      :user,
      nickname: "七海",
      personality_type: companion.personality_type,
      companion: companion
    )
  end
  let(:reflection) do
    create(
      :reflection,
      user: user,
      companion: companion,
      title: "会話のあとに残った気持ち",
      insight: "自分の話も聞いてほしかったのかもしれない"
    )
  end

  before do
    expect(OpenaiClient).not_to receive(:new)

    post user_session_path, params: {
      user: { email: user.email, password: "test123" }
    }
  end

  it "保存済みのまとめと元の入力・選択感情・メモ欄を表示する" do
    emotion = create(:emotion, name: "モヤモヤ")
    reflection.emotions << emotion

    get reflection_summary_path(reflection)

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css(".summary-title").text).to eq(reflection.title)
    expect(page.css(".summary-content").map(&:text))
      .to eq([ reflection.initial_text, reflection.insight ])
    expect(page.css(".feeling-tags li").map(&:text)).to eq([ "モヤモヤ" ])
    expect(page.at_css('textarea[name="reflection[personal_note]"]')).to be_present
    expect(page.at_css('a[href="' + reflection_path(reflection) + '"]').text)
      .to eq("対話に戻る")
    expect(page.at_css('input[type="submit"]')["value"])
      .to eq("保存してホームへ")
  end

  it "メモを保存して振り返りを完了し、ホームへ移動する" do
    patch reflection_summary_path(reflection), params: {
      reflection: { personal_note: "次は自分の話もしてみたい" }
    }

    expect(response).to redirect_to(home_path)
    expect(response).to have_http_status(:see_other)
    expect(reflection.reload).to be_completed
    expect(reflection.personal_note).to eq("次は自分の話もしてみたい")
    expect(reflection.completed_at).to be_present
    expect(flash[:notice]).to eq("振り返りを保存しました。")
  end

  it "401文字のメモではエラーと入力内容を表示し、完了しない" do
    note = "あ" * 401

    patch reflection_summary_path(reflection), params: {
      reflection: { personal_note: note }
    }

    expect(response).to have_http_status(:unprocessable_content)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css("#error_explanation").text)
      .to include("メモは400文字以内で入力してください")

    # Railsがtextareaの先頭に付ける改行だけを除き、入力内容が保持されているか確認する
    expect(page.at_css("#reflection-personal-note").text.delete_prefix("\n"))
      .to eq(note)
    expect(reflection.reload).to be_in_progress
    expect(reflection.personal_note).to be_nil
    expect(reflection.completed_at).to be_nil
  end

  context "AI④の返信を取得したあと" do
    let(:generator) { instance_double(ReflectionSummaryGenerator) }
    let(:summary) do
      {
        "title" => "会話のあと",
        "insight" => "話を聞いてほしかったのかもしれない"
      }
    end

    before do
      reflection.update!(title: nil, insight: nil)
      7.times do |index|
        create(
          :reflection_message,
          reflection: reflection,
          role: index.even? ? :assistant : :user,
          position: index + 1
        )
      end
      allow(ReflectionSummaryGenerator).to receive(:new).and_return(generator)
      allow(generator).to receive(:call).and_return(summary)
    end

    it "入力欄の代わりにまとめるボタンを表示する" do
      get reflection_path(reflection)

      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML(response.body)
      expect(page.at_css("#reflection-reply")).to be_nil
      expect(page.at_css('form[action="' + reflection_summary_path(reflection) + '"]'))
        .to be_present
      expect(page.text).to include("ここまでの気持ちをまとめてみる？")
    end

    it "上限に達する前は返信欄を表示する" do
      reflection.reflection_messages.where(position: [ 6, 7 ]).destroy_all

      get reflection_path(reflection)

      page = Nokogiri::HTML(response.body)
      expect(page.at_css("#reflection-reply")).to be_present
      expect(page.at_css('form[action="' + reflection_summary_path(reflection) + '"]'))
        .to be_nil
    end

    it "まとめを生成して確認画面へ移動し、対話画面から再確認できる" do
      expect(generator).to receive(:call).once.with(retrying: false).and_return(summary)

      post reflection_summary_path(reflection)

      expect(response).to redirect_to(reflection_summary_path(reflection))
      expect(reflection.reload.attributes.slice(*summary.keys)).to eq(summary)
      expect(reflection).to be_in_progress
      follow_redirect!
      expect(response).to have_http_status(:ok)

      get reflection_path(reflection)

      page = Nokogiri::HTML(response.body)
      expect(page.at_css('a[href="' + reflection_summary_path(reflection) + '"]').text)
        .to eq("まとめを確認する")
      expect(page.at_css("#reflection-reply")).to be_nil
    end

    it "生成失敗後に再試行ボタンを表示し、再送でまとめを取得できる" do
      error = OpenaiClient::ResponseError.new("形式不正", response: nil)
      allow(generator).to receive(:call).and_raise(error)

      post reflection_summary_path(reflection)

      expect(response).to redirect_to(reflection_summary_path(reflection))
      expect(reflection.reload).to be_ai_response_failed
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("もう一度まとめる")

      get reflection_path(reflection)
      expect(response.body).to include("もう一度まとめる")
      expect(response.body).not_to include("もう一度返答を受け取る")

      allow(generator).to receive(:call).and_return(summary)
      post reflection_summary_path(reflection)

      expect(response).to redirect_to(reflection_summary_path(reflection))
      expect(reflection.reload).to be_summary_available
      expect(reflection).to be_ai_response_idle
    end
  end

  it "未ログインではまとめの表示・生成・保存を受け付けない" do
    path = reflection_summary_path(reflection)
    delete destroy_user_session_path

    get path
    expect(response).to redirect_to(new_user_session_path)
    post path
    expect(response).to redirect_to(new_user_session_path)
    patch path, params: { reflection: { personal_note: "保存しない" } }
    expect(response).to redirect_to(new_user_session_path)
    expect(reflection.reload).to be_in_progress
    expect(reflection.personal_note).to be_nil
  end

  it "他の利用者のまとめは表示・生成・保存できない" do
    other_reflection = create(
      :reflection,
      user: create(:user),
      companion: companion
    )
    path = reflection_summary_path(other_reflection)

    get path
    expect(response).to have_http_status(:not_found)
    post path
    expect(response).to have_http_status(:not_found)
    patch path, params: { reflection: { personal_note: "保存しない" } }
    expect(response).to have_http_status(:not_found)
    expect(other_reflection.reload).to be_in_progress
    expect(other_reflection.personal_note).to be_nil
  end
end
