require "digest"

# #30のまとめ生成検証専用。
# 保存済みの会話を読み込み、APIを1回だけ呼び出す。
# 元の会話記録は変更しない。

log_directory = Rails.root.join("tmp/openai-verification")
source_path = log_directory.join(
  "case-d-20261022-102634-059465005.json"
)

source = JSON.parse(source_path.read, symbolize_names: true)
turns = source.fetch(:turns)
history = source.fetch(:history)

# 完了済みのケースDを使うことを、送信前に確認する。
unless source[:case] == "D" &&
       turns.size == 4 &&
       turns.all? { |item| item[:status] == "completed" } &&
       history.last[:role] == "assistant"
  abort "完了済みのケースDではありません。API送信はしていません。"
end

prompt = Rails.root.join("script/summary_prompt.txt").read
abort "まとめ用プロンプトが空です。API送信はしていません。" if prompt.strip.empty?

# 会話検証と同じモデル・設定で比較する。
settings = source.fetch(:settings)
client = OpenAI::Client.new(max_retries: 0, timeout: 60)

timestamp = Time.current.strftime("%Y%m%d-%H%M%S-%N")
log_path = log_directory.join("summary-d-#{timestamp}.json")

record = {
  case: "D",
  purpose: "summary",
  source_file: source_path.basename.to_s,
  started_at: Time.current.iso8601,
  prompt_version: "summary-v2",
  prompt_digest: Digest::SHA256.hexdigest(prompt),
  prompt: prompt,
  settings: settings,
  history: history
}

# 会話後に、利用者がまとめ生成を選んだ場面を再現する。
input = history + [
  {
    role: :user,
    content: "ここまでの対話を、指定された3項目でまとめてください。"
  }
]

puts "ケースDの保存済み会話から、まとめを1回生成します。"
puts "記録先：#{log_path}"

started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

begin
  response = client.responses.create(
    **settings,
    instructions: prompt,
    input: input
  )
rescue OpenAI::Errors::APIError => e
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

  record[:result] = {
    elapsed_seconds: elapsed.round(2),
    error_class: e.class.name,
    error_message: e.message
  }

  log_path.write(JSON.pretty_generate(record))
  abort "API通信に失敗しました。記録を確認してください。"
end

elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

record[:result] = {
  response_id: response.id,
  model: response.model,
  status: response.status,
  elapsed_seconds: elapsed.round(2),
  usage: response.usage&.to_h,
  incomplete_details: response.incomplete_details&.to_h,
  text: response.output_text
}

# 未完了でも、結果と使用量を保存する。
log_path.write(JSON.pretty_generate(record))

puts
puts response.output_text
puts "状態：#{response.status}"
puts "所要時間：#{elapsed.round(2)}秒"
puts "使用量：#{response.usage&.to_h.to_json}"

unless response.status.to_s == "completed"
  puts "未完了の詳細：#{response.incomplete_details&.to_h.to_json}"
  abort "生成が完了していません。記録を確認してください。"
end

if response.output_text.to_s.strip.empty?
  abort "表示できるまとめがありません。記録を確認してください。"
end

puts "記録先：#{log_path}"
