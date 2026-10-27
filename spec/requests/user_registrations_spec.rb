require "rails_helper"

RSpec.describe "ユーザー登録", type: :request do
  # 各テストで使う、正しい登録内容
  let(:registration_params) do
    {
      email: "signup-test@example.com",
      password: "test123",
      password_confirmation: "test123",
      terms_accepted: "1"
    }
  end

  it "正しい入力と同意があれば登録でき、TOPへ戻る" do
    expect {
      post user_registration_path, params: { user: registration_params }
    }.to change(User, :count).by(1)

    expect(response).to redirect_to(root_path)
    expect(flash[:notice]).to eq("アカウントを登録しました。")
  end

  it "同意が未チェックの場合は登録できない" do
    # チェックを外したフォームが送る値は「0」
    params = registration_params.merge(terms_accepted: "0")

    expect {
      post user_registration_path, params: { user: params }
    }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(
      "利用規約・プライバシーポリシーに同意してください"
    )
  end

  it "同意の項目自体が送られなくても登録できない" do
    params = registration_params.except(:terms_accepted)

    expect {
      post user_registration_path, params: { user: params }
    }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(
      "利用規約・プライバシーポリシーに同意してください"
    )
  end

  it "確認用パスワードが不一致の場合は日本語のエラーを表示する" do
    params = registration_params.merge(password_confirmation: "test456")

    expect {
      post user_registration_path, params: { user: params }
    }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(
      "パスワード（確認）がパスワードと一致しません"
    )
  end
end
