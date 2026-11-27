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

  it "振り返りを削除しても、当日の開始回数と上限到達状態を維持する" do
    3.times { record_usage }

    expect(policy.daily_start_count).to eq(3)

    reflection.destroy!

    expect(policy.daily_start_count).to eq(3)
    expect(policy.start_limit_reached?).to be true
    expect(user.api_usage_logs.count).to eq(3)
    expect(user.api_usage_logs.where.not(reflection_id: nil)).to be_empty

    expect {
      policy.ensure_start_available!
    }.to raise_error(AiUsagePolicy::LimitError, /翌日0時/)
  end

  it "AIが有効なら利用を拒否しない" do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("AI_ENABLED", "true").and_return("true")

    expect { policy.ensure_enabled! }.not_to raise_error
  end

  it "AIが停止中なら停止理由を返す" do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("AI_ENABLED", "true").and_return("false")

    expect {
      policy.ensure_enabled!
    }.to raise_error(AiUsagePolicy::StoppedError, /一時停止/)
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
