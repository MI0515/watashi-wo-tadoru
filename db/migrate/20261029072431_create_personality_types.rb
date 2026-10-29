class CreatePersonalityTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :personality_types do |t|
      # タイプとグループは必須
      t.string :code, null: false
      t.string :group_code, null: false

      t.timestamps
    end

    # 同じタイプの重複登録をDB側でも防ぐ
    add_index :personality_types, :code, unique: true
  end
end
