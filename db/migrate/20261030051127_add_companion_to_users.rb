class AddCompanionToUsers < ActiveRecord::Migration[8.1]
  def change
    # 初期設定前は、ミツメイトが未選択でもよい
    add_reference :users, :companion,
                  null: true,
                  foreign_key: true
  end
end
