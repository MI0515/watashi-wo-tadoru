require "rails_helper"

RSpec.describe OpenaiClient do
  let(:responses_api) { instance_double(OpenAI::Resources::Responses) }
  let(:sdk_client) { instance_double(OpenAI::Client, responses: responses_api) }
  let(:service) { described_class.new(client: sdk_client) }
  let(:instructions) { "テスト用の指示" }
  let(:input) { [ { role: :user, content: "テスト用の入力" } ] }

  let(:response) do
    instance_double(
      OpenAI::Models::Responses::Response,
      status: :completed,
      output_text: "テスト用の返答"
    )
  end

  before do
    allow(responses_api).to receive(:create).and_return(response)
    allow(OpenAI::Client).to receive(:new).and_return(sdk_client)
  end

  it "自動再試行なし・時間切れ60秒でSDKを用意し、初期化だけでは送信しない" do
    expect(OpenAI::Client).to receive(:new)
      .with(max_retries: 0, timeout: 60)
      .and_return(sdk_client)

    expect(responses_api).not_to receive(:create)

    described_class.new
  end

  it "検証で決めた設定と入力を送り、SDKの返答をそのまま返す" do
    expect(responses_api).to receive(:create).with(
      model: "gpt-6.1-sol",
      instructions: instructions,
      input: input,
      reasoning: { effort: :low },
      max_output_tokens: 4096,
      service_tier: :default,
      store: false
    ).and_return(response)

    result = service.call(instructions: instructions, input: input)

    expect(result).to equal(response)
  end

  it "未完了の場合は、返答の情報を保持したエラーにする" do
    allow(response).to receive(:status).and_return(:incomplete)

    expect {
      service.call(instructions: instructions, input: input)
    }.to raise_error(described_class::ResponseError) { |error|
      expect(error.response).to equal(response)
    }
  end

  [ "", " \n " ].each do |text|
    it "本文が#{text.inspect}の場合は、返答の情報を保持したエラーにする" do
      allow(response).to receive(:output_text).and_return(text)

      expect {
        service.call(instructions: instructions, input: input)
      }.to raise_error(described_class::ResponseError) { |error|
        expect(error.response).to equal(response)
      }
    end
  end

  it "通信失敗のエラーをそのまま呼び出し元へ伝える" do
    error = OpenAI::Errors::APIConnectionError.new(
      url: URI("https://api.openai.com/v1/responses")
    )
    allow(responses_api).to receive(:create).and_raise(error)

    expect {
      service.call(instructions: instructions, input: input)
    }.to raise_error(OpenAI::Errors::APIConnectionError) { |raised|
      expect(raised).to equal(error)
    }
  end

  it "時間切れのエラーをそのまま呼び出し元へ伝える" do
    error = OpenAI::Errors::APITimeoutError.new(
      url: URI("https://api.openai.com/v1/responses")
    )
    allow(responses_api).to receive(:create).and_raise(error)

    expect {
      service.call(instructions: instructions, input: input)
    }.to raise_error(OpenAI::Errors::APITimeoutError) { |raised|
      expect(raised).to equal(error)
    }
  end
end
