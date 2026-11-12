class Reflection < ApplicationRecord
  belongs_to :user
  belongs_to :companion
  has_many :reflection_emotions, dependent: :destroy
  has_many :emotions, through: :reflection_emotions

  enum :status, { in_progress: 0, completed: 1 }, validate: true

  validates :initial_text, presence: true, length: { maximum: 400 }
end
