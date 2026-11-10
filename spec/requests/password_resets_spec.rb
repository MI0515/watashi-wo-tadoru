require "rails_helper"

RSpec.describe "パスワード再設定", type: :request do
  let(:user) { create(:user) }

  before { ActionMailer::Base.deliveries.clear }
  after { ActionMailer::Base.deliveries.clear }

  def request_reset
    post user_password_path, params: { user: { email: user.email } }

    mail = ActionMailer::Base.deliveries.last
    html = (mail.html_part || mail).body.decoded
    url = Nokogiri::HTML(html).at_css("a")["href"]

    URI.decode_www_form(URI.parse(url).query).to_h.fetch("reset_password_token")
  end

  def change_password(token, password: "newpass123", confirmation: password)
    put user_password_path, params: {
      user: {
        reset_password_token: token,
        password: password,
        password_confirmation: confirmation
      }
    }
  end

  it "ログイン画面から日本語の申請画面へ進める" do
    get new_user_session_path
    expect(response.parsed_body.at_css(".forgot-link a")["href"])
      .to eq(new_user_password_path)

    get new_user_password_path
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.at_css("#reset-title").text)
      .to eq("パスワードを再設定")
  end

  it "登録済みの宛先に日本語の再設定メールを生成する" do
    token = request_reset
    mail = ActionMailer::Base.deliveries.last

    expect(response).to redirect_to(new_user_session_path)
    expect(flash[:notice]).to eq(
      "パスワード再設定の案内をメールでお送りします。メールをご確認ください。"
    )
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(mail.to).to eq([ user.email ])
    expect(mail.subject).to eq("【わたしを辿る】パスワード再設定のご案内")
    expect((mail.html_part || mail).body.decoded)
      .to include("新しいパスワードを設定する")
    expect(user.reload.reset_password_token).to be_present
    expect(user.reset_password_token).not_to eq(token)
  end

  it "メールアドレスが空なら送信せず申請用のエラー見出しを表示する" do
    post user_password_path, params: { user: { email: "" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(ActionMailer::Base.deliveries).to be_empty
    expect(response.parsed_body.at_css("#error_explanation h2").text)
      .to include("再設定用メールを送信できませんでした。")
    expect(response.body).to include("メールアドレスを入力してください")
  end

  it "未登録のメールアドレスには送信しない" do
    post user_password_path, params: { user: { email: "unknown@example.com" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(ActionMailer::Base.deliveries).to be_empty
    expect(response.body).to include("メールアドレスが見つかりません")
  end

  it "メールのトークンを設定画面のフォームへ引き継ぐ" do
    token = request_reset

    get edit_user_password_path, params: { reset_password_token: token }

    expect(response).to have_http_status(:ok)
    doc = response.parsed_body
    expect(doc.at_css("#new-password-title").text)
      .to include("新しいパスワードを", "設定")
    expect(
      doc.at_css('input[name="user[reset_password_token]"]')["value"]
    ).to eq(token)
  end

  it "変更後は旧パスワードでログインできず新パスワードでログインできる" do
    token = request_reset
    change_password(token)

    expect(response).to have_http_status(:see_other)
    expect(flash[:notice]).to eq("パスワードを変更しました。ログインしました。")
    expect(request.env["warden"].user(:user)).to eq(user)
    expect(user.reload.reset_password_token).to be_nil

    delete destroy_user_session_path

    post user_session_path, params: {
      user: { email: user.email, password: "test123" }
    }
    expect(request.env["warden"].user(:user)).to be_nil

    post user_session_path, params: {
      user: { email: user.email, password: "newpass123" }
    }
    expect(request.env["warden"].user(:user)).to eq(user)
  end

  it "確認用パスワードが違う場合は変更せずトークンを保持する" do
    token = request_reset
    change_password(token, confirmation: "different123")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.at_css("#error_explanation h2").text)
      .to include("パスワードを変更できませんでした。")
    expect(response.body)
      .to include("パスワード（確認）がパスワードと一致しません")
    expect(
      response.parsed_body.at_css('input[name="user[reset_password_token]"]')["value"]
    ).to eq(token)
    expect(user.reload.valid_password?("test123")).to be true
  end

  it "5文字のパスワードでは変更できない" do
    token = request_reset
    change_password(token, password: "abc12")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("パスワードは6文字以上で入力してください")
    expect(user.reload.valid_password?("test123")).to be true
  end

  it "無効なトークンでは変更できない" do
    user
    change_password("invalid-token")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("再設定用リンクが無効です。")
    expect(user.reload.valid_password?("test123")).to be true
  end

  it "期限切れのトークンでは変更できない" do
    token = request_reset
    user.reload.update_column(
      :reset_password_sent_at, (User.reset_password_within + 1.minute).ago
    )
    change_password(token)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("再設定用リンクの有効期限が切れています。")
    expect(user.reload.valid_password?("test123")).to be true
  end

  it "使用済みのトークンを再利用できない" do
    token = request_reset
    change_password(token)
    expect(user.reload.valid_password?("newpass123")).to be true

    delete destroy_user_session_path
    change_password(token, password: "another123")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("再設定用リンクが無効です。")
    expect(user.reload.valid_password?("newpass123")).to be true
    expect(user.valid_password?("another123")).to be false
  end

  it "トークンなしで設定画面を開くとログイン画面へ案内する" do
    get edit_user_password_path

    expect(response).to redirect_to(new_user_session_path)
    expect(flash[:alert]).to eq(
      "再設定用メールに記載されたリンクからアクセスしてください。"
    )
  end
end
