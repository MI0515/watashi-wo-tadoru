class ReflectionMessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_to_pending_onboarding
  before_action :load_reflection

  def create
    ReflectionReply.new(reflection: @reflection).call(
      content: message_params[:content]
    )

    redirect_to reflection_path(@reflection), status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    @reply = error.record
    @companion = @reflection.companion
    @messages = @reflection.reflection_messages.order(:position)

    render "reflections/show", status: :unprocessable_content
  rescue ReflectionReply::NotReadyError
    redirect_to reflection_path(@reflection),
                alert: "今は返答を送信できません。",
                status: :see_other
  end

  private

  def redirect_to_pending_onboarding
    next_path = pending_onboarding_path_for(current_user)
    redirect_to next_path if next_path
  end

  def load_reflection
    # URLのIDだけでなく、ログイン中の本人の振り返りに限定する
    @reflection = current_user.reflections.find(params[:reflection_id])
  end

  def message_params
    params.require(:reflection_message).permit(:content)
  end
end
