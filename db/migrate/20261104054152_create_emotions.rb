class CreateEmotions < ActiveRecord::Migration[8.1]
  def change
    create_table :emotions do |t|
      t.string :name, null: false
      t.integer :display_order, null: false

      t.timestamps
    end

    add_index :emotions, :name, unique: true
  end
end
