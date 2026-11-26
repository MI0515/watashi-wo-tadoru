require "rails_helper"

RSpec.describe "ミツメイトの変更", type: :request do
  let(:companion) { create(:companion) }
  let(:user) do
    create(
      :user,
      nickname: "七海",
      personality_type: companion.personality_type,
      companion: companion
    )
  end
  let(:new_type) do
    create(:personality_type, code: "INFJ", group_code: "NF")
  end
  let(:new_companion) do
    create(
      :companion,
      personality_type: new_type,
      sd_image_path: "companions/nf-animal-sd.png",
      full_image_path: "companions/nf-animal-full.png",
      speaking_style: "polite"
    )
  end

  before do
    post user_session_path, params: {
      user: { email: user.email, password: "test123" }
    }
  end

  it "設定画面から変更画面へ進み、現在のミツメイトを選択状態で表示する" do
    get settings_path

    expect(response.parsed_body.at_css(
      'a[href="' + edit_settings_companion_path + '"]'
    )).to be_present

    get edit_settings_companion_path

    expect(response).to have_http_status(:ok)
    doc = response.parsed_body
    expect(doc.at_css("form")["action"]).to eq(destroy_user_session_path)
    expect(doc.at_css('form[data-controller="companion-selection"]')["action"])
      .to eq(settings_companion_path)
    expect(doc.at_css("#companion-type option[selected]")["value"])
      .to eq(companion.personality_type_id.to_s)
    expect(doc.at_css('input[type="radio"][checked]')["value"])
      .to eq(companion.id.to_s)
    expect(doc.css(".buddy.selected").size).to eq(1)
    expect(doc.at_css(".bottom a")["href"]).to eq(settings_path)
  end

  it "別タイプへ変更してホームへ反映し、本人のタイプと過去の記録は変えない" do
    record = create(
      :reflection,
      user: user,
      companion: companion,
      status: :completed,
      completed_at: Time.current,
      title: "振り返りの記録",
      insight: "話を聞いてほしかった。"
    )
    original_record = record.attributes
    original_type_id = user.personality_type_id
    line = create(
      :monologue,
      personality_type: new_type,
      content: "何気ない一言が、あとになって心に残ることがありますね。"
    )

    patch settings_companion_path, params: {
      user: { companion_id: new_companion.id }
    }

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(home_path)
    expect(flash[:notice]).to eq("ミツメイトを変更しました。")
    expect(user.reload.companion).to eq(new_companion)
    expect(user.personality_type_id).to eq(original_type_id)
    expect(record.reload.attributes).to eq(original_record)

    follow_redirect!

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.at_css(".sd-mate")["src"])
      .to include("nf-animal-sd")
    expect(response.parsed_body.at_css(".quote").text).to eq(line.content)
  end

  it "未選択なら表示中のタイプを保ってエラーを表示し、変更しない" do
    patch settings_companion_path, params: {
      companion_type_id: new_type.id,
      user: { companion_id: "" }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("ミツメイトを選択してください")
    expect(response.parsed_body.at_css("#companion-type option[selected]")["value"])
      .to eq(new_type.id.to_s)
    expect(user.reload.companion).to eq(companion)
  end

  it "存在しないミツメイトでは変更しない" do
    patch settings_companion_path, params: {
      user: { companion_id: Companion.maximum(:id) + 1 }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("ミツメイトを選択してください")
    expect(user.reload.companion).to eq(companion)
  end

  it "別の利用者のIDや本人のタイプなど、対象外の項目は変更しない" do
    other = create(:user)
    original_email = user.email
    original_type_id = user.personality_type_id

    patch settings_companion_path, params: {
      user: {
        id: other.id,
        email: "changed@example.com",
        personality_type_id: new_type.id,
        companion_id: new_companion.id
      }
    }

    expect(response).to redirect_to(home_path)
    expect(user.reload.companion).to eq(new_companion)
    expect(user.email).to eq(original_email)
    expect(user.personality_type_id).to eq(original_type_id)
    expect(other.reload.companion).to be_nil
  end

  it "未ログインでは変更画面の表示も保存もできない" do
    selected_id = new_companion.id
    delete destroy_user_session_path

    get edit_settings_companion_path
    expect(response).to redirect_to(new_user_session_path)

    patch settings_companion_path, params: {
      user: { companion_id: selected_id }
    }

    expect(response).to redirect_to(new_user_session_path)
    expect(user.reload.companion).to eq(companion)
  end

  it "初期設定が未完了なら変更画面の表示も保存もできない" do
    user.update!(companion: nil)

    get edit_settings_companion_path
    expect(response).to redirect_to(edit_onboarding_companion_path)

    patch settings_companion_path, params: {
      user: { companion_id: new_companion.id }
    }

    expect(response).to redirect_to(edit_onboarding_companion_path)
    expect(user.reload.companion).to be_nil
  end
end
