require "rails_helper"

RSpec.describe "ホーム画面", type: :request do
  it "設定した呼び名と、選択中のミツメイトの画像・独り言を表示する" do
    own_type = create(:personality_type, code: "INFJ", group_code: "NF")
    companion = create(:companion)
    create(:monologue, personality_type: own_type, content: "本人のタイプの独り言")
    create(:monologue, personality_type: companion.personality_type, content: "ミツメイトの独り言")
    create(:monologue, personality_type: companion.personality_type, content: "別の独り言")
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
    contents = JSON.parse(
      doc.at_css(".character")["data-monologue-contents-value"]
    )
    expect(contents).to match_array([ "ミツメイトの独り言", "別の独り言" ])
    expect(contents).to include(doc.at_css(".quote").text)
    button = doc.at_css('button[data-action="click->monologue#change"]')
    expect(button["type"]).to eq("button")
    expect(button["aria-label"]).to eq("独り言を切り替える")
  end

  context "独り言が少ない場合" do
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

    it "1件の場合も、独り言と切り替え候補を表示する" do
      create(
        :monologue,
        personality_type: companion.personality_type,
        content: "ひとつだけの独り言"
      )

      get home_path

      expect(response).to have_http_status(:ok)
      doc = response.parsed_body
      contents = JSON.parse(
        doc.at_css(".character")["data-monologue-contents-value"]
      )

      expect(contents).to eq([ "ひとつだけの独り言" ])
      expect(doc.at_css(".quote").text).to eq("ひとつだけの独り言")
    end

    it "0件の場合もホームを表示し、吹き出しは表示しない" do
      get home_path

      expect(response).to have_http_status(:ok)
      doc = response.parsed_body
      contents = JSON.parse(
        doc.at_css(".character")["data-monologue-contents-value"]
      )

      expect(contents).to eq([])
      expect(doc.at_css(".quote")).to be_nil
      expect(doc.at_css(".monologue-button")).not_to be_nil
    end
  end
end
