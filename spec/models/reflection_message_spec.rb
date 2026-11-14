require "rails_helper"

RSpec.describe ReflectionMessage, type: :model do
  it "利用者とAIの発言を区別して保存できる" do
    reflection = create(:reflection)
    user_message = create(
      :reflection_message,
      reflection: reflection,
      role: :user,
      position: 1
    )
    assistant_message = create(
      :reflection_message,
      reflection: reflection,
      role: :assistant,
      position: 2
    )

    expect(user_message.reload).to be_user
    expect(assistant_message.reload).to be_assistant
    expect(reflection.reflection_messages)
      .to match_array([ user_message, assistant_message ])
  end

  it "振り返りがなければ無効になる" do
    message = build(:reflection_message, reflection: nil)

    expect(message).to be_invalid
    expect(message.errors.of_kind?(:reflection, :blank)).to be true
  end

  it "本文が空白だけなら無効になる" do
    message = build(:reflection_message, content: "   ")

    expect(message).to be_invalid
    expect(message.errors.of_kind?(:content, :blank)).to be true
  end

  it "定義されていない発言者は無効になる" do
    message = build(:reflection_message, role: "unknown")

    expect(message).to be_invalid
    expect(message.errors.of_kind?(:role, :inclusion)).to be true
  end

  it "発言者が未設定なら無効になる" do
    message = build(:reflection_message, role: nil)

    expect(message).to be_invalid
    expect(message.errors.of_kind?(:role, :inclusion)).to be true
  end

  [ nil, 0, -1, 1.5 ].each do |position|
    it "発言順が#{position.inspect}なら無効になる" do
      message = build(:reflection_message, position: position)

      expect(message).to be_invalid
      expect(message.errors[:position]).not_to be_empty
    end
  end

  it "同じ振り返り内で発言順を重複させられない" do
    existing = create(:reflection_message)
    duplicate = build(
      :reflection_message,
      reflection: existing.reflection,
      position: existing.position
    )

    expect(duplicate).to be_invalid
    expect(duplicate.errors.of_kind?(:position, :taken)).to be true
  end

  it "別の振り返りなら同じ発言順を使える" do
    existing = create(:reflection_message)
    other_reflection = create(
      :reflection,
      user: existing.reflection.user,
      companion: existing.reflection.companion
    )
    message = build(
      :reflection_message,
      reflection: other_reflection,
      position: existing.position
    )

    expect(message).to be_valid
  end

  it "モデルの検証を省略しても、DBが発言順の重複を拒否する" do
    existing = create(:reflection_message)
    duplicate = existing.dup

    expect {
      # 制約違反の影響を、この保存処理の範囲でロールバックする
      ReflectionMessage.transaction(requires_new: true) do
        duplicate.save!(validate: false)
      end
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "振り返りを削除すると、その発言も削除される" do
    message = create(:reflection_message)
    reflection = message.reflection

    expect {
      reflection.destroy!
    }.to change { ReflectionMessage.exists?(message.id) }
      .from(true).to(false)
  end
end
