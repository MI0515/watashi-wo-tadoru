class ApiUsageRecorder
  def initialize(reflection:, request_kind:, initial_reply: false, retrying: false)
    @reflection = reflection
    @request_kind = request_kind
    @initial_reply = initial_reply
    @retrying = retrying
  end

  def call
    log = reserve_request

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

  def reserve_request
    user = @reflection.user

    # 上限確認と枠の確保を直列化し、別の振り返りの同時開始でも超過させない
    user.with_lock do
      policy = AiUsagePolicy.new(user: user)
      policy.ensure_enabled!
      policy.ensure_start_available! if @initial_reply

      @reflection.api_usage_logs.create!(
        user: user,
        request_kind: @request_kind,
        initial_reply: @initial_reply,
        retry: @retrying
      )
    end
  end

  def save_response(log, response, status)
    log.update!(
      status: status,
      response_id: response.id,
      input_tokens: response.usage&.input_tokens,
      output_tokens: response.usage&.output_tokens
    )
  end
end
