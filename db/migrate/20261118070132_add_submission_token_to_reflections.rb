class AddSubmissionTokenToReflections < ActiveRecord::Migration[8.1]
  def change
    # 既存の振り返りにも、それぞれ異なる送信IDを付ける
    add_column :reflections, :submission_token, :uuid,
               default: -> { "gen_random_uuid()" },
               null: false

    add_index :reflections, [ :user_id, :submission_token ], unique: true
  end
end
