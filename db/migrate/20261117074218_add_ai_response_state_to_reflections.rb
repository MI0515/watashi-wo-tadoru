class AddAiResponseStateToReflections < ActiveRecord::Migration[8.1]
  def change
    add_column :reflections, :ai_response_status, :integer, default: 0, null: false
    add_column :reflections, :ai_response_started_at, :datetime
  end
end
