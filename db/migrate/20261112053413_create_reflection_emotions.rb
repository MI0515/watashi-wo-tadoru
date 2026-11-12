class CreateReflectionEmotions < ActiveRecord::Migration[8.1]
  def change
    create_table :reflection_emotions do |t|
      t.references :reflection, null: false, foreign_key: { on_delete: :cascade }
      t.references :emotion, null: false, foreign_key: { on_delete: :restrict }

      t.timestamps
    end
    # 同じ振り返りに同じ感情が重複して保存されるのを防ぐ
    add_index :reflection_emotions,
              [ :reflection_id, :emotion_id ],
              unique: true
  end
end
