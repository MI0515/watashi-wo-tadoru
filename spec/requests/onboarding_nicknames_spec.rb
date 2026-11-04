require "rails_helper"

RSpec.describe "呼ばれ方の初期設定", type: :request do
  let(:user) { create(:user) }

  context "未ログインの場合" do
    it "入力画面はログイン画面へ転送する" do
      get edit_onboarding_nickname_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "保存できずログイン画面へ転送する" do
      patch onboarding_nickname_path, params: {
        user: { nickname: "七海", honorific: "さん" }
      }

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context "ログイン済みの場合" do
    before do
      post user_session_path, params: {
        user: { email: user.email, password: "test123" }
      }
    end

    it "入力画面を表示する" do
      get edit_onboarding_nickname_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        "呼ばれ方を決めよう",
        'data-controller="nickname-preview"'
      )
    end

    it "保存後に16タイプ設定へ移動できる" do
      patch onboarding_nickname_path, params: {
        user: { nickname: "七海", honorific: "さん" }
      }

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(edit_onboarding_personality_type_path)
      expect(user.reload.nickname).to eq("七海")
      expect(user.honorific).to eq("さん")

      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.at_css("#type-title").text).to include(
        "あなたの16タイプを", "教えてね"
      )
    end

    it "敬称が空欄でも保存できる" do
      patch onboarding_nickname_path, params: {
        user: { nickname: "七海", honorific: "" }
      }

      expect(response).to redirect_to(edit_onboarding_personality_type_path)
      expect(user.reload.honorific).to eq("")
    end

    it "名前が空の場合はエラーと入力済みの敬称を表示し、DBを変更しない" do
      patch onboarding_nickname_path, params: {
        user: { nickname: "", honorific: "ちゃん" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("ニックネームを入力してください")
      expect(
        response.parsed_body.at_css('input[name="user[honorific]"]')["value"]
      ).to eq("ちゃん")
      expect(user.reload.nickname).to be_nil
    end

    it "名前が21文字の場合は保存せずエラーを表示する" do
      patch onboarding_nickname_path, params: {
        user: { nickname: "あ" * 21, honorific: "さん" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(
        "ニックネームは20文字以内で入力してください"
      )
      expect(user.reload.nickname).to be_nil
    end

    it "敬称が11文字の場合は保存せずエラーを表示する" do
      patch onboarding_nickname_path, params: {
        user: { nickname: "七海", honorific: "さ" * 11 }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(
        "呼び方（敬称など）は10文字以内で入力してください"
      )
      expect(user.reload.honorific).to be_nil
    end

    it "送られた別ユーザーのIDやメールアドレスは更新に使わない" do
      other = create(:user)
      original_email = user.email

      patch onboarding_nickname_path, params: {
        user: {
          id: other.id,
          email: "changed@example.com",
          nickname: "七海",
          honorific: "さん"
        }
      }

      expect(response).to redirect_to(edit_onboarding_personality_type_path)
      expect(user.reload.email).to eq(original_email)
      expect(user.nickname).to eq("七海")
      expect(other.reload.nickname).to be_nil
    end
  end
end
