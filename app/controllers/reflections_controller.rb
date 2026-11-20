class ReflectionsController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_to_pending_onboarding
  before_action :load_form_data, only: [ :new, :create ]

  def new
    @reflection = current_user.reflections.build(companion: @companion)
  end

  def create
    attributes = reflection_params
    created = false

    # 同じ利用者からの同時送信で、確認と作成がすれ違わないようにする
    current_user.with_lock do
      @reflection = current_user.reflections.find_by(
        submission_token: attributes[:submission_token]
      )

      unless @reflection
        # 本人とミツメイトは、送信されたIDではなくログイン情報から決める
        @reflection = current_user.reflections.build(
          initial_text: attributes[:initial_text],
          submission_token: attributes[:submission_token],
          companion: @companion
        )

        selected_ids = Array(attributes[:emotion_ids]).reject(&:blank?)
        @reflection.emotions = Emotion.find(selected_ids).uniq
        created = @reflection.save
      end
    end

    if @reflection.persisted?
      # 再送時は既存の会話へ戻し、自動でAIを再呼び出ししない
      ReflectionInitialReply.new(reflection: @reflection).call if created

      redirect_to reflection_path(@reflection), status: :see_other
    else
      render :new, status: :unprocessable_content
    end

  rescue AiUsagePolicy::StoppedError, AiUsagePolicy::LimitError => error
    redirect_to reflection_path(@reflection),
                alert: error.message,
                status: :see_other
  rescue OpenAI::Errors::APITimeoutError
    redirect_to reflection_path(@reflection),
                alert: "返答の生成に時間がかかり、完了できませんでした。入力内容は保存されています。",
                status: :see_other
  rescue OpenAI::Errors::APIError, OpenaiClient::ResponseError
    redirect_to reflection_path(@reflection),
                alert: "返答を取得できませんでした。入力内容は保存されています。少し待ってから再試行してください。",
                status: :see_other
  end

  def show
    @reflection = current_user.reflections.find(params[:id])
    @companion = @reflection.companion
    @messages = @reflection.reflection_messages.order(:position)
    @reply = @reflection.reflection_messages.build(role: :user)
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
    params.require(:reflection).permit(
      :initial_text,
      :submission_token,
      emotion_ids: []
    )
  end
end
