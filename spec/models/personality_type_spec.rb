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

  describe "#random_monologue" do
    let(:personality_type) { create(:personality_type) }

    before do
      other_type = create(:personality_type, code: "ENFP", group_code: "NF")
      create(:monologue, personality_type: other_type, content: "別タイプの独り言")
    end

    it "このタイプに属する独り言から1件返す" do
      first = create(:monologue, personality_type: personality_type, content: "考える時間が好き。")
      second = create(:monologue, personality_type: personality_type, content: "また別の謎を見つけた。")

      expect([ first, second ]).to include(personality_type.random_monologue)
    end

    it "このタイプに独り言がなければnilを返す" do
      expect(personality_type.random_monologue).to be_nil
    end
  end
end
