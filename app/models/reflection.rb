class Reflection < ApplicationRecord
  belongs_to :user
  belongs_to :companion
  has_many :reflection_emotions, dependent: :destroy
  has_many :emotions, through: :reflection_emotions
  has_many :reflection_messages, dependent: :destroy

  # フォーム表示時点で、再送時にも同じ値を使える送信IDを用意する
  attribute :submission_token, default: -> { SecureRandom.uuid }

  enum :status, { in_progress: 0, completed: 1 }, validate: true

  enum :ai_response_status,
       { idle: 0, processing: 1, failed: 2 },
       prefix: :ai_response,
       validate: true

  validates :initial_text, presence: true, length: { maximum: 400 }
  validates :submission_token, presence: true
end
