class CreateReflectionMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :reflection_messages do |t|
      t.references :reflection, null: false, foreign_key: { on_delete: :cascade }
      t.integer :role, null: false
      t.text :content, null: false
      t.integer :position, null: false

      t.timestamps
    end

    # 同じ振り返り内で発言順が重複することを防ぐ
    add_index :reflection_messages,
              [ :reflection_id, :position ],
              unique: true
  end
end
