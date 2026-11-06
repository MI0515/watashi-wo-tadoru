require "rails_helper"

RSpec.describe "16タイプの初期設定", type: :request do
  let(:user) { create(:user) }

  let!(:types) do
    {
      "NT" => %w[INTJ INTP ENTJ ENTP],
      "NF" => %w[INFJ INFP ENFJ ENFP],
      "SJ" => %w[ISTJ ISFJ ESTJ ESFJ],
      "SP" => %w[ISTP ISFP ESTP ESFP]
    }.flat_map do |group, codes|
      codes.map do |code|
        create(:personality_type, code: code, group_code: group)
      end
    end
  end

  context "未ログインの場合" do
    it "入力・保存・次の画面へのアクセスをログイン画面へ転送する" do
      get edit_onboarding_personality_type_path
      expect(response).to redirect_to(new_user_session_path)

      patch onboarding_personality_type_path, params: {
        user: { personality_type_id: types.first.id }
      }
      expect(response).to redirect_to(new_user_session_path)

      get edit_onboarding_companion_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context "ログイン済みの場合" do
    before do
      post user_session_path, params: {
        user: { email: user.email, password: "test123" }
      }
    end

    it "16件を未選択で表示し、外部リンクを別タブで開く指定にする" do
      get edit_onboarding_personality_type_path

      expect(response).to have_http_status(:ok)

      doc = response.parsed_body
      expect(doc.css('input[type="radio"]').size).to eq(16)
      expect(doc.css('input[type="radio"][checked]')).to be_empty
      expect(doc.css(".group-name").map(&:text)).to eq(
        %w[NTグループ NFグループ SJグループ SPグループ]
      )
      expect(
        doc.at_css('[data-type-selection-target="selected"]').text
      ).to eq("未選択")

      link = doc.at_css("a.type-help")
      expect(link["href"]).to eq(
        "https://mentuzzle.com/shindan/report/16type"
      )
      expect(link["target"]).to eq("_blank")
      expect(link["rel"].split).to include("noopener", "noreferrer")
    end

    it "保存後にミツメイト設定へ移動できる" do
      patch onboarding_personality_type_path, params: {
        user: { personality_type_id: types[1].id }
      }

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(edit_onboarding_companion_path)
      expect(user.reload.personality_type).to eq(types[1])

      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(
        response.parsed_body.at_css("#companion-title").text
      ).to eq("そばにいてほしいミツメイトを選ぼう")
    end

    it "保存済みのタイプを選択状態で表示する" do
      user.update!(personality_type: types[1])

      get edit_onboarding_personality_type_path

      doc = response.parsed_body
      checked = doc.css('input[type="radio"][checked]')

      expect(checked.size).to eq(1)
      expect(checked.first["value"]).to eq(types[1].id.to_s)
      expect(doc.css(".type-option.selected").size).to eq(1)
      expect(
        doc.at_css('[data-type-selection-target="selected"]').text
      ).to eq("INTP")
    end

    it "未選択ならエラーと選択肢を表示し、保存済みデータを変更しない" do
      user.update!(personality_type: types[1])

      patch onboarding_personality_type_path, params: {
        user: { personality_type_id: "" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("16タイプを選択してください")
      expect(
        response.parsed_body.css('input[type="radio"]').size
      ).to eq(16)
      expect(user.reload.personality_type).to eq(types[1])
    end

    it "存在しないIDでは保存せずエラーを表示する" do
      patch onboarding_personality_type_path, params: {
        user: { personality_type_id: PersonalityType.maximum(:id) + 1 }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("16タイプを選択してください")
      expect(user.reload.personality_type).to be_nil
    end

    it "数字ではないIDでもサーバーエラーにせず入力エラーを返す" do
      patch onboarding_personality_type_path, params: {
        user: { personality_type_id: "invalid" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.personality_type).to be_nil
    end

    it "別ユーザーのIDや許可していない属性を更新に使わない" do
      other = create(:user)
      original_email = user.email

      patch onboarding_personality_type_path, params: {
        user: {
          id: other.id,
          email: "changed@example.com",
          nickname: "変更",
          personality_type_id: types.first.id
        }
      }

      expect(response).to redirect_to(edit_onboarding_companion_path)
      expect(user.reload.personality_type).to eq(types.first)
      expect(user.email).to eq(original_email)
      expect(user.nickname).to be_nil
      expect(other.reload.personality_type).to be_nil
    end
  end
end
