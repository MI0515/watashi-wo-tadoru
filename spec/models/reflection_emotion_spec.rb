require "rails_helper"

RSpec.describe ReflectionEmotion, type: :model do
  it "振り返りと感情があれば保存できる" do
    reflection_emotion = create(:reflection_emotion)

    expect(reflection_emotion.reflection.emotions)
      .to include(reflection_emotion.emotion)
  end

  it "振り返りがなければ無効になる" do
    reflection_emotion = build(:reflection_emotion, reflection: nil)

    expect(reflection_emotion).to be_invalid
    expect(reflection_emotion.errors.of_kind?(:reflection, :blank)).to be true
  end

  it "感情がなければ無効になる" do
    reflection_emotion = build(:reflection_emotion, emotion: nil)

    expect(reflection_emotion).to be_invalid
    expect(reflection_emotion.errors.of_kind?(:emotion, :blank)).to be true
  end

  it "同じ振り返りに同じ感情を重複して登録できない" do
    existing = create(:reflection_emotion)
    duplicate = build(
      :reflection_emotion,
      reflection: existing.reflection,
      emotion: existing.emotion
    )

    expect(duplicate).to be_invalid
    expect(duplicate.errors.of_kind?(:emotion_id, :taken)).to be true
  end

  it "同じ感情でも別の振り返りなら登録できる" do
    existing = create(:reflection_emotion)
    other_reflection = create(
      :reflection,
      user: existing.reflection.user,
      companion: existing.reflection.companion
    )
    reflection_emotion = build(
      :reflection_emotion,
      reflection: other_reflection,
      emotion: existing.emotion
    )

    expect(reflection_emotion).to be_valid
  end
end
