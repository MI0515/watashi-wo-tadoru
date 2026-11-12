class CreateReflections < ActiveRecord::Migration[8.1]
  def change
    create_table :reflections do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :companion, null: false, foreign_key: { on_delete: :restrict }
      t.text :initial_text, null: false
      t.string :title
      t.text :valued_thing
      t.text :insight
      t.text :personal_note
      t.integer :status, null: false, default: 0
      t.datetime :completed_at

      t.timestamps
    end
  end
end
