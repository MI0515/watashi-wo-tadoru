class ReflectionDialogue
  def initialize(reflection:, client: nil)
    @reflection = reflection
    @client = client || OpenaiClient.new
  end

  def call(final_reply: false, retrying: false)
    # 設定変更後も、この振り返りを始めたミツメイトの話し方を使う
    instructions = ReflectionPrompt.call(
      speaking_style: @reflection.companion.speaking_style,
      final_reply: final_reply
    )

    input = build_input

    recorder = ApiUsageRecorder.new(
      reflection: @reflection,
      request_kind: :dialogue,
      initial_reply: input.size == 1,
      retrying: retrying
    )

    recorder.call do
      @client.call(instructions: instructions, input: input)
    end
  end

  private

  def build_input
    emotion_names = @reflection.emotions.order(:display_order, :id).pluck(:name)

    initial_content = [
      "選択した感情：#{emotion_names.empty? ? 'なし' : emotion_names.join('・')}",
      "",
      "最初の入力：",
      @reflection.initial_text
    ].join("\n")

    # 初回入力とは別に保存している追加の発言を、発言順に積み上げる
    history = @reflection.reflection_messages.order(:position).map do |message|
      { role: message.role.to_sym, content: message.content }
    end

    [ { role: :user, content: initial_content } ] + history
  end
end
