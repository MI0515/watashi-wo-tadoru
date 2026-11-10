require "rails_helper"

RSpec.describe "初期設定の振り分け", type: :request do
  let(:user) { create(:user) }
  let(:companion) { create(:companion) }

  def sign_in
    post user_session_path, params: {
      user: { email: user.email, password: "test123" }
    }
  end

  def sign_in_again
    delete destroy_user_session_path
    sign_in
  end

  it "途中でログアウトしても続きから再開でき、設定完了後はホームへ進む" do
    sign_in
    expect(response).to redirect_to(edit_onboarding_nickname_path)

    patch onboarding_nickname_path, params: {
      user: { nickname: "七海", honorific: "さん" }
    }
    sign_in_again
    expect(response).to redirect_to(edit_onboarding_personality_type_path)

    patch onboarding_personality_type_path, params: {
      user: { personality_type_id: companion.personality_type_id }
    }
    sign_in_again
    expect(response).to redirect_to(edit_onboarding_companion_path)

    patch onboarding_companion_path, params: {
      user: { companion_id: companion.id }
    }
    expect(response).to redirect_to(home_path)

    sign_in_again
    expect(response).to redirect_to(home_path)

    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.at_css("#home-title").text).to eq("ホーム")
  end

  it "設定途中でホームを直接開くと続きの設定画面へ進む" do
    user.update!(nickname: "七海")
    sign_in

    get home_path

    expect(response).to redirect_to(edit_onboarding_personality_type_path)
  end
end
