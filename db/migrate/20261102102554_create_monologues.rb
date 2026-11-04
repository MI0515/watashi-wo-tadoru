class CreateMonologues < ActiveRecord::Migration[8.1]
  def change
    create_table :monologues do |t|
      t.references :personality_type, null: false, foreign_key: true
      t.text :content, null: false

      t.timestamps
    end
  end
end
