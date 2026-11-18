class ReflectionReply
  class NotReadyError < StandardError
  end

  class InProgressError < NotReadyError
  end

  def initialize(reflection:, dialogue: nil)
    @reflection = reflection
    @dialogue = dialogue
  end

  def call(content:, reply_to_id:, final_reply: false)
    generation_started = false
    user_message = nil

    # 発言の保存と生成開始をまとめ、同時に追加送信を受け付けないようにする
    @reflection.with_lock do
      if @reflection.ai_response_processing?
        raise InProgressError, "AIの返答を生成中です。"
      end

      last_message = @reflection.reflection_messages.order(:position).last

      unless @reflection.in_progress? && last_message&.assistant?
        raise NotReadyError, "返答を送信できる状態ではありません。"
      end

      # 古い画面や遅れて届いた送信を、次の問いへの返答として保存しない
      unless reply_to_id.present? && reply_to_id.to_s == last_message.id.to_s
        raise NotReadyError, "表示中の会話が更新されています。"
      end

      user_message = @reflection.reflection_messages.create!(
        role: :user,
        content: content,
        position: last_message.position + 1
      )

      @reflection.update!(
        ai_response_status: :processing,
        ai_response_started_at: Time.current
      )
      generation_started = true
    end

    # APIの応答待ちの間は、DBのロックを保持しない
    dialogue = @dialogue || ReflectionDialogue.new(reflection: @reflection)
    response = dialogue.call(final_reply: final_reply)

    @reflection.with_lock do
      reply = @reflection.reflection_messages.create!(
        role: :assistant,
        content: response.output_text,
        position: user_message.position + 1
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
