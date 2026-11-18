class CreateApiUsageLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :api_usage_logs do |t|
      t.references :user,
                   null: false,
                   foreign_key: { on_delete: :cascade }

      # 振り返りを削除しても、利用回数と使用量の記録は残す
      t.references :reflection,
                   null: true,
                   foreign_key: { on_delete: :nullify }

      t.integer :request_kind, null: false
      t.integer :status, null: false, default: 0
      t.boolean :initial_reply, null: false, default: false
      t.boolean :retry, null: false, default: false
      t.string :response_id

      # 使用量を取得できなかった場合と、実際に0だった場合を区別する
      t.integer :input_tokens
      t.integer :output_tokens

      t.timestamps
    end

    add_index :api_usage_logs, [ :user_id, :created_at ]
    add_index :api_usage_logs, :response_id, unique: true
  end
end
