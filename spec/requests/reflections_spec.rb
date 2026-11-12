require "rails_helper"

RSpec.describe "振り返りの開始", type: :request do
  let(:companion) { create(:companion) }
  let(:user) do
    create(
      :user,
      nickname: "七海",
      personality_type: companion.personality_type,
      companion: companion
    )
  end

  before do
    post user_session_path, params: {
      user: { email: user.email, password: "test123" }
    }
  end

  it "開始画面に、登録済みの19件の感情を表示順で並べる" do
    emotions = 19.downto(1).map do |order|
      create(:emotion, display_order: order)
    end

    get new_reflection_path

    expect(response).to have_http_status(:ok)
    doc = response.parsed_body
    checkboxes = doc.css('input[type="checkbox"]')

    expect(checkboxes.map { |input| input["value"] })
      .to eq(emotions.reverse.map { |emotion| emotion.id.to_s })
    expect(doc.at_css("textarea")["maxlength"]).to eq("400")
    expect(doc.at_css(".helper").text)
      .to include("選ばずに進んでも大丈夫")
    expect(doc.at_css("#entry-ai-note").text).to include("OpenAI")
  end

  it "入力・複数の感情・開始時のミツメイトを保存して対話画面へ移動する" do
    emotions = create_list(:emotion, 2)
    initial_text = "今日は少し疲れた。\nひとりでゆっくりしたい。"

    expect {
      post reflections_path, params: {
        reflection: {
          initial_text: initial_text,
          emotion_ids: emotions.map(&:id)
        }
      }
    }.to change(Reflection, :count).by(1)
      .and change(ReflectionEmotion, :count).by(2)

    reflection = user.reflections.last
    expect(reflection.initial_text).to eq(initial_text)
    expect(reflection.companion).to eq(companion)
    expect(reflection.emotion_ids).to match_array(emotions.map(&:id))
    expect(reflection).to be_in_progress
    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(reflection_path(reflection))

    follow_redirect!

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.at_css(".initial-text").text)
      .to eq(initial_text)
  end

  it "感情未選択でも振り返りを開始できる" do
    expect {
      post reflections_path, params: {
        reflection: {
          initial_text: "何も感じない",
          emotion_ids: [ "" ]
        }
      }
    }.to change(Reflection, :count).by(1)
      .and change(ReflectionEmotion, :count).by(0)

    reflection = user.reflections.last
    expect(reflection.emotions).to be_empty
    expect(response).to redirect_to(reflection_path(reflection))
  end

  it "空白だけの入力では保存せず、日本語エラーと選択感情を表示する" do
    emotion = create(:emotion)

    expect {
      post reflections_path, params: {
        reflection: {
          initial_text: "   ",
          emotion_ids: [ emotion.id ]
        }
      }
    }.not_to change { [ Reflection.count, ReflectionEmotion.count ] }

    expect(response).to have_http_status(:unprocessable_content)
    doc = response.parsed_body
    expect(doc.at_css("#error_explanation").text)
      .to include("ひとこと入力してください")
    expect(doc.css('input[type="checkbox"][checked]').map { |input| input["value"] })
      .to eq([ emotion.id.to_s ])
  end

  it "401文字の入力では保存せず、入力内容と選択感情を残す" do
    emotion = create(:emotion)
    initial_text = "あ" * 401

    expect {
      post reflections_path, params: {
        reflection: {
          initial_text: initial_text,
          emotion_ids: [ emotion.id ]
        }
      }
    }.not_to change { [ Reflection.count, ReflectionEmotion.count ] }

    expect(response).to have_http_status(:unprocessable_content)
    doc = response.parsed_body
    expect(doc.at_css("#error_explanation").text)
      .to include("入力内容は400文字以内で入力してください")
    expect(doc.at_css("textarea").text).to include(initial_text)
    expect(doc.css('input[type="checkbox"][checked]').map { |input| input["value"] })
      .to eq([ emotion.id.to_s ])
  end

  it "存在しない感情IDが含まれていれば、何も保存せず404を返す" do
    emotion = create(:emotion)
    missing_id = Emotion.maximum(:id) + 1

    expect {
      post reflections_path, params: {
        reflection: {
          initial_text: "少し気になっている。",
          emotion_ids: [ emotion.id, missing_id ]
        }
      }
    }.not_to change { [ Reflection.count, ReflectionEmotion.count ] }

    expect(response).to have_http_status(:not_found)
  end

  it "未ログインでは開始画面・保存・対話画面にアクセスできない" do
    reflection = create(:reflection, user: user, companion: companion)
    delete destroy_user_session_path

    get new_reflection_path
    expect(response).to redirect_to(new_user_session_path)

    expect {
      post reflections_path, params: {
        reflection: { initial_text: "少し話したい。" }
      }
    }.not_to change(Reflection, :count)
    expect(response).to redirect_to(new_user_session_path)

    get reflection_path(reflection)
    expect(response).to redirect_to(new_user_session_path)
  end

  it "他の利用者の振り返りは開けない" do
    other_user = create(:user)
    reflection = create(
      :reflection,
      user: other_user,
      companion: companion,
      initial_text: "他の利用者の入力内容"
    )

    # 詳細エラー画面のコード抜粋ではなく、通常の404画面で情報の非表示を確認する
    get reflection_path(reflection),
        env: { "action_dispatch.show_detailed_exceptions" => false }

    expect(response).to have_http_status(:not_found)
    expect(response.body).not_to include("他の利用者の入力内容")
  end

  it "初期設定が未完了なら、開始画面へ進めず保存もできない" do
    user.update!(companion: nil)

    get new_reflection_path
    expect(response).to redirect_to(edit_onboarding_companion_path)

    expect {
      post reflections_path, params: {
        reflection: { initial_text: "少し話したい。" }
      }
    }.not_to change(Reflection, :count)
    expect(response).to redirect_to(edit_onboarding_companion_path)
  end

  it "本人・ミツメイト・状態を送信値で変更できない" do
    other_user = create(:user)
    other_companion = create(
      :companion,
      personality_type: companion.personality_type,
      appearance_type: "female"
    )

    post reflections_path, params: {
      reflection: {
        initial_text: "少し話したい。",
        user_id: other_user.id,
        companion_id: other_companion.id,
        status: "completed"
      }
    }

    expect(response).to have_http_status(:see_other)
    reflection = user.reflections.last
    expect(reflection).not_to be_nil
    expect(reflection.user).to eq(user)
    expect(reflection.companion).to eq(companion)
    expect(reflection).to be_in_progress
  end

  it "ミツメイトを変更したあとも、開始時のミツメイトを表示する" do
    post reflections_path, params: {
      reflection: { initial_text: "今日の気持ちを残したい。" }
    }
    reflection = user.reflections.last

    new_companion = create(
      :companion,
      personality_type: companion.personality_type,
      appearance_type: "female",
      full_image_path: "companions/intp-female-full.png"
    )
    user.update!(companion: new_companion)

    get reflection_path(reflection)

    expect(response).to have_http_status(:ok)
    expect(reflection.reload.companion).to eq(companion)
    expect(response.parsed_body.at_css(".full-mate")["src"])
      .to include("nt-animal-full")
  end

  it "同じ感情IDが重複して送られても、関連付けは1件だけ保存する" do
    emotion = create(:emotion)

    expect {
      post reflections_path, params: {
        reflection: {
          initial_text: "少し気になっている。",
          emotion_ids: [ "", emotion.id.to_s, emotion.id.to_s ]
        }
      }
    }.to change(Reflection, :count).by(1)
      .and change(ReflectionEmotion, :count).by(1)

    reflection = user.reflections.last
    expect(reflection.emotion_ids).to eq([ emotion.id ])
    expect(response).to redirect_to(reflection_path(reflection))
  end
end
