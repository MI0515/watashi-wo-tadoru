# 中断したケースBの、最後の1返信だけを取得する。
# 実行するとAPI料金が発生する。自動再試行はしない。

source_path = Rails.root.join(
  "tmp/openai-verification/case-b-20261022-092650-473522346.json"
)

log_path = Rails.root.join(
  "tmp/openai-verification/case-b-20261022-092650-473522346-resumed.json"
)

# 誤って繰り返し送信することを防ぐ。
abort "再開用の記録が既にあります。再送せず、内容を確認してください。" if log_path.exist?

# 保存時のプロンプト・設定・会話履歴を、そのまま読み込む。
record = JSON.parse(source_path.read, symbolize_names: true)

unless record[:turns].size == 3 &&
       record[:turns].all? { |item| item[:status] == "completed" } &&
       record[:history].last[:role] == "assistant"
  abort "想定した中断状態ではありません。API送信はしていません。"
end

reply = "昼ごはん食べて休憩にソファに寝転がってからずっとスマホでショート動画とかスワイプして見続けて、起き上がれないまま3時間も無駄にした"

record[:history] << { role: :user, content: reply }
record[:resumed_at] = Time.current.iso8601
record[:resumed_from] = source_path.basename.to_s

turn_instruction = <<~TEXT
  今回は4回目で、通常対話の最終返信です。
  共通指示の【最終返信】に従ってください。
  ただし、【安全を優先する例外】は最終返信の制約より優先します。
TEXT

instructions = "#{record[:prompt]}\n\n#{turn_instruction}"
client = OpenAI::Client.new(max_retries: 0, timeout: 60)

# 送信前にも記録を保存し、再実行による重複送信を防ぐ。
log_path.write(JSON.pretty_generate(record))

started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

begin
  response = client.responses.create(
    **record[:settings],
    instructions: instructions,
    input: record[:history]
  )
rescue OpenAI::Errors::APIError => e
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

  record[:turns] << {
    turn: 4,
    turn_instruction: turn_instruction,
    elapsed_seconds: elapsed.round(2),
    error_class: e.class.name,
    error_message: e.message
  }

  log_path.write(JSON.pretty_generate(record))
  abort "API通信に失敗しました。再実行せず、記録を確認してください。"
end

elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

record[:history] << { role: :assistant, content: response.output_text }
record[:turns] << {
  turn: 4,
  turn_instruction: turn_instruction,
  response_id: response.id,
  model: response.model,
  status: response.status,
  elapsed_seconds: elapsed.round(2),
  usage: response.usage&.to_h,
  incomplete_details: response.incomplete_details&.to_h,
  text: response.output_text
}

log_path.write(JSON.pretty_generate(record))

puts "【ケースB：4回目の返信】"
puts response.output_text
puts "状態：#{response.status}"
puts "所要時間：#{elapsed.round(2)}秒"
puts "使用量：#{response.usage&.to_h.to_json}"
puts "記録先：#{log_path}"

if response.status.to_s != "completed"
  puts "未完了の詳細：#{response.incomplete_details&.to_h.to_json}"
  abort "生成が完了していません。記録を確認してください。"
end

if response.output_text.to_s.strip.empty?
  abort "表示できる返答がありません。記録を確認してください。"
end
