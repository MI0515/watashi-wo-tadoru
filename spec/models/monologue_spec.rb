require "rails_helper"

RSpec.describe Monologue, type: :model do
  it "タイプと本文があれば有効になる" do
    monologue = build(:monologue)

    expect(monologue).to be_valid
  end

  it "タイプがなければ無効になる" do
    monologue = build(:monologue, personality_type: nil)

    expect(monologue).to be_invalid
    expect(monologue.errors.of_kind?(:personality_type, :blank)).to be true
  end

  it "本文が空なら無効になる" do
    monologue = build(:monologue, content: "")

    expect(monologue).to be_invalid
    expect(monologue.errors.of_kind?(:content, :blank)).to be true
  end
end
