class ReflectionCompletion
  class NotReadyError < StandardError
  end

  def initialize(reflection:)
    @reflection = reflection
  end

  def call(personal_note:)
    @reflection.with_lock do
      return @reflection if @reflection.completed?

      unless @reflection.in_progress? && @reflection.summary_available? &&
             !@reflection.ai_response_processing?
        raise NotReadyError, "まとめを確認してから保存してください。"
      end

      # 入力エラー時に対話中の状態と入力内容を保つため、完了へ変更する前に検証する
      @reflection.personal_note = personal_note.presence
      raise ActiveRecord::RecordInvalid.new(@reflection) unless @reflection.valid?

      @reflection.update!(
        status: :completed,
        completed_at: Time.current
      )
    end

    @reflection
  end
end
