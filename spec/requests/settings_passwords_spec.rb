require "rails_helper"

RSpec.describe "パスワードの変更", type: :request do
  let(:companion) { create(:companion) }
  let(:user) do
    create(
      :user,
      nickname: "七海",
      personality_type: companion.personality_type,
      companion: companion
    )
  end
  let(:password_params) do
    {
      current_password: "test123",
      password: "changed123",
      password_confirmation: "changed123"
    }
  end

  before do
    post user_session_path, params: {
      user: { email: user.email, password: "test123" }
    }
  end

  it "設定から変更画面へ進むリンクと3つのパスワード欄を表示する" do
    get settings_path

    expect(response.parsed_body.at_css(
      'a[href="' + edit_settings_password_path + '"]'
    )).to be_present

    get edit_settings_password_path

    expect(response).to have_http_status(:ok)
    fields = response.parsed_body.css('input[type="password"]')
    expect(fields.map { |field| field["name"] }).to eq([
      "user[current_password]",
      "user[password]",
      "user[password_confirmation]"
    ])
  end

  it "変更後もログインを維持し、新しいパスワードで再ログインできる" do
    patch settings_password_path, params: { user: password_params }

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(settings_path)
    expect(flash[:notice]).to eq("パスワードを変更しました。")
    expect(user.reload.valid_password?("changed123")).to be(true)
    expect(user.valid_password?("test123")).to be(false)

    get settings_path
    expect(response).to have_http_status(:ok)

    delete destroy_user_session_path

    post user_session_path, params: {
      user: { email: user.email, password: "test123" }
    }
    expect(response.body)
      .to include("メールアドレスまたはパスワードが正しくありません。")

    post user_session_path, params: {
      user: { email: user.email, password: "changed123" }
    }
    expect(response).to redirect_to(home_path)
  end

  [
    [
      "現在のパスワードが誤っている",
      { current_password: "wrong-password" },
      "現在のパスワードが正しくありません"
    ],
    [
      "現在のパスワードが空欄",
      { current_password: "" },
      "現在のパスワードを入力してください"
    ],
    [
      "新しいパスワードが空欄",
      { password: "" },
      "パスワードを入力してください"
    ],
    [
      "新しいパスワードが短すぎる",
      { password: "short", password_confirmation: "short" },
      "パスワードは6文字以上で入力してください"
    ],
    [
      "確認用パスワードが空欄",
      { password_confirmation: "" },
      "パスワード（確認）を入力してください"
    ],
    [
      "確認用パスワードが一致しない",
      { password_confirmation: "different123" },
      "パスワード（確認）がパスワードと一致しません"
    ]
  ].each do |condition, invalid_attributes, message|
    it "#{condition}場合は変更せず、パスワードを画面へ再表示しない" do
      expect {
        patch settings_password_path, params: {
          user: password_params.merge(invalid_attributes)
        }
      }.not_to change { user.reload.encrypted_password }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.at_css("#error_explanation").text)
        .to include(message)
      fields = response.parsed_body.css('input[type="password"]')
      expect(fields.map { |field| field["value"].to_s })
        .to all(eq(""))
    end
  end

  it "別の利用者のIDやメールなど、対象外の項目は変更しない" do
    other = create(:user)
    original_email = user.email
    original_companion_id = user.companion_id
    other_password = other.encrypted_password

    patch settings_password_path, params: {
      user: password_params.merge(
        id: other.id,
        email: "changed@example.com",
        companion_id: nil
      )
    }

    expect(response).to redirect_to(settings_path)
    expect(user.reload.valid_password?("changed123")).to be(true)
    expect(user.email).to eq(original_email)
    expect(user.companion_id).to eq(original_companion_id)
    expect(other.reload.encrypted_password).to eq(other_password)
  end

  it "未ログインでは変更画面の表示も更新もできない" do
    delete destroy_user_session_path

    get edit_settings_password_path
    expect(response).to redirect_to(new_user_session_path)

    expect {
      patch settings_password_path, params: { user: password_params }
    }.not_to change { user.reload.encrypted_password }

    expect(response).to redirect_to(new_user_session_path)
  end

  it "初期設定が未完了なら変更画面の表示も更新もできない" do
    user.update!(companion: nil)

    get edit_settings_password_path
    expect(response).to redirect_to(edit_onboarding_companion_path)

    expect {
      patch settings_password_path, params: { user: password_params }
    }.not_to change { user.reload.encrypted_password }

    expect(response).to redirect_to(edit_onboarding_companion_path)
  end
end
