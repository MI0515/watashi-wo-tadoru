require "rails_helper"

RSpec.describe "ログイン・ログアウト", type: :request do
  # 各テストで必要になったとき、登録済みユーザーを作る
  let(:user) { create(:user) }

  it "正しい情報でログインでき、ヘッダーが切り替わる" do
    post user_session_path, params: {
      user: { email: user.email, password: "test123" }
    }

    expect(response).to redirect_to(root_path)
    expect(flash[:notice]).to eq("ログインしました。")

    # 遷移先を開き、ヘッダー内の表示を確認する
    follow_redirect!
    navigation = response.parsed_body.at_css(".wtc-nav").text

    expect(navigation).to include("ログアウト")
    expect(navigation).not_to include("はじめてみる")
  end

  it "パスワードが違う場合はログインできず、日本語で案内する" do
    post user_session_path, params: {
      user: { email: user.email, password: "wrong-password" }
    }

    expect(response.body).to include(
      "メールアドレスまたはパスワードが正しくありません。"
    )

    # TOPを開いても、未ログインのメニューであることを確認する
    get root_path
    navigation = response.parsed_body.at_css(".wtc-nav").text

    expect(navigation).to include("ログイン", "はじめてみる")
    expect(navigation).not_to include("ログアウト")
  end

  it "ログアウトするとTOPへ戻り、未ログインのメニューになる" do
    post user_session_path, params: {
      user: { email: user.email, password: "test123" }
    }

    follow_redirect!
    expect(response.parsed_body.at_css(".wtc-nav").text)
      .to include("ログアウト")

    delete destroy_user_session_path

    expect(response).to redirect_to(root_path)
    expect(flash[:notice]).to eq("ログアウトしました。")

    follow_redirect!
    navigation = response.parsed_body.at_css(".wtc-nav").text

    expect(navigation).to include("ログイン", "はじめてみる")
    expect(navigation).not_to include("ログアウト")
  end
end
