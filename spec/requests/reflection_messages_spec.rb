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

  let(:reply_to_id) do
    reflection.reflection_messages.find_by(position: 1).id
  end

  let(:ai_client) { instance_double(OpenaiClient) }
  let(:ai_response) do
    instance_double(
      OpenAI::Models::Responses::Response,
      id: "response-test-request",
      usage: nil,
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
        reflection_message: { reply_to_id: reply_to_id, content: "相談してほしかった" }
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
          reflection_message: { reply_to_id: reply_to_id, content: content }
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
        reflection_message: { reply_to_id: reply_to_id, content: "少し話したい" }
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
        reflection_message: { reply_to_id: reply_to_id, content: "少し話したい" }
      }
    }.not_to change(ReflectionMessage, :count)

    expect(response).to have_http_status(:not_found)
  end

  it "初期設定が未完了なら保存・送信できない" do
    user.update!(companion: nil)
    expect(ai_client).not_to receive(:call)

    expect {
      post reflection_messages_path(reflection), params: {
        reflection_message: { reply_to_id: reply_to_id, content: "少し話したい" }
      }
    }.not_to change(ReflectionMessage, :count)

    expect(response).to redirect_to(edit_onboarding_companion_path)
  end

  it "完了済みの振り返りには保存・送信できない" do
    reflection.update!(status: :completed)
    expect(ai_client).not_to receive(:call)

    expect {
      post reflection_messages_path(reflection), params: {
        reflection_message: { reply_to_id: reply_to_id, content: "もうひとこと" }
      }
    }.not_to change(ReflectionMessage, :count)

    expect(response).to redirect_to(reflection_path(reflection))
  end

  it "送信値で発言者・発言順・保存先を変更できない" do
    post reflection_messages_path(reflection), params: {
      reflection_message: {
        reply_to_id: reply_to_id,
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
  it "返信完了後に同じ送信が届いても、追加保存・API送信しない" do
    sent_params = {
      reflection_message: {
        reply_to_id: reply_to_id.to_s,
        content: "相談してほしかった"
      }
    }
    expect(ai_client).to receive(:call).once.and_return(ai_response)

    post reflection_messages_path(reflection), params: sent_params

    expect(response).to redirect_to(reflection_path(reflection))

    expect {
      post reflection_messages_path(reflection), params: sent_params
    }.not_to change(ReflectionMessage, :count)

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(reflection_path(reflection))
    expect(reflection.reflection_messages.order(:position).pluck(:position))
      .to eq([ 1, 2, 3 ])
  end

  it "返信先IDがない送信は、追加保存・API送信しない" do
    expect(ai_client).not_to receive(:call)

    expect {
      post reflection_messages_path(reflection), params: {
        reflection_message: { content: "少し話したい" }
      }
    }.not_to change(ReflectionMessage, :count)

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(reflection_path(reflection))
  end

  [ "時間切れ", "応答エラー" ].each do |failure_type|
    it "追加返信が#{failure_type}でも、発言を保存して会話画面へ戻る" do
      error =
        if failure_type == "時間切れ"
          OpenAI::Errors::APITimeoutError.new(
            url: URI("https://api.openai.com/v1/responses")
          )
        else
          OpenaiClient::ResponseError.new(
            "テスト用の応答エラー",
            response: ai_response
          )
        end

      expect(ai_client).to receive(:call).once.and_raise(error)

      expect {
        post reflection_messages_path(reflection), params: {
          reflection_message: {
            reply_to_id: reply_to_id,
            content: "相談してほしかった"
          }
        }
      }.to change(ReflectionMessage, :count).by(1)

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(reflection_path(reflection))
      expect(reflection.reload).to be_ai_response_failed

      message = reflection.reflection_messages.order(:position).last
      expect(message).to be_user
      expect(message.content).to eq("相談してほしかった")

      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css(".thread .bubble").map(&:text))
        .to include("相談してほしかった")
      expect(response.parsed_body.at_css(".alert").text)
        .to include("入力内容は保存されています。")
      expect(response.parsed_body.at_css(".retry-form")["action"])
        .to eq(reflection_retry_path(reflection))
      expect(response.parsed_body.at_css('input[name="last_message_id"]')["value"])
        .to eq(message.id.to_s)
      expect(response.parsed_body.at_css("#reflection-reply")).to be_nil
    end
  end
end
