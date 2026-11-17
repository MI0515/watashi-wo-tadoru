require "rails_helper"

RSpec.describe "対話メッセージの送信", type: :request do
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
    create(:reflection, user: user, companion: companion)
  end
  let(:ai_client) { instance_double(OpenaiClient) }
  let(:ai_response) do
    instance_double(
      OpenAI::Models::Responses::Response,
      output_text: "次のAIの返答"
    )
  end

  before do
    allow(OpenaiClient).to receive(:new).and_return(ai_client)
    allow(ai_client).to receive(:call).and_return(ai_response)

    create(
      :reflection_message,
      reflection: reflection,
      position: 1,
      content: "最初のAIの返答"
    )

    post user_session_path, params: {
      user: { email: user.email, password: "test123" }
    }
  end

  it "送信した発言をAIへ渡し、自分とAIの発言を保存・表示する" do
    expect(ai_client).to receive(:call) do |instructions:, input:|
      expect(input.last).to eq(
        role: :user,
        content: "相談してほしかった"
      )
      ai_response
    end

    expect {
      post reflection_messages_path(reflection), params: {
        reflection_message: { content: "相談してほしかった" }
      }
    }.to change(ReflectionMessage, :count).by(2)

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(reflection_path(reflection))

    follow_redirect!

    expect(response.parsed_body.css(".thread .bubble").map(&:text))
      .to eq(
        [
          reflection.initial_text,
          "最初のAIの返答",
          "相談してほしかった",
          "次のAIの返答"
        ]
      )
  end

  [ "   ", "あ" * 401 ].each do |content|
    it "空白だけ、または400文字超過では保存・送信しない（#{content.length}文字）" do
      expect(ai_client).not_to receive(:call)

      expect {
        post reflection_messages_path(reflection), params: {
          reflection_message: { content: content }
        }
      }.not_to change(ReflectionMessage, :count)

      expect(response).to have_http_status(:unprocessable_content)

      doc = response.parsed_body
      expect(doc.at_css("#reflection-reply").text).to include(content)

      expected_message =
        if content.blank?
          "ひとこと入力してください"
        else
          "返答は400文字以内で入力してください"
        end

      expect(doc.at_css("#error_explanation").text)
        .to include(expected_message)
    end
  end

  it "未ログインでは保存・送信できない" do
    delete destroy_user_session_path
    expect(ai_client).not_to receive(:call)

    expect {
      post reflection_messages_path(reflection), params: {
        reflection_message: { content: "少し話したい" }
      }
    }.not_to change(ReflectionMessage, :count)

    expect(response).to redirect_to(new_user_session_path)
  end

  it "他の利用者の振り返りには保存・送信できない" do
    other_reflection = create(
      :reflection,
      user: create(:user),
      companion: companion
    )
    expect(ai_client).not_to receive(:call)

    expect {
      post reflection_messages_path(other_reflection), params: {
        reflection_message: { content: "少し話したい" }
      }
    }.not_to change(ReflectionMessage, :count)

    expect(response).to have_http_status(:not_found)
  end

  it "初期設定が未完了なら保存・送信できない" do
    user.update!(companion: nil)
    expect(ai_client).not_to receive(:call)

    expect {
      post reflection_messages_path(reflection), params: {
        reflection_message: { content: "少し話したい" }
      }
    }.not_to change(ReflectionMessage, :count)

    expect(response).to redirect_to(edit_onboarding_companion_path)
  end

  it "完了済みの振り返りには保存・送信できない" do
    reflection.update!(status: :completed)
    expect(ai_client).not_to receive(:call)

    expect {
      post reflection_messages_path(reflection), params: {
        reflection_message: { content: "もうひとこと" }
      }
    }.not_to change(ReflectionMessage, :count)

    expect(response).to redirect_to(reflection_path(reflection))
  end

  it "送信値で発言者・発言順・保存先を変更できない" do
    post reflection_messages_path(reflection), params: {
      reflection_message: {
        content: "相談してほしかった",
        role: "assistant",
        position: 99,
        reflection_id: reflection.id + 1
      }
    }

    message = reflection.reflection_messages.find_by(position: 2)

    expect(message).to be_user
    expect(message.content).to eq("相談してほしかった")
    expect(reflection.reflection_messages.order(:position).pluck(:position))
      .to eq([ 1, 2, 3 ])
  end
end
