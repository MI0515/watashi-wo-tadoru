class Emotion < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  # 表示順は1から始まる整数にする
  validates :display_order,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 }
end
