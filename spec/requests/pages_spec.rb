require "rails_helper"

RSpec.describe "TOPページ", type: :request do
  it "未ログインでアクセスでき、サービス名が表示される" do
    # ブラウザ操作をせず、TOPへのGETリクエストを送る
    get root_path

    # 正常な応答と、サービス名が返ることを確認する
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("わたしを辿る")
  end
end