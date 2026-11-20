class ReflectionSummary
  class NotReadyError < StandardError
  end

  class InProgressError < NotReadyError
  end

  def initialize(reflection:, generator: nil)
    @reflection = reflection
    @generator = generator
  end

  def call
    generation_started = false
    retrying = false

    @reflection.with_lock do
      return @reflection if @reflection.summary_available?

      if @reflection.ai_response_processing?
        raise InProgressError, "まとめを生成中です。"
      end

      last_message = @reflection.reflection_messages.order(:position).last
      unless @reflection.in_progress? &&
             @reflection.additional_reply_limit_reached? &&
             last_message&.assistant?
        raise NotReadyError, "今はまとめを生成できません。"
      end

      retrying = @reflection.api_usage_logs.request_kind_summary.exists?
      @reflection.update!(
        ai_response_status: :processing,
        ai_response_started_at: Time.current
      )
      generation_started = true
    end

    # APIの応答待ちではロックを保持せず、生成中の状態で二重実行を防ぐ
    generator = @generator || ReflectionSummaryGenerator.new(reflection: @reflection)
    summary = generator.call(retrying: retrying)

    @reflection.with_lock do
      @reflection.update!(
        summary.merge(
          ai_response_status: :idle,
          ai_response_started_at: nil
        )
      )
    end

    @reflection
  rescue StandardError
    # 別のリクエストを拒否しただけの場合は、進行中の状態を変更しない
    if generation_started
      @reflection.with_lock do
        @reflection.update!(ai_response_status: :failed)
      end
    end

    raise
  end
end
