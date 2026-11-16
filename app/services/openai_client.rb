class OpenaiClient
  class ResponseError < StandardError
    attr_reader :response

    # 未完了や空の返答でも、使用量などを呼び出し元で確認できるようにする
    def initialize(message, response:)
      @response = response
      super(message)
    end
  end

  def initialize(client: nil)
    @client = client || OpenAI::Client.new(max_retries: 0, timeout: 60)
  end

  def call(instructions:, input:)
    response = @client.responses.create(
      model: "gpt-6.1-sol",
      instructions: instructions,
      input: input,
      reasoning: { effort: :low },
      max_output_tokens: 4096,
      service_tier: :default,
      store: false
    )

    unless response.status.to_s == "completed"
      raise ResponseError.new(
        "AIの応答生成が完了しませんでした。",
        response: response
      )
    end

    if response.output_text.to_s.strip.empty?
      raise ResponseError.new(
        "表示できるAIの返答がありませんでした。",
        response: response
      )
    end

    response
  end
end
