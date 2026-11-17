require "rails_helper"

RSpec.describe "AI返信の再試行", type: :request do
  let(:companion) { create(:companion) }
  let(:user) do
    create(
      :user,
      nickname: "七海",
      personality_type: companion.personality_type,
      companion: companion
    )
  end
  let(:reflection) do
    create(
      :reflection,
      user: user,
      companion: companion,
      ai_response_status: :failed
    )
  end
  let(:ai_client) { instance_double(OpenaiClient) }
  let(:ai_response) do
    instance_double(
      OpenAI::Models::Responses::Response,
      output_text: "再試行で生成したAIの返答"
    )
  end
  let(:user_message) do
    create(:reflection_message, reflection: reflection, position: 1)
    create(
      :reflection_message,
      reflection: reflection,
      role: :user,
      position: 2,
      content: "相談してほしかった"
    )
  end

  before do
    allow(OpenaiClient).to receive(:new).and_return(ai_client)
    allow(ai_client).to receive(:call).and_return(ai_response)

    post user_session_path, params: {
      user: { email: user.email, password: "test123" }
    }
  end

  it "初回返信を再試行し、AI返信を保存して会話画面へ戻る" do
    reflection

    expect {
      post reflection_retry_path(reflection)
    }.to change(ReflectionMessage, :count).by(1)

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(reflection_path(reflection))
    expect(reflection.reflection_messages.sole.position).to eq(1)
    expect(reflection.reload).to be_ai_response_idle
  end

  it "保存済みの発言から再試行し、成功後の同じリクエストを拒否する" do
    message_id = user_message.id

    expect(ai_client).to receive(:call).once do |instructions:, input:|
      expect(input.last).to eq(
        role: :user,
        content: "相談してほしかった"
      )
      ai_response
    end

    expect {
      post reflection_retry_path(reflection),
           params: { last_message_id: message_id }
    }.to change(ReflectionMessage, :count).by(1)

    expect(reflection.reflection_messages.where(role: :user).count).to eq(1)

    expect {
      post reflection_retry_path(reflection),
           params: { last_message_id: message_id }
    }.not_to change(ReflectionMessage, :count)

    expect(response).to redirect_to(reflection_path(reflection))
  end

  it "時間切れでは発言を保持し、エラーを付けて会話画面へ戻る" do
    message_id = user_message.id
    error = OpenAI::Errors::APITimeoutError.new(
      url: URI("https://api.openai.com/v1/responses")
    )
    allow(ai_client).to receive(:call).and_raise(error)

    expect {
      post reflection_retry_path(reflection),
           params: { last_message_id: message_id }
    }.not_to change(ReflectionMessage, :count)

    expect(response).to redirect_to(reflection_path(reflection))
    expect(flash[:alert])
      .to eq("返答の生成に時間がかかり、再試行を完了できませんでした。")
    expect(reflection.reload).to be_ai_response_failed
  end

  it "未ログインでは再試行しない" do
    reflection
    delete destroy_user_session_path
    expect(ai_client).not_to receive(:call)

    expect {
      post reflection_retry_path(reflection)
    }.not_to change(ReflectionMessage, :count)

    expect(response).to redirect_to(new_user_session_path)
  end

  it "他の利用者の振り返りは再試行しない" do
    other_reflection = create(
      :reflection,
      user: create(:user),
      companion: companion,
      ai_response_status: :failed
    )
    expect(ai_client).not_to receive(:call)

    expect {
      post reflection_retry_path(other_reflection)
    }.not_to change(ReflectionMessage, :count)

    expect(response).to have_http_status(:not_found)
  end

  it "生成中は再試行せず、待機中であることを伝える" do
    reflection.update!(ai_response_status: :processing)
    expect(ai_client).not_to receive(:call)

    expect {
      post reflection_retry_path(reflection)
    }.not_to change(ReflectionMessage, :count)

    expect(response).to redirect_to(reflection_path(reflection))
    expect(flash[:notice]).to eq("ミツメイトが返答を考えています。")
    expect(reflection.reload).to be_ai_response_processing
  end

  it "初期設定が未完了なら再試行しない" do
    reflection
    user.update!(companion: nil)
    expect(ai_client).not_to receive(:call)

    expect {
      post reflection_retry_path(reflection)
    }.not_to change(ReflectionMessage, :count)

    expect(response).to redirect_to(edit_onboarding_companion_path)
  end
end
