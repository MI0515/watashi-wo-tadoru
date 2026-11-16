class ReflectionReply
  class NotReadyError < StandardError
  end

  def initialize(reflection:, dialogue: nil)
    @reflection = reflection
    @dialogue = dialogue
  end

  def call(content:, final_reply: false)
    last_message = @reflection.reflection_messages.order(:position).last

    unless @reflection.in_progress? && last_message&.assistant?
      raise NotReadyError, "返答を送信できる状態ではありません。"
    end

    # 通信に失敗しても入力を失わないよう、利用者の発言を先に保存する
    user_message = @reflection.reflection_messages.create!(
      role: :user,
      content: content,
      position: last_message.position + 1
    )

    dialogue = @dialogue || ReflectionDialogue.new(reflection: @reflection)
    response = dialogue.call(final_reply: final_reply)

    @reflection.reflection_messages.create!(
      role: :assistant,
      content: response.output_text,
      position: user_message.position + 1
    )
  end
end
