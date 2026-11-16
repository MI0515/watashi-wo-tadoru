class ReflectionInitialReply
  def initialize(reflection:, dialogue: nil)
    @reflection = reflection
    @dialogue = dialogue
  end

  def call
    # 保存済みの初回返答があれば、再生成せずに返す
    existing_reply = @reflection.reflection_messages.find_by(
      role: :assistant,
      position: 1
    )
    return existing_reply if existing_reply

    dialogue = @dialogue || ReflectionDialogue.new(reflection: @reflection)
    response = dialogue.call

    @reflection.reflection_messages.create!(
      role: :assistant,
      content: response.output_text,
      position: 1
    )
  end
end
