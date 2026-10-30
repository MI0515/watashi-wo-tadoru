class CreateCompanions < ActiveRecord::Migration[8.1]
  def change
    create_table :companions do |t|
      t.references :personality_type, null: false, foreign_key: true
      t.string :appearance_type, null: false
      t.string :sd_image_path, null: false
      t.string :full_image_path, null: false
      t.string :speaking_style, null: false

      t.timestamps
    end

    # 同じタイプ・同じ見た目の組み合わせは重複させない
    add_index :companions,
              [ :personality_type_id, :appearance_type ],
              unique: true
  end
end
