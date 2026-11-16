class ReflectionMessage < ApplicationRecord
  belongs_to :reflection

  enum :role, { user: 0, assistant: 1 }, validate: true

  validates :content, presence: true

  # AIの生成文には、利用者の入力文字数の上限を適用しない
  validates :content, length: { maximum: 400 }, if: :user?

  validates :position,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 },
            uniqueness: { scope: :reflection_id }
end
