class ReflectionsController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_to_pending_onboarding
  before_action :load_form_data, only: [ :new, :create ]

  def new
    @reflection = current_user.reflections.build(companion: @companion)
  end

  def create
    attributes = reflection_params

    # 本人と開始時のミツメイトは、送信されたIDではなくログイン情報から決める
    @reflection = current_user.reflections.build(
      initial_text: attributes[:initial_text],
      companion: @companion
    )

    selected_ids = Array(attributes[:emotion_ids]).reject(&:blank?)
    @reflection.emotions = Emotion.find(selected_ids).uniq

    if @reflection.save
      redirect_to reflection_path(@reflection), status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    @reflection = current_user.reflections.find(params[:id])
    @companion = @reflection.companion
    @messages = @reflection.reflection_messages.order(:position)
  end

  private

  def redirect_to_pending_onboarding
    next_path = pending_onboarding_path_for(current_user)
    redirect_to next_path if next_path
  end

  def load_form_data
    @companion = current_user.companion
    @emotions = Emotion.order(:display_order, :id)
  end

  def reflection_params
    params.require(:reflection).permit(:initial_text, emotion_ids: [])
  end
end
