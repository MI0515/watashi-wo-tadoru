class AiUsagePolicy
  DAILY_START_LIMIT = 3

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
end
