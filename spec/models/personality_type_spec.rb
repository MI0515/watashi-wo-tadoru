require "rails_helper"

RSpec.describe PersonalityType, type: :model do
  it "コードとグループが正しければ有効になる" do
    personality_type = build(:personality_type)

    expect(personality_type).to be_valid
  end

  it "コードが空なら無効になる" do
    personality_type = build(:personality_type, code: nil)

    expect(personality_type).to be_invalid
  end

  it "同じコードを重複して登録できない" do
    create(:personality_type, code: "INTP")
    personality_type = build(:personality_type, code: "INTP")

    expect(personality_type).to be_invalid
  end

  it "グループが空なら無効になる" do
    personality_type = build(:personality_type, group_code: nil)

    expect(personality_type).to be_invalid
  end

  it "定義されていないグループは無効になる" do
    personality_type = build(:personality_type, group_code: "XX")

    expect(personality_type).to be_invalid
  end
end
