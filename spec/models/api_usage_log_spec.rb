require "rails_helper"

RSpec.describe ApiUsageLog, type: :model do
  it "利用者・振り返り・リクエストの種類・使用量を保存できる" do
    log = create(:api_usage_log)

    expect(log.reload.user).to eq(log.reflection.user)
    expect(log).to be_request_kind_dialogue
    expect(log).to be_status_succeeded
    expect(log.initial_reply).to be true
    expect(log[:retry]).to be false
    expect(log.input_tokens).to eq(100)
    expect(log.output_tokens).to eq(30)
  end

  it "使用量を取得できなかった場合は、0ではなく空欄で保存できる" do
    log = create(
      :api_usage_log,
      status: :timed_out,
      response_id: nil,
      input_tokens: nil,
      output_tokens: nil
    )

    expect(log.reload).to be_status_timed_out
    expect(log.response_id).to be_nil
    expect(log.input_tokens).to be_nil
    expect(log.output_tokens).to be_nil
  end

  it "実際に取得した0トークンを保存できる" do
    log = create(:api_usage_log, input_tokens: 0, output_tokens: 0)

    expect(log.reload.input_tokens).to eq(0)
    expect(log.output_tokens).to eq(0)
  end

  it "利用者がなければ無効になる" do
    log = build(:api_usage_log, user: nil)

    expect(log).to be_invalid
    expect(log.errors.of_kind?(:user, :blank)).to be true
  end

  [ :request_kind, :status ].each do |attribute|
    [ nil, "unknown" ].each do |value|
      it "#{attribute}が#{value.inspect}なら無効になる" do
        log = build(:api_usage_log)
        log.public_send("#{attribute}=", value)

        expect(log).to be_invalid
        expect(log.errors.of_kind?(attribute, :inclusion)).to be true
      end
    end
  end

  [ :initial_reply, :retry ].each do |attribute|
    it "#{attribute}が未設定なら無効になる" do
      log = build(:api_usage_log)
      log[attribute] = nil

      expect(log).to be_invalid
      expect(log.errors.of_kind?(attribute, :inclusion)).to be true
    end
  end

  [ :input_tokens, :output_tokens ].each do |attribute|
    [ -1, 1.5 ].each do |value|
      it "#{attribute}が#{value}なら無効になる" do
        log = build(:api_usage_log)
        log.public_send("#{attribute}=", value)

        expect(log).to be_invalid
        expect(log.errors[attribute]).not_to be_empty
      end
    end
  end

  it "同じ応答IDをDB側で重複保存できない" do
    original = create(:api_usage_log)
    duplicate = original.dup

    expect {
      # 制約違反の影響を、この保存処理の範囲でロールバックする
      described_class.transaction(requires_new: true) do
        duplicate.save!
      end
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "応答IDを取得できなかった履歴は複数保存できる" do
    original = create(:api_usage_log, response_id: nil)
    duplicate = original.dup

    expect(duplicate.save).to be true
  end

  it "振り返りを削除しても、利用者と使用量の記録は残る" do
    log = create(:api_usage_log)
    user = log.user

    log.reflection.destroy!

    expect(log.reload.reflection_id).to be_nil
    expect(log.user).to eq(user)
    expect(log.input_tokens).to eq(100)
    expect(log.output_tokens).to eq(30)
    expect(log).to be_valid
  end

  it "モデルの削除処理を通さなくても、DB側で振り返りとの関連を外す" do
    log = create(:api_usage_log)

    log.reflection.delete

    expect(log.reload.reflection_id).to be_nil
  end

  it "利用者を削除すると、その利用履歴も削除される" do
    log = create(:api_usage_log)

    expect {
      log.user.destroy!
    }.to change { described_class.exists?(log.id) }.from(true).to(false)
  end
end
