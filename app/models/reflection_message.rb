class ReflectionMessage < ApplicationRecord
  belongs_to :reflection

  enum :role, { user: 0, assistant: 1 }, validate: true

  validates :content, presence: true

  validates :position,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 },
            uniqueness: { scope: :reflection_id }
end
