class RecordsController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_to_pending_onboarding

  def index
    @companion = current_user.companion
    @records = current_user.reflections.completed
                           .includes(companion: :personality_type)
                           .order(completed_at: :desc, id: :desc)
  end

  def show
    # 本人の保存済み記録に限定し、他人の記録や対話中の振り返りは表示しない
    @record = current_user.reflections.completed
                          .includes(:emotions, companion: :personality_type)
                          .find(params[:id])
    @companion = @record.companion
  end

  private

  def redirect_to_pending_onboarding
    next_path = pending_onboarding_path_for(current_user)
    redirect_to next_path if next_path
  end
end
