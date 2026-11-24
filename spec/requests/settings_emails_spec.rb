require "rails_helper"

RSpec.describe "メールアドレスの変更", type: :request do
  let(:companion) { create(:companion) }
  let(:user) do
    create(
      :user,
      nickname: "七海",
      personality_type: companion.personality_type,
      companion: companion
    )
  end
  let(:email_params) do
    { email: "changed@example.com", current_password: "test123" }
  end

  before do
    post user_session_path, params: {
      user: { email: user.email, password: "test123" }
    }
  end

  it "設定画面から変更画面へ進むリンクと入力欄を表示する" do
    get settings_path
    expect(response.parsed_body.at_css('a[href="' + edit_settings_email_path + '"]'))
      .to be_present

    get edit_settings_email_path

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.at_css('input[name="user[email]"]')["value"])
      .to eq(user.email)
    expect(response.parsed_body.at_css('input[name="user[current_password]"]')["type"])
      .to eq("password")
  end

  it "メールを変更し、ログインを維持して新しいメールでも再ログインできる" do
    original_email = user.email

    expect {
      patch settings_email_path, params: { user: email_params }
    }.not_to change(ActionMailer::Base.deliveries, :count)

    expect(response).to redirect_to(settings_path)
    expect(flash[:notice]).to eq("メールアドレスを変更しました。")
    expect(user.reload.email).to eq("changed@example.com")

    get settings_path
    expect(response).to have_http_status(:ok)
    delete destroy_user_session_path

    post user_session_path, params: {
      user: { email: original_email, password: "test123" }
    }
    expect(response.body).to include("メールアドレスまたはパスワードが正しくありません。")

    post user_session_path, params: {
      user: { email: "changed@example.com", password: "test123" }
    }
    expect(response).to redirect_to(home_path)
  end

  it "現在のパスワードが誤っていたらメールだけを入力欄に残して拒否する" do
    original_email = user.email

    patch settings_email_path, params: {
      user: email_params.merge(current_password: "wrong-password")
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("現在のパスワードが正しくありません")
    expect(response.parsed_body.at_css('input[name="user[email]"]')["value"])
      .to eq("changed@example.com")
    expect(response.parsed_body.at_css('input[name="user[current_password]"]')["value"].to_s)
      .to eq("")
    expect(user.reload.email).to eq(original_email)
  end

  it "現在のパスワードが空欄なら変更しない" do
    original_email = user.email

    patch settings_email_path, params: {
      user: email_params.merge(current_password: "")
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("現在のパスワードを入力してください")
    expect(user.reload.email).to eq(original_email)
  end

  it "メールが空欄なら変更しない" do
    original_email = user.email

    patch settings_email_path, params: { user: email_params.merge(email: "") }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("メールアドレスを入力してください")
    expect(user.reload.email).to eq(original_email)
  end

  it "メールの形式が不正なら変更しない" do
    original_email = user.email

    patch settings_email_path, params: {
      user: email_params.merge(email: "invalid-email")
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("メールアドレスが正しくありません")
    expect(user.reload.email).to eq(original_email)
  end

  it "他の利用者と重複するメールには変更しない" do
    other = create(:user)
    original_email = user.email

    patch settings_email_path, params: {
      user: email_params.merge(email: other.email)
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("メールアドレスはすでに使用されています")
    expect(user.reload.email).to eq(original_email)
  end

  it "別の利用者のIDやパスワード変更などの対象外項目は受け付けない" do
    other = create(:user)
    other_email = other.email
    original_password = user.encrypted_password

    patch settings_email_path, params: {
      user: email_params.merge(id: other.id, password: "new-password123", companion_id: nil)
    }

    expect(response).to redirect_to(settings_path)
    expect(user.reload.email).to eq("changed@example.com")
    expect(user.encrypted_password).to eq(original_password)
    expect(user.companion).to eq(companion)
    expect(other.reload.email).to eq(other_email)
  end

  it "未ログインでは変更画面の表示も更新もできない" do
    original_email = user.email
    delete destroy_user_session_path

    get edit_settings_email_path
    expect(response).to redirect_to(new_user_session_path)

    patch settings_email_path, params: { user: email_params }

    expect(response).to redirect_to(new_user_session_path)
    expect(user.reload.email).to eq(original_email)
  end

  it "初期設定が未完了なら変更画面の表示も更新もできない" do
    original_email = user.email
    user.update!(companion: nil)

    get edit_settings_email_path
    expect(response).to redirect_to(edit_onboarding_companion_path)

    patch settings_email_path, params: { user: email_params }

    expect(response).to redirect_to(edit_onboarding_companion_path)
    expect(user.reload.email).to eq(original_email)
  end
end
