require "rails_helper"

RSpec.describe Emotion, type: :model do
  it "名前と表示順が正しければ有効になる" do
    emotion = build(:emotion)

    expect(emotion).to be_valid
  end

  it "名前が空なら無効になる" do
    emotion = build(:emotion, name: "")

    expect(emotion).to be_invalid
    expect(emotion.errors.of_kind?(:name, :blank)).to be true
  end

  it "同じ名前を重複して登録できない" do
    existing_emotion = create(:emotion)
    emotion = build(:emotion, name: existing_emotion.name)

    expect(emotion).to be_invalid
    expect(emotion.errors.of_kind?(:name, :taken)).to be true
  end

  it "表示順が空なら無効になる" do
    emotion = build(:emotion, display_order: nil)

    expect(emotion).to be_invalid
    expect(emotion.errors.of_kind?(:display_order, :blank)).to be true
  end

  it "表示順が0なら無効になる" do
    emotion = build(:emotion, display_order: 0)

    expect(emotion).to be_invalid
    expect(emotion.errors.of_kind?(:display_order, :greater_than)).to be true
  end

  it "表示順が負の数なら無効になる" do
    emotion = build(:emotion, display_order: -1)

    expect(emotion).to be_invalid
    expect(emotion.errors.of_kind?(:display_order, :greater_than)).to be true
  end

  it "表示順が小数なら無効になる" do
    emotion = build(:emotion, display_order: 1.5)

    expect(emotion).to be_invalid
    expect(emotion.errors.of_kind?(:display_order, :not_an_integer)).to be true
  end
end
