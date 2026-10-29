class PersonalityType < ApplicationRecord
  has_many :users

  # タイプのコードは必須で、重複を許可しない
  validates :code, presence: true, uniqueness: true

  # グループは4種類のいずれかにする
  validates :group_code,
            presence: true,
            inclusion: { in: %w[NT NF SP SJ] }
end
