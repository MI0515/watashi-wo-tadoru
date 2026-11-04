class Monologue < ApplicationRecord
  belongs_to :personality_type

  validates :content, presence: true
end
