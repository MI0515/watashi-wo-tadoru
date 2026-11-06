require "rails_helper"

RSpec.describe "ミツメイトの初期設定", type: :request do
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

  let!(:companions) do
    types.flat_map do |type|
      appearances = type.code == "INTP" ? %w[male female animal] : %w[animal]

      appearances.map do |appearance|
        prefix = appearance == "animal" ? "#{type.group_code.downcase}-animal" : "intp-#{appearance}"

        create(
          :companion,
          personality_type: type,
          appearance_type: appearance,
          sd_image_path: "companions/#{prefix}-sd.png",
          full_image_path: "companions/#{prefix}-full.png"
        )
      end
    end
  end

  let(:intp) { types.find { |type| type.code == "INTP" } }
  let(:infj) { types.find { |type| type.code == "INFJ" } }
  let(:user) { create(:user, personality_type: intp) }

  def visible_choices
    response.parsed_body.at_css(".companion-choices:not([hidden])")
  end

  context "未ログインの場合" do
    it "入力・保存・ホームへのアクセスをログイン画面へ転送する" do
      get edit_onboarding_companion_path
      expect(response).to redirect_to(new_user_session_path)

      patch onboarding_companion_path, params: {
        user: { companion_id: companions.first.id }
      }
      expect(response).to redirect_to(new_user_session_path)

      get home_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context "ログイン済みの場合" do
    before do
      post user_session_path, params: {
        user: { email: user.email, password: "test123" }
      }
    end

    it "16タイプを選択肢に表示し、INTPの3候補を未選択で表示する" do
      get edit_onboarding_companion_path

      expect(response).to have_http_status(:ok)

      doc = response.parsed_body
      options = doc.css("#companion-type option").reject { |option| option["value"].blank? }

      expect(options.map(&:text)).to match_array(types.map(&:code))
      expect(visible_choices.css(".buddy").size).to eq(3)
      expect(
        visible_choices.css(".choice-label > span:last-child").map { |label| label.text.strip }
      ).to eq([ "INTP・男の子", "INTP・女の子", "INTP・動物" ])

      expect(doc.css('input[type="radio"][checked]')).to be_empty
      expect(
        doc.css('.companion-choices[hidden] input[type="radio"]:not([disabled])')
      ).to be_empty
      expect(
        visible_choices.css(".visual img").map { |image| image["src"] }
      ).to all(include("-full-"))
    end

    it "INTP以外のタイプでは動物1件を表示する" do
      user.update!(personality_type: infj)

      get edit_onboarding_companion_path

      expect(response).to have_http_status(:ok)
      expect(visible_choices.css(".buddy").size).to eq(1)
      expect(
        visible_choices.at_css(".choice-label > span:last-child").text.strip
      ).to eq("INFJ・動物")
    end

    it "保存済みのミツメイトを選択状態で表示する" do
      selected = companions.find { |companion| companion.personality_type == infj }
      user.update!(companion: selected)

      get edit_onboarding_companion_path

      doc = response.parsed_body
      checked = doc.css('input[type="radio"][checked]')

      expect(checked.size).to eq(1)
      expect(checked.first["value"]).to eq(selected.id.to_s)
      expect(checked.first["disabled"]).to be_nil
      expect(doc.css(".buddy.selected").size).to eq(1)
      expect(
        doc.at_css("#companion-type option[selected]")["value"]
      ).to eq(infj.id.to_s)
    end

    it "INTPの3候補に登録済み6件から重複なしでセリフを割り当てる" do
      contents = 6.times.map { |index| "INTPのセリフ#{index + 1}" }
      contents.each do |content|
        create(:monologue, personality_type: intp, content: content)
      end

      get edit_onboarding_companion_path

      lines = visible_choices.css('input[type="radio"]').map { |radio| radio["data-line"] }

      expect(lines.size).to eq(3)
      expect(lines.uniq.size).to eq(3)
      expect(lines - contents).to be_empty
    end

    it "INTPの男の子・女の子・動物をそれぞれ保存できる" do
      companions.select { |companion| companion.personality_type == intp }.each do |companion|
        patch onboarding_companion_path, params: {
          user: { companion_id: companion.id }
        }

        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(home_path)
        expect(user.reload.companion).to eq(companion)
      end
    end

    it "自分とは異なるタイプの相手を保存してホームへ進める" do
      selected = companions.find { |companion| companion.personality_type == infj }

      patch onboarding_companion_path, params: {
        user: { companion_id: selected.id }
      }

      expect(response).to redirect_to(home_path)
      expect(user.reload.companion).to eq(selected)
      expect(user.personality_type).to eq(intp)

      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.at_css("#home-title").text).to eq("ホーム")
    end

    it "未選択なら表示中のタイプを保ってエラーを表示し、保存済みデータを変更しない" do
      previous = companions.find { |companion| companion.personality_type == intp }
      user.update!(companion: previous)

      patch onboarding_companion_path, params: {
        companion_type_id: infj.id,
        user: { companion_id: "" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(
        response.parsed_body.at_css('[role="alert"]').text
      ).to include("ミツメイトを選択してください")
      expect(visible_choices["data-type-id"]).to eq(infj.id.to_s)
      expect(user.reload.companion).to eq(previous)
    end

    it "存在しないミツメイトのIDでは保存しない" do
      patch onboarding_companion_path, params: {
        user: { companion_id: Companion.maximum(:id) + 1 }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("ミツメイトを選択してください")
      expect(user.reload.companion).to be_nil
    end

    it "別ユーザーのIDや本人のタイプなど、許可していない属性を変更しない" do
      other = create(:user)
      selected = companions.find { |companion| companion.personality_type == infj }
      original_email = user.email

      patch onboarding_companion_path, params: {
        user: {
          id: other.id,
          email: "changed@example.com",
          personality_type_id: infj.id,
          companion_id: selected.id
        }
      }

      expect(response).to redirect_to(home_path)
      expect(user.reload.email).to eq(original_email)
      expect(user.personality_type).to eq(intp)
      expect(user.companion).to eq(selected)
      expect(other.reload.companion).to be_nil
    end
  end
end
