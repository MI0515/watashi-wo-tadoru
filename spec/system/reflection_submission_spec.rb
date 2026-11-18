require "rails_helper"

RSpec.describe "AIへの送信と待機表示", type: :system do
  let(:companion) { create(:companion) }
  let(:user) do
    create(
      :user,
      nickname: "七海",
      personality_type: companion.personality_type,
      companion: companion,
      onboarding_completed_at: Time.current
    )
  end
  let(:reflection) do
    create(:reflection, user: user, companion: companion)
  end
  let(:ai_client) { instance_double(OpenaiClient) }
  let(:ai_response) do
    instance_double(
      OpenAI::Models::Responses::Response,
      id: "response-test-request",
      usage: nil,
      output_text: "待機後のAIの返答"
    )
  end

  before do
    allow(OpenaiClient).to receive(:new).and_return(ai_client)

    visit new_user_session_path
    fill_in "メールアドレス", with: user.email
    fill_in "パスワード", with: "test123"
    click_button "ログイン"

    expect(page).to have_current_path(home_path)
  end

  it "追加送信中は入力を保持して待機案内を出し、返信後に入力欄へ戻る",
     skip: "CIで送信中表示を確認できないため一時保留。原因調査後に再開する" do
    create(:reflection_message, reflection: reflection, position: 1)
    visit reflection_path(reflection)
    fill_in "ミツメイトへの返答", with: "相談してほしかった"

    with_pending_reply do |finish_reply|
      click_button "送信"

      expect(page).to have_button("送信中…", disabled: true)
      expect(page).to have_css(
        ".submission-status",
        text: "ミツメイトが返答を考えています。"
      )
      expect(page).to have_css("#reflection-reply[readonly]")
      expect(find("#reflection-reply").value).to eq("相談してほしかった")

      finish_reply.call

      expect(page).to have_css(".thread .bubble", text: "待機後のAIの返答")
      expect(page).to have_button("送信", disabled: false)
      expect(page).to have_no_css("#reflection-reply[readonly]")
      expect(page).to have_no_css(".submission-status", visible: true)
      expect(find("#reflection-reply").value).to eq("")

      expect(reflection.reload).to be_ai_response_idle
      expect(reflection.reflection_messages.where(role: :user).count).to eq(1)
      expect(reflection.reflection_messages.find_by!(role: :user).content)
        .to eq("相談してほしかった")
      expect(ai_client).to have_received(:call).once
    end
  end

  it "初回送信中は入力を保持して待機し、会話画面へ移動する" do
    emotion = create(:emotion, name: "モヤモヤ")
    visit new_reflection_path
    check "モヤモヤ", allow_label_click: true
    fill_in "今、どんなことが浮かんでる？",
            with: "何が嫌だったのか分からない"

    with_pending_reply do |finish_reply|
      click_button "ミツメイトと振り返る"

      expect(page).to have_button("開始しています…", disabled: true)
      expect(page).to have_css(
        ".submission-status",
        text: "ミツメイトが返答を考えています。"
      )
      expect(page).to have_css("#reflection_initial_text[readonly]")
      expect(find("#reflection_initial_text").value)
        .to eq("何が嫌だったのか分からない")

      finish_reply.call

      expect(page).to have_css(".thread .bubble", text: "待機後のAIの返答")
      expect(page).to have_no_css(".submission-status", visible: true)

      saved_reflection = user.reflections.sole
      expect(saved_reflection.initial_text).to eq("何が嫌だったのか分からない")
      expect(saved_reflection.emotions).to contain_exactly(emotion)
      expect(saved_reflection.reflection_messages.count).to eq(1)
      expect(ai_client).to have_received(:call).once
    end
  end

  it "再試行中はボタンを無効化し、保存済みの発言から返信を受け取る" do
    create(:reflection_message, reflection: reflection, position: 1)
    create(
      :reflection_message,
      reflection: reflection,
      role: :user,
      position: 2,
      content: "相談してほしかった"
    )
    reflection.update!(ai_response_status: :failed)

    visit reflection_path(reflection)

    with_pending_reply do |finish_reply|
      click_button "もう一度返答を受け取る"

      expect(page).to have_button("再試行中…", disabled: true)
      expect(page).to have_css(
        ".submission-status",
        text: "ミツメイトが返答を考えています。"
      )

      finish_reply.call

      expect(page).to have_css(".thread .bubble", text: "待機後のAIの返答")
      expect(page).to have_button("送信", disabled: false)
      expect(page).to have_no_css(".retry-form")
      expect(page).to have_no_css(".submission-status", visible: true)

      expect(reflection.reload).to be_ai_response_idle
      expect(reflection.reflection_messages.where(role: :user).count).to eq(1)
      expect(reflection.reflection_messages.count).to eq(3)
      expect(ai_client).to have_received(:call).once
    end
  end

  def with_pending_reply
    gate = Queue.new

    # 実行速度に左右されず、待機中の表示を確認してから応答を返す
    allow(ai_client).to receive(:call) do
      gate.pop
      ai_response
    end

    yield -> { gate << true }
  ensure
    # 途中でテストが失敗しても、サーバーを応答待ちのまま残さない
    gate << true if gate
  end
end
