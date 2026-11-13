require "rails_helper"

RSpec.describe "登録から初期設定まで", type: :system do
  let!(:personality_type) do
    create(:personality_type, code: "INFP", group_code: "NF")
  end
  let!(:companion) { create(:companion) }
  let!(:monologue) do
    create(:monologue, personality_type: companion.personality_type)
  end

  it "新規登録から初期設定を経て、初回案内を完了してホームを使える" do
    visit new_user_registration_path
    fill_in "メールアドレス", with: "onboarding@example.com"
    fill_in "パスワード", with: "test123", exact: true
    fill_in "パスワード（確認）", with: "test123"
    check "同意します"
    click_button "登録して次へ"

    expect(page).to have_current_path(edit_onboarding_nickname_path)
    fill_in "ニックネーム", with: "七海"
    fill_in "呼び方（敬称など）", with: "さん"
    expect(page).to have_css(
      '[data-nickname-preview-target="preview"]',
      text: "七海さん"
    )
    click_button "次へ：16タイプを選ぶ"

    expect(page).to have_current_path(edit_onboarding_personality_type_path)
    choose "INFP", allow_label_click: true
    expect(page).to have_css(
      '[data-type-selection-target="selected"]',
      text: "INFP"
    )
    click_button "次へ：ミツメイトを選ぶ"

    expect(page).to have_current_path(edit_onboarding_companion_path)
    select "INTP", from: "ミツメイトの16タイプ"
    choose "INTP・動物", allow_label_click: true
    expect(page).to have_css(
      '[data-companion-selection-target="selected"]',
      text: "INTP・動物"
    )
    click_button "このミツメイトと始める"

    expect(page).to have_current_path(home_path)
    expect(page).to have_css("dialog.guide-card[open]")

    within("dialog.guide-card") do
      click_button "はじめる"
    end

    expect(page).to have_no_css("dialog.guide-card")
    expect(page).to have_css(".hello", text: "おかえり、七海さん。")
    expect(page).to have_css('.sd-mate[src*="nt-animal-sd"]')
    expect(page).to have_css(".quote", text: monologue.content)
    expect(page).to have_link("振り返りを始める", href: new_reflection_path)

    user = User.find_by!(email: "onboarding@example.com")
    expect(user.nickname).to eq("七海")
    expect(user.honorific).to eq("さん")
    expect(user.personality_type).to eq(personality_type)
    expect(user.companion).to eq(companion)
    expect(user.onboarding_completed_at).not_to be_nil
  end

  it "ログアウト後に再ログインすると、初期設定済みのホームに戻る" do
    user = create(
      :user,
      nickname: "七海",
      honorific: "さん",
      personality_type: personality_type,
      companion: companion,
      onboarding_completed_at: Time.current
    )

    visit new_user_session_path
    fill_in "メールアドレス", with: user.email
    fill_in "パスワード", with: "test123"
    click_button "ログイン"

    expect(page).to have_current_path(home_path)
    expect(page).to have_css(".hello", text: "おかえり、七海さん。")
    expect(page).to have_no_css("dialog.guide-card")

    click_button "ログアウト"

    expect(page).to have_current_path(root_path)
    expect(page).to have_link("ログイン", href: new_user_session_path)

    click_link "wtc-login"
    fill_in "メールアドレス", with: user.email
    fill_in "パスワード", with: "test123"
    click_button "ログイン"

    expect(page).to have_current_path(home_path)
    expect(page).to have_css(".hello", text: "おかえり、七海さん。")
    expect(page).to have_css('.sd-mate[src*="nt-animal-sd"]')
    expect(page).to have_css(".quote", text: monologue.content)
    expect(page).to have_no_css("dialog.guide-card")
  end
end
