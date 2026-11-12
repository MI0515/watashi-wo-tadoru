require "rails_helper"

RSpec.describe Reflection, type: :model do
  it "感情未選択でも保存でき、初期状態は対話中になる" do
    reflection = create(:reflection)

    reflection.reload
    expect(reflection).to be_in_progress
    expect(reflection.emotions).to be_empty
    expect(reflection.completed_at).to be_nil
  end

  it "最初の入力が空白だけなら無効になる" do
    reflection = build(:reflection, initial_text: "   ")

    expect(reflection).to be_invalid
    expect(reflection.errors.of_kind?(:initial_text, :blank)).to be true
  end

  it "最初の入力が400文字なら有効になる" do
    reflection = build(:reflection, initial_text: "あ" * 400)

    expect(reflection).to be_valid
  end

  it "最初の入力が401文字なら無効になる" do
    reflection = build(:reflection, initial_text: "あ" * 401)

    expect(reflection).to be_invalid
    expect(reflection.errors.of_kind?(:initial_text, :too_long)).to be true
  end

  it "ユーザーがなければ無効になる" do
    reflection = build(:reflection, user: nil)

    expect(reflection).to be_invalid
    expect(reflection.errors.of_kind?(:user, :blank)).to be true
  end

  it "ミツメイトがなければ無効になる" do
    reflection = build(:reflection, companion: nil)

    expect(reflection).to be_invalid
    expect(reflection.errors.of_kind?(:companion, :blank)).to be true
  end

  it "定義されていない状態は無効になる" do
    reflection = build(:reflection, status: "unknown")

    expect(reflection).to be_invalid
    expect(reflection.errors.of_kind?(:status, :inclusion)).to be true
  end

  it "状態が未設定なら無効になる" do
    reflection = build(:reflection, status: nil)

    expect(reflection).to be_invalid
    expect(reflection.errors.of_kind?(:status, :inclusion)).to be true
  end
end
