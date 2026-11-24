require "rails_helper"

RSpec.describe "プロフィール設定", type: :request do
  let(:companion) { create(:companion) }
  let(:user) do
    create(
      :user,
      nickname: "七海",
      honorific: "さん",
      personality_type: companion.personality_type,
      companion: companion
    )
  end
  let(:settings_params) do
    {
      nickname: "なな",
      honorific: "ちゃん",
      personality_type_id: user.personality_type_id
    }
  end

  before do
    post user_session_path, params: {
      user: { email: user.email, password: "test123" }
    }
  end

  it "現在の設定とホームの設定メニューを表示する" do
    get settings_path

    expect(response).to have_http_status(:ok)
    doc = response.parsed_body
    expect(doc.at_css('input[name="user[nickname]"]')["value"]).to eq("七海")
    expect(doc.at_css('input[name="user[honorific]"]')["value"]).to eq("さん")
    expect(doc.at_css('select option[selected]')["value"])
      .to eq(user.personality_type_id.to_s)

    get home_path

    expect(response.parsed_body.at_css('.account-menu a[href="' + settings_path + '"]'))
      .to be_present
  end

  it "3項目を変更し、ミツメイトと過去の記録は変えずにホームへ反映する" do
    record = create(:reflection, user: user, companion: companion)
    original_record = record.attributes
    new_type = create(:personality_type, code: "ENTJ", group_code: "NT")

    patch settings_path, params: {
      user: settings_params.merge(personality_type_id: new_type.id)
    }

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(settings_path)
    expect(flash[:notice]).to eq("設定を変更しました。")
    expect(user.reload.nickname).to eq("なな")
    expect(user.honorific).to eq("ちゃん")
    expect(user.personality_type).to eq(new_type)
    expect(user.companion).to eq(companion)
    expect(record.reload.attributes).to eq(original_record)

    get home_path

    expect(response.parsed_body.at_css(".hello").text.strip)
      .to eq("おかえり、ななちゃん。")
  end

  it "敬称が空欄でも保存できる" do
    patch settings_path, params: {
      user: settings_params.merge(honorific: "")
    }

    expect(response).to redirect_to(settings_path)
    expect(user.reload.honorific).to eq("")
  end

  it "名前が空欄ならエラーと入力内容を表示し、DBを変更しない" do
    patch settings_path, params: {
      user: settings_params.merge(nickname: "")
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("ニックネームを入力してください")
    expect(response.parsed_body.at_css('input[name="user[honorific]"]')["value"])
      .to eq("ちゃん")
    expect(user.reload.nickname).to eq("七海")
    expect(user.honorific).to eq("さん")
  end

  it "名前21文字・敬称11文字では保存しない" do
    patch settings_path, params: {
      user: settings_params.merge(nickname: "あ" * 21, honorific: "あ" * 11)
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(
      "ニックネームは20文字以内で入力してください",
      "呼び方（敬称など）は10文字以内で入力してください"
    )
    expect(user.reload.nickname).to eq("七海")
    expect(user.honorific).to eq("さん")
  end

  it "存在しないタイプでは保存しない" do
    patch settings_path, params: {
      user: settings_params.merge(
        personality_type_id: PersonalityType.maximum(:id) + 1
      )
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.at_css("#error_explanation")).to be_present
    expect(user.reload.personality_type).to eq(companion.personality_type)
    expect(user.nickname).to eq("七海")
  end

  it "別の利用者のIDや対象外の項目を送っても更新しない" do
    other_user = create(:user)
    original_email = user.email

    patch settings_path, params: {
      user: settings_params.merge(
        id: other_user.id,
        email: "changed@example.com",
        companion_id: nil
      )
    }

    expect(response).to redirect_to(settings_path)
    expect(user.reload.nickname).to eq("なな")
    expect(user.email).to eq(original_email)
    expect(user.companion).to eq(companion)
    expect(other_user.reload.nickname).to be_nil
  end

  it "未ログインでは表示・保存できない" do
    values = settings_params
    delete destroy_user_session_path

    get settings_path
    expect(response).to redirect_to(new_user_session_path)

    patch settings_path, params: { user: values }

    expect(response).to redirect_to(new_user_session_path)
    expect(user.reload.nickname).to eq("七海")
  end

  it "初期設定が未完了なら設定画面へ進めない" do
    user.update!(companion: nil)

    get settings_path
    expect(response).to redirect_to(edit_onboarding_companion_path)

    patch settings_path, params: { user: settings_params }

    expect(response).to redirect_to(edit_onboarding_companion_path)
    expect(user.reload.nickname).to eq("七海")
  end
end
