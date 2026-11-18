class ApiUsageRecorder
  def initialize(reflection:, request_kind:, initial_reply: false, retrying: false)
    @reflection = reflection
    @request_kind = request_kind
    @initial_reply = initial_reply
    @retrying = retrying
  end

  def call
    log = @reflection.api_usage_logs.create!(
      user: @reflection.user,
      request_kind: @request_kind,
      initial_reply: @initial_reply,
      retry: @retrying
    )

    begin
      response = yield
    rescue OpenaiClient::ResponseError => error
      # 返答が未完了でも、APIから取得できた使用量は残す
      save_response(log, error.response, :failed)
      raise
    rescue OpenAI::Errors::APITimeoutError
      log.update!(status: :timed_out)
      raise
    rescue StandardError
      log.update!(status: :failed)
      raise
    else
      save_response(log, response, :succeeded)
      response
    end
  end

  private

  def save_response(log, response, status)
    log.update!(
      status: status,
      response_id: response.id,
      input_tokens: response.usage&.input_tokens,
      output_tokens: response.usage&.output_tokens
    )
  end
end
