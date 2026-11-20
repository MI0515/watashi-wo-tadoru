class ReflectionSummariesController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_to_pending_onboarding
  before_action :load_reflection

  def show
    return if @reflection.summary_available?

    last_message = @reflection.reflection_messages.order(:position).last
    unless @reflection.in_progress? &&
           @reflection.additional_reply_limit_reached? &&
           last_message&.assistant?
      redirect_to reflection_path(@reflection),
                  alert: "対話の続きを確認してください。",
                  status: :see_other
    end
  end

  def create
    ReflectionSummary.new(reflection: @reflection).call

    redirect_to reflection_summary_path(@reflection), status: :see_other
  rescue ReflectionSummary::InProgressError
    redirect_to reflection_summary_path(@reflection),
                notice: "まとめを作っています。",
                status: :see_other
  rescue ReflectionSummary::NotReadyError
    redirect_to reflection_path(@reflection),
                alert: "今はまとめを作れません。対話の続きを確認してください。",
                status: :see_other
  rescue AiUsagePolicy::StoppedError => error
    redirect_to reflection_summary_path(@reflection),
                alert: error.message,
                status: :see_other
  rescue OpenAI::Errors::APITimeoutError
    redirect_to reflection_summary_path(@reflection),
                alert: "まとめの生成に時間がかかり、完了できませんでした。会話は保存されています。",
                status: :see_other
  rescue OpenAI::Errors::APIError, OpenaiClient::ResponseError
    redirect_to reflection_summary_path(@reflection),
                alert: "まとめを取得できませんでした。会話は保存されています。もう一度お試しください。",
                status: :see_other
  end

  def update
    ReflectionCompletion.new(reflection: @reflection).call(
      personal_note: completion_params[:personal_note]
    )

    redirect_to home_path,
                notice: "振り返りを保存しました。",
                status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    @reflection = error.record
    render :show, status: :unprocessable_content
  rescue ReflectionCompletion::NotReadyError => error
    redirect_to reflection_summary_path(@reflection),
                alert: error.message,
                status: :see_other
  end

  private

  def completion_params
    params.require(:reflection).permit(:personal_note)
  end

  def redirect_to_pending_onboarding
    next_path = pending_onboarding_path_for(current_user)
    redirect_to next_path if next_path
  end

  def load_reflection
    # 生成・表示ともに、ログイン中の本人の振り返りだけを扱う
    @reflection = current_user.reflections.find(params[:reflection_id])
    @companion = @reflection.companion
  end
end
