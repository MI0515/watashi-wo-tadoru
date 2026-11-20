require "rails_helper"

RSpec.describe AiUsagePolicy do
  let(:user) { create(:user) }
  let(:reflection) { create(:reflection, user: user) }
  let(:now) { Time.zone.local(2026, 11, 20, 12) }
  let(:policy) { described_class.new(user: user, now: now) }

  it "本人の初回対話の成功だけを数える" do
    record_usage
    record_usage(status: :processing)
    record_usage(status: :failed)
    record_usage(status: :timed_out)
    record_usage(initial_reply: false)
    record_usage(request_kind: :summary)

    create(
      :api_usage_log,
      user: create(:user),
      reflection: nil,
      created_at: now,
      updated_at: now
    )

    expect(policy.daily_start_count).to eq(1)
  end

  it "初回取得に失敗しても、再試行で成功すれば1回と数える" do
    record_usage(status: :failed)
    record_usage(retry: true)

    expect(policy.daily_start_count).to eq(1)
  end

  it "通信開始日ではなく、日本時間で成功した日を数える" do
    record_usage(
      created_at: Time.utc(2026, 11, 19, 14, 59),
      updated_at: Time.utc(2026, 11, 19, 15, 0)
    )
    record_usage(updated_at: Time.utc(2026, 11, 20, 14, 59, 59))
    record_usage(updated_at: Time.utc(2026, 11, 19, 14, 59, 59))
    record_usage(updated_at: Time.utc(2026, 11, 20, 15, 0))

    expect(policy.daily_start_count).to eq(2)
  end

  it "2回では上限未到達、3回で上限到達になる" do
    2.times { record_usage }

    expect(policy.start_limit_reached?).to be false

    record_usage

    expect(policy.start_limit_reached?).to be true
  end

  def record_usage(**attributes)
    create(
      :api_usage_log,
      user: user,
      reflection: reflection,
      created_at: now,
      updated_at: now,
      **attributes
    )
  end
end
