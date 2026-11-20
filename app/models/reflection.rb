class Reflection < ApplicationRecord
  MAX_ADDITIONAL_REPLIES = 3

  belongs_to :user
  belongs_to :companion
  has_many :reflection_emotions, dependent: :destroy
  has_many :emotions, through: :reflection_emotions
  has_many :reflection_messages, dependent: :destroy
  has_many :api_usage_logs, dependent: :nullify

  # フォーム表示時点で、再送時にも同じ値を使える送信IDを用意する
  attribute :submission_token, default: -> { SecureRandom.uuid }

  enum :status, { in_progress: 0, completed: 1 }, validate: true

  enum :ai_response_status,
       { idle: 0, processing: 1, failed: 2 },
       prefix: :ai_response,
       validate: true

  validates :initial_text, presence: true, length: { maximum: 400 }
  validates :submission_token, presence: true

  # 初回入力は別に保存しているため、追加の利用者発言だけを数える
  def additional_reply_limit_reached?
    reflection_messages.where(role: :user).count >= MAX_ADDITIONAL_REPLIES
  end

  def summary_available?
    title.present? && valued_thing.present? && insight.present?
  end
end
