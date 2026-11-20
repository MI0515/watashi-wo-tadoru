class ReflectionRetriesController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_to_pending_onboarding
  before_action :load_reflection

  def create
    ReflectionRetry.new(reflection: @reflection).call(
      last_message_id: params[:last_message_id]
    )

    redirect_to reflection_path(@reflection), status: :see_other
  rescue ReflectionRetry::InProgressError
    redirect_to reflection_path(@reflection),
                notice: "ミツメイトが返答を考えています。",
                status: :see_other
  rescue ReflectionRetry::NotReadyError
    redirect_to reflection_path(@reflection),
                alert: "今は再試行できません。現在の会話を確認してください。",
                status: :see_other
  rescue AiUsagePolicy::StoppedError, AiUsagePolicy::LimitError => error
    redirect_to reflection_path(@reflection),
                alert: error.message,
                status: :see_other
  rescue OpenAI::Errors::APITimeoutError
    redirect_to reflection_path(@reflection),
                alert: "返答の生成に時間がかかり、再試行を完了できませんでした。",
                status: :see_other
  rescue OpenAI::Errors::APIError, OpenaiClient::ResponseError
    redirect_to reflection_path(@reflection),
                alert: "返答を取得できませんでした。少し待ってから再試行してください。",
                status: :see_other
  end

  private

  def redirect_to_pending_onboarding
    next_path = pending_onboarding_path_for(current_user)
    redirect_to next_path if next_path
  end

  def load_reflection
    # 他の利用者の振り返りを再試行できないよう、本人の記録に限定する
    @reflection = current_user.reflections.find(params[:reflection_id])
  end
end
