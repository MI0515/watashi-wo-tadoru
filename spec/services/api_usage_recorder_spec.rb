require "rails_helper"

RSpec.describe ApiUsageRecorder do
  let(:reflection) { create(:reflection) }
  let(:service) do
    described_class.new(
      reflection: reflection,
      request_kind: :dialogue,
      initial_reply: true
    )
  end

  let(:usage) do
    instance_double(
      OpenAI::Models::Responses::ResponseUsage,
      input_tokens: 100,
      output_tokens: 30
    )
  end

  let(:response) do
    instance_double(
      OpenAI::Models::Responses::Response,
      id: "response-test-recorder",
      usage: usage
    )
  end

  it "通信前に履歴を作り、成功後に使用量を記録して応答を返す" do
    result = service.call do
      log = reflection.api_usage_logs.sole

      expect(log).to be_status_processing
      expect(log.input_tokens).to be_nil
      expect(log.output_tokens).to be_nil

      response
    end

    log = reflection.api_usage_logs.sole

    expect(result).to equal(response)
    expect(log.user).to eq(reflection.user)
    expect(log).to be_request_kind_dialogue
    expect(log).to be_status_succeeded
    expect(log.initial_reply).to be true
    expect(log[:retry]).to be false
    expect(log.response_id).to eq("response-test-recorder")
    expect(log.input_tokens).to eq(100)
    expect(log.output_tokens).to eq(30)
  end

  it "未完了でも取得できた使用量を残し、元のエラーを伝える" do
    error = OpenaiClient::ResponseError.new(
      "AIの応答生成が完了しませんでした。",
      response: response
    )

    expect {
      service.call { raise error }
    }.to raise_error(OpenaiClient::ResponseError) { |raised|
      expect(raised).to equal(error)
    }

    log = reflection.api_usage_logs.sole

    expect(log).to be_status_failed
    expect(log.response_id).to eq("response-test-recorder")
    expect(log.input_tokens).to eq(100)
    expect(log.output_tokens).to eq(30)
  end

  it "時間切れでは使用量を空欄にし、元のエラーを伝える" do
    error = OpenAI::Errors::APITimeoutError.new(
      url: URI("https://api.openai.com/v1/responses")
    )

    expect {
      service.call { raise error }
    }.to raise_error(OpenAI::Errors::APITimeoutError) { |raised|
      expect(raised).to equal(error)
    }

    log = reflection.api_usage_logs.sole

    expect(log).to be_status_timed_out
    expect(log.response_id).to be_nil
    expect(log.input_tokens).to be_nil
    expect(log.output_tokens).to be_nil
  end

  it "通信失敗でも履歴を残し、元のエラーを伝える" do
    error = OpenAI::Errors::APIConnectionError.new(
      url: URI("https://api.openai.com/v1/responses")
    )

    expect {
      service.call { raise error }
    }.to raise_error(OpenAI::Errors::APIConnectionError) { |raised|
      expect(raised).to equal(error)
    }

    log = reflection.api_usage_logs.sole

    expect(log).to be_status_failed
    expect(log.input_tokens).to be_nil
    expect(log.output_tokens).to be_nil
  end

  it "再試行を別のAPIリクエストとして記録する" do
    service.call { response }

    retry_service = described_class.new(
      reflection: reflection,
      request_kind: :dialogue,
      initial_reply: true,
      retrying: true
    )
    retry_response = instance_double(
      OpenAI::Models::Responses::Response,
      id: "response-test-retry",
      usage: usage
    )

    expect {
      retry_service.call { retry_response }
    }.to change(ApiUsageLog, :count).by(1)

    log = reflection.api_usage_logs.order(:id).last

    expect(log[:retry]).to be true
    expect(log.initial_reply).to be true
    expect(log.response_id).to eq("response-test-retry")
  end

  it "応答に使用量が含まれない場合も、成功と使用量不明を区別して残す" do
    allow(response).to receive(:usage).and_return(nil)

    service.call { response }

    log = reflection.api_usage_logs.sole

    expect(log).to be_status_succeeded
    expect(log.input_tokens).to be_nil
    expect(log.output_tokens).to be_nil
  end

  it "開始上限に達していれば通信も履歴作成もしない" do
    create_list(:api_usage_log, 3, user: reflection.user, reflection: reflection)

    expect {
      expect {
        service.call { raise "通信処理が呼ばれています" }
      }.to raise_error(AiUsagePolicy::LimitError, /翌日0時/)
    }.not_to change(ApiUsageLog, :count)
  end

  it "初回返信の生成中は残りの枠を確保し、別の開始を拒否する" do
    create_list(:api_usage_log, 2, user: reflection.user, reflection: reflection)
    other_reflection = create(
      :reflection,
      user: reflection.user,
      companion: reflection.companion
    )
    other_service = described_class.new(
      reflection: other_reflection,
      request_kind: :dialogue,
      initial_reply: true
    )

    service.call do
      expect {
        expect {
          other_service.call { raise "通信処理が呼ばれています" }
        }.to raise_error(AiUsagePolicy::LimitError, /生成中/)
      }.not_to change(ApiUsageLog, :count)

      response
    end

    expect(reflection.user.api_usage_logs.status_succeeded.count).to eq(3)
  end

  it "開始上限に達しても追加返信は利用できる" do
    create_list(:api_usage_log, 3, user: reflection.user, reflection: reflection)
    additional_service = described_class.new(
      reflection: reflection,
      request_kind: :dialogue,
      initial_reply: false
    )

    expect {
      additional_service.call { response }
    }.to change(ApiUsageLog, :count).by(1)
  end

  it "全体停止中は通信も履歴作成もしない" do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("AI_ENABLED", "true").and_return("false")

    expect {
      expect {
        service.call { raise "通信処理が呼ばれています" }
      }.to raise_error(AiUsagePolicy::StoppedError)
    }.not_to change(ApiUsageLog, :count)
  end
end
