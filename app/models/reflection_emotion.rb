class ReflectionEmotion < ApplicationRecord
  belongs_to :reflection
  belongs_to :emotion
  validates :emotion_id, uniqueness: { scope: :reflection_id }
end
