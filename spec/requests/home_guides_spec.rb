require "rails_helper"

RSpec.describe "初回ホーム案内", type: :request do
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

  it "未完了なら案内を表示し、表示しただけでは完了にしない" do
    get home_path

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.at_css("dialog.guide-card")).not_to be_nil
    expect(user.reload.onboarding_completed_at).to be_nil
  end

  it "完了日時を保存し、再ログインしても案内を表示しない" do
    patch home_guide_path

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(home_path)
    expect(user.reload.onboarding_completed_at).not_to be_nil

    follow_redirect!
    expect(response.parsed_body.at_css("dialog.guide-card")).to be_nil

    delete destroy_user_session_path
    post user_session_path, params: {
      user: { email: user.email, password: "test123" }
    }
    get home_path

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.at_css("dialog.guide-card")).to be_nil
  end

  it "再送信されても、保存済みの完了日時を変更しない" do
    user.update!(onboarding_completed_at: 1.day.ago)
    completed_at = user.reload.onboarding_completed_at

    patch home_guide_path

    expect(response).to redirect_to(home_path)
    expect(user.reload.onboarding_completed_at).to eq(completed_at)
  end

  it "未ログインでは完了日時を保存できない" do
    delete destroy_user_session_path

    patch home_guide_path

    expect(response).to redirect_to(new_user_session_path)
    expect(user.reload.onboarding_completed_at).to be_nil
  end

  it "初期設定が未完了なら、設定画面へ案内して日時を保存しない" do
    user.update!(companion: nil)

    patch home_guide_path

    expect(response).to redirect_to(edit_onboarding_companion_path)
    expect(user.reload.onboarding_completed_at).to be_nil
  end
end
