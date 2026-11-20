class AiUsagePolicy
  DAILY_START_LIMIT = 3

  class StoppedError < StandardError
  end

  class LimitError < StandardError
  end

  def initialize(user:, now: Time.current)
    @user = user
    @now = now
  end

  # 日付をまたぐ通信も、初回返信の取得に成功した日の利用として数える
  def daily_start_count
    @user.api_usage_logs
      .request_kind_dialogue
      .status_succeeded
      .where(initial_reply: true)
      .where(updated_at: @now.in_time_zone("Tokyo").all_day)
      .count
  end

  def start_limit_reached?
    daily_start_count >= DAILY_START_LIMIT
  end

  def stopped?
    ENV.fetch("AI_ENABLED", "true") != "true"
  end

  def ensure_enabled!
    if stopped?
      raise StoppedError, "AI機能は現在、一時停止しています。時間をおいてからご利用ください。"
    end
  end

  def ensure_start_available!
    if start_limit_reached?
      raise LimitError, "本日の振り返り開始は3回までです。日本時間の翌日0時から、再び始められます。"
    end

    logs = @user.api_usage_logs
      .request_kind_dialogue
      .where(initial_reply: true)

    # 同時に開始する処理も枠に含め、成功回数だけの確認による超過を防ぐ
    occupied_count = logs.status_processing.or(
      logs.status_succeeded.where(
        updated_at: @now.in_time_zone("Tokyo").all_day
      )
    ).count

    if occupied_count >= DAILY_START_LIMIT
      raise LimitError, "ほかの振り返りの初回返信を生成中です。完了してから、もう一度お試しください。"
    end
  end
end
