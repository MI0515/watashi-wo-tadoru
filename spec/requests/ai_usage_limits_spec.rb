require "rails_helper"

RSpec.describe "AI利用制限の案内", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:companion) { create(:companion) }
  let(:user) do
    create(
      :user,
      nickname: "七海",
      personality_type: companion.personality_type,
      companion: companion
    )
  end
  let(:reflection) { create(:reflection, user: user, companion: companion) }
  let(:ai_client) { instance_double(OpenaiClient) }
  let(:ai_response) do
    instance_double(
      OpenAI::Models::Responses::Response,
      id: "response-limit-test",
      usage: nil,
      output_text: "テスト用のAI返答"
    )
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("AI_ENABLED", "true").and_return("true")
    allow(OpenaiClient).to receive(:new).and_return(ai_client)
    allow(ai_client).to receive(:call).and_return(ai_response)

    post user_session_path, params: {
      user: { email: user.email, password: "test123" }
    }
  end

  it "開始上限ではAPIを呼ばず、翌日の再開案内を表示する" do
    create_list(:api_usage_log, 3, user: user, reflection: reflection)

    expect { start_reflection }.not_to change(ApiUsageLog, :count)

    expect_denied("日本時間の翌日0時")
  end

  it "日本時間の翌日0時には新しい振り返りを開始できる" do
    travel_to(Time.zone.local(2026, 11, 21, 0)) do
      create_list(
        :api_usage_log, 3,
        user: user,
        reflection: reflection,
        created_at: 1.minute.ago,
        updated_at: 1.minute.ago
      )

      expect { start_reflection }.to change(ApiUsageLog, :count).by(1)

      expect(response).to have_http_status(:see_other)
      expect(ai_client).to have_received(:call).once
      expect(AiUsagePolicy.new(user: user).daily_start_count).to eq(1)
    end
  end

  it "開始上限に達した後は、失敗していた初回返信を再試行できない" do
    create_list(:api_usage_log, 3, user: user, reflection: reflection)
    failed_reflection = create(
      :reflection,
      user: user,
      companion: companion,
      ai_response_status: :failed
    )

    expect {
      post reflection_retry_path(failed_reflection)
    }.not_to change { [ ApiUsageLog.count, ReflectionMessage.count ] }

    expect_denied("日本時間の翌日0時")
  end

  context "AI機能が全体停止中" do
    before do
      allow(ENV).to receive(:fetch).with("AI_ENABLED", "true").and_return("false")
    end

    it "初回返信を取得せず、停止案内を表示する" do
      expect { start_reflection }.not_to change(ApiUsageLog, :count)

      expect_denied("一時停止")
    end

    it "追加返信を取得せず、入力を保存して停止案内を表示する" do
      message = create(:reflection_message, reflection: reflection, position: 1)

      expect {
        post reflection_messages_path(reflection), params: {
          reflection_message: {
            reply_to_id: message.id,
            content: "もう少し話したい"
          }
        }
      }.not_to change(ApiUsageLog, :count)

      expect_denied("一時停止")
      expect(response.parsed_body.css(".thread .bubble").map(&:text))
        .to include("もう少し話したい")
    end

    it "再試行でもAPIを呼ばず、停止案内を表示する" do
      reflection.update!(ai_response_status: :failed)

      expect {
        post reflection_retry_path(reflection)
      }.not_to change(ApiUsageLog, :count)

      expect_denied("一時停止")
    end

    it "保存済み記録の一覧・詳細はAPIを呼ばずに表示できる" do
      reflection.update!(
        status: :completed,
        completed_at: Time.current,
        title: "保存済みの振り返り",
        insight: "自分の話を聞いてほしかった。"
      )
      create_list(:api_usage_log, 3, user: user, reflection: reflection)

      get records_path

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.at_css(".record-title").text)
        .to eq(reflection.title)

      get record_path(reflection)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.at_css("#record-title").text)
        .to eq(reflection.title)
      expect(response.body).to include(reflection.insight)
      expect(ai_client).not_to have_received(:call)
    end

    it "開始上限にも達していても、ホーム・独り言・保存した内容を表示できる" do
      create_list(:api_usage_log, 3, user: user, reflection: reflection)
      monologue = create(:monologue, personality_type: companion.personality_type)

      get home_path

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.at_css(".quote").text).to eq(monologue.content)

      get reflection_path(reflection)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css(".thread .bubble").map(&:text))
        .to include(reflection.initial_text)
      expect(ai_client).not_to have_received(:call)
    end
  end

  def start_reflection
    post reflections_path, params: {
      reflection: {
        submission_token: SecureRandom.uuid,
        initial_text: "今日は少し疲れた"
      }
    }
  end

  def expect_denied(message)
    expect(response).to have_http_status(:see_other)
    expect(ai_client).not_to have_received(:call)

    follow_redirect!

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.at_css(".alert").text).to include(message)
  end
end
