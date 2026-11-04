class PersonalityType < ApplicationRecord
  has_many :users
  has_many :companions
  has_many :monologues

  # タイプのコードは必須で、重複を許可しない
  validates :code, presence: true, uniqueness: true

  # グループは4種類のいずれかにする
  validates :group_code,
            presence: true,
            inclusion: { in: %w[NT NF SP SJ] }

  # このタイプの独り言から、ランダムに1件取り出す
  def random_monologue
    monologues.order(Arel.sql("RANDOM()")).first
  end
end
