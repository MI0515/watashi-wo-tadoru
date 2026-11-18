class ReflectionInitialReply
  class InProgressError < StandardError
  end

  def initialize(reflection:, dialogue: nil)
    @reflection = reflection
    @dialogue = dialogue
  end

  def call
    generation_started = false

    # 状態確認と生成開始の記録をまとめ、同時に生成を開始しないようにする
    @reflection.with_lock do
      existing_reply = @reflection.reflection_messages.find_by(
        role: :assistant,
        position: 1
      )
      return existing_reply if existing_reply

      if @reflection.ai_response_processing?
        raise InProgressError, "AIの返答を生成中です。"
      end

      @reflection.update!(
        ai_response_status: :processing,
        ai_response_started_at: Time.current
      )
      generation_started = true
    end

    # APIの応答待ちの間は、DBのロックを保持しない
    dialogue = @dialogue || ReflectionDialogue.new(reflection: @reflection)
    response = dialogue.call

    @reflection.with_lock do
      reply = @reflection.reflection_messages.create!(
        role: :assistant,
        content: response.output_text,
        position: 1
      )

      @reflection.update!(
        ai_response_status: :idle,
        ai_response_started_at: nil
      )

      reply
    end
  rescue StandardError
    # 生成中として拒否された別リクエストが、状態を失敗へ変更しないようにする
    if generation_started
      @reflection.with_lock do
        @reflection.update!(ai_response_status: :failed)
      end
    end

    raise
  end
end
