class ReflectionRetry
  class NotReadyError < StandardError
  end

  class InProgressError < NotReadyError
  end

  def initialize(reflection:, dialogue: nil)
    @reflection = reflection
    @dialogue = dialogue
  end

  def call(last_message_id:)
    generation_started = false
    reply_position = nil
    final_reply = false

    @reflection.with_lock do
      if @reflection.ai_response_processing?
        raise InProgressError, "AIの返答を生成中です。"
      end

      last_message = @reflection.reflection_messages.order(:position).last

      unless @reflection.in_progress? && @reflection.ai_response_failed? &&
             (last_message.nil? || last_message.user?) &&
             last_message_id.to_s == last_message&.id.to_s
        raise NotReadyError, "今は再試行できません。"
      end

      final_reply = @reflection.additional_reply_limit_reached?
      reply_position = last_message ? last_message.position + 1 : 1

      @reflection.update!(
        ai_response_status: :processing,
        ai_response_started_at: Time.current
      )
      generation_started = true
    end

    # 保存済みの会話を使い、利用者の発言は追加しない
    dialogue = @dialogue || ReflectionDialogue.new(reflection: @reflection)
    response = dialogue.call(final_reply: final_reply, retrying: true)

    @reflection.with_lock do
      reply = @reflection.reflection_messages.create!(
        role: :assistant,
        content: response.output_text,
        position: reply_position
      )

      @reflection.update!(
        ai_response_status: :idle,
        ai_response_started_at: nil
      )

      reply
    end
  rescue StandardError
    # 拒否された別リクエストが、進行中の生成状態を変更しないようにする
    if generation_started
      @reflection.with_lock do
        @reflection.update!(ai_response_status: :failed)
      end
    end

    raise
  end
end
