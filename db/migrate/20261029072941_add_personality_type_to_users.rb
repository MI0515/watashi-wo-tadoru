class AddPersonalityTypeToUsers < ActiveRecord::Migration[8.1]
  def change
    # 初期設定前のユーザーは、タイプが未設定でもよい
    add_reference :users, :personality_type,
                  null: true,
                  foreign_key: true
  end
end
