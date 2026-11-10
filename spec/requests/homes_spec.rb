require "rails_helper"

RSpec.describe "ホーム画面", type: :request do
  it "設定した呼び名と、選択中のミツメイトの画像・独り言を表示する" do
    own_type = create(:personality_type, code: "INFJ", group_code: "NF")
    companion = create(:companion)
    create(:monologue, personality_type: own_type, content: "本人のタイプの独り言")
    create(:monologue, personality_type: companion.personality_type, content: "ミツメイトの独り言")
    user = create(
      :user,
      nickname: "七海",
      honorific: "さん",
      personality_type: own_type,
      companion: companion
    )

    post user_session_path, params: {
      user: { email: user.email, password: "test123" }
    }
    get home_path

    expect(response).to have_http_status(:ok)
    doc = response.parsed_body
    expect(doc.at_css(".hello").text.strip).to eq("おかえり、七海さん。")
    expect(doc.at_css(".sd-mate")["src"]).to include("nt-animal-sd")
    expect(doc.at_css(".quote").text).to eq("ミツメイトの独り言")
  end
end
