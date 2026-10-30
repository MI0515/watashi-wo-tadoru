require "rails_helper"

RSpec.describe Companion, type: :model do
  it "必要な情報がそろっていれば有効になる" do
    companion = build(:companion)

    expect(companion).to be_valid
  end

  it "タイプが未設定なら無効になる" do
    companion = build(:companion, personality_type: nil)

    expect(companion).to be_invalid
  end

  it "同じタイプ・同じ見た目は重複して登録できない" do
    existing = create(:companion)
    companion = build(
      :companion,
      personality_type: existing.personality_type
    )

    expect(companion).to be_invalid
  end

  it "タイプが違えば、同じ見た目でも登録できる" do
    create(:companion)
    infp = create(:personality_type, code: "INFP", group_code: "NF")
    companion = build(
      :companion,
      personality_type: infp,
      sd_image_path: "companions/nf-animal-sd.png",
      full_image_path: "companions/nf-animal-full.png"
    )

    expect(companion).to be_valid
  end

  it "同じタイプでも、見た目が違えば登録できる" do
    existing = create(:companion)
    companion = build(
      :companion,
      personality_type: existing.personality_type,
      appearance_type: "male",
      sd_image_path: "companions/intp-male-sd.png",
      full_image_path: "companions/intp-male-full.png"
    )

    expect(companion).to be_valid
  end

  it "定義されていない見た目は無効になる" do
    companion = build(:companion, appearance_type: "unknown")

    expect(companion).to be_invalid
  end

  it "定義されていない話し方は無効になる" do
    companion = build(:companion, speaking_style: "unknown")

    expect(companion).to be_invalid
  end

  it "画像パスが未設定なら無効になる" do
    companion = build(
      :companion,
      sd_image_path: nil,
      full_image_path: nil
    )

    expect(companion).to be_invalid
  end

  it "SD画像のパスから顔アイコンのパスを取得できる" do
    companion = build(:companion)

    expect(companion.icon_image_path)
      .to eq("companions/nt-animal-icon.png")
  end
end
