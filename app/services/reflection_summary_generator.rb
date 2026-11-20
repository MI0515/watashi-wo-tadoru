class ReflectionSummaryGenerator
  FIELDS = %w[title valued_thing insight].freeze

  OUTPUT_FORMAT = {
    type: :json_schema,
    name: "reflection_summary",
    strict: true,
    schema: {
      type: "object",
      properties: {
        title: { type: "string" },
        valued_thing: { type: "string" },
        insight: { type: "string" }
      },
      required: FIELDS,
      additionalProperties: false
    }
  }.freeze

  def initialize(reflection:, client: nil)
    @reflection = reflection
    @client = client || OpenaiClient.new
  end

  def call(retrying: false)
    instructions = [
      Rails.root.join("config/prompts/summary.txt").read,
      ReflectionPrompt::STYLE_INSTRUCTIONS.fetch(@reflection.companion.speaking_style)
    ].join("\n\n")

    input = build_input
    summary = nil
    recorder = ApiUsageRecorder.new(
      reflection: @reflection,
      request_kind: :summary,
      retrying: retrying
    )

    recorder.call do
      response = @client.call(
        instructions: instructions,
        input: input,
        text_format: OUTPUT_FORMAT
      )

      # 形式不正も失敗として使用量を記録するため、記録処理の内側で検証する
      summary = parse_summary(response)
      response
    end

    summary
  end

  private

  def build_input
    messages = @reflection.reflection_messages.order(:position).map do |message|
      { role: message.role, content: message.content }
    end

    content = {
      initial_text: @reflection.initial_text,
      selected_emotions: @reflection.emotions.order(:display_order, :id).pluck(:name),
      messages: messages
    }.to_json

    [ { role: :user, content: content } ]
  end

  def parse_summary(response)
    summary = JSON.parse(response.output_text)

    unless summary.is_a?(Hash) && summary.keys.sort == FIELDS.sort &&
           FIELDS.all? { |field| summary[field].is_a?(String) && summary[field].present? }
      invalid_summary!(response)
    end

    summary
  rescue JSON::ParserError
    invalid_summary!(response)
  end

  def invalid_summary!(response)
    raise OpenaiClient::ResponseError.new(
      "まとめを正しい形式で受け取れませんでした。",
      response: response
    )
  end
end
