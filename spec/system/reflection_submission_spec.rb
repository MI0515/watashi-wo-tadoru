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

  it "追加送信中は入力を保持して待機案内を出し、返信後に入力欄へ戻る" do
    create(:reflection_message, reflection: reflection, position: 1)
    visit reflection_path(reflection)

    with_pending_reply do |finish_reply|
      with_reply_input_probe do
        fill_in "ミツメイトへの返答",
                with: "test reply",
                fill_options: { clear: :backspace }

        expect(page).to have_field(
          "ミツメイトへの返答",
          with: "test reply"
        )
      end

      click_button "送信"

      expect(page).to have_button("送信中…", disabled: true)
      expect(page).to have_css(
        ".submission-status",
        text: "ミツメイトが返答を考えています。"
      )
      expect(page).to have_css("#reflection-reply[readonly]")
      expect(find("#reflection-reply").value).to eq("test reply")

      finish_reply.call

      expect(page).to have_css(".thread .bubble", text: "待機後のAIの返答")
      expect(page).to have_button("送信", disabled: false)
      expect(page).to have_no_css("#reflection-reply[readonly]")
      expect(page).to have_no_css(".submission-status", visible: true)
      expect(find("#reflection-reply").value).to eq("")

      expect(reflection.reload).to be_ai_response_idle
      expect(reflection.reflection_messages.where(role: :user).count).to eq(1)
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

  # CIで入力が反映されない原因を調べるための一時的な観測
  def with_reply_input_probe
    page.execute_script(<<~JS)
      const original = document.querySelector("#reflection-reply")
      const events = []
      const startedAt = performance.now()
      const listeners = new AbortController()
      const record = (type, event = null) => {
        const current = document.querySelector("#reflection-reply")
        events.push({
          ms: Math.round(performance.now() - startedAt),
          type,
          value: current?.value ?? null,
          sameElement: current === original,
          focused: document.activeElement === current,
          readOnly: current?.readOnly ?? null,
          disabled: current?.disabled ?? null,
          key: event?.key ?? null,
          inputType: event?.inputType ?? null
        })
      }
      const probe = { original, events, record }
      window.__replyInputProbe = probe
      const types = ["focus", "blur", "keydown", "keyup", "beforeinput",
                     "input", "change", "compositionstart", "compositionend"]
      types.forEach((type) => {
        document.addEventListener(type, (event) => {
          if (event.target.id === "reflection-reply") record(type, event)
        }, { capture: true, signal: listeners.signal })
      })
      document.addEventListener("reset", (event) => {
        if (event.target === original?.form) record("form reset")
      }, { capture: true, signal: listeners.signal })
      let previous = original
      const observer = new MutationObserver(() => {
        const current = document.querySelector("#reflection-reply")
        if (current !== previous) {
          record("element changed")
          previous = current
        }
      })
      observer.observe(document.body, { childList: true, subtree: true })
      probe.stop = () => { observer.disconnect(); listeners.abort() }
      record("before fill")
    JS

    yield
  ensure
    log_reply_input_probe
  end

  def log_reply_input_probe
    snapshot = page.evaluate_script(<<~JS)
      (() => {
        const probe = window.__replyInputProbe
        if (!probe) return { probeMissing: true }
        probe.record("after fill check")
        const current = document.querySelector("#reflection-reply")
        const result = {
          sameElement: current === probe.original,
          originalConnected: probe.original?.isConnected ?? false,
          currentValue: current?.value ?? null,
          events: probe.events
        }
        probe.stop()
        delete window.__replyInputProbe
        return result
      })()
    JS

    warn "REPLY_INPUT_PROBE=#{snapshot.to_json}"
  rescue StandardError => error
    warn "REPLY_INPUT_PROBE_ERROR=#{error.class.name}"
  end

  def with_pending_reply
    # HTMLの表示だけでなく、送信処理のJavaScriptが接続されるまで待つ
    page.document.synchronize(10) do
      ready = page.evaluate_script(<<~JS)
        Boolean(
          window.Turbo && window.Stimulus &&
          window.Stimulus.getControllerForElementAndIdentifier(
            document.querySelector('[data-controller~="ai-submission"]'),
            "ai-submission"
          )
        )
      JS

      raise Capybara::ElementNotFound, "送信処理のJavaScriptが未接続です" unless ready
    end

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
