class HomesController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_to_pending_onboarding

  def show
    @companion = current_user.companion
    @monologue = @companion&.personality_type&.random_monologue

    if current_user.nickname.present?
      @display_name = "#{current_user.nickname}#{current_user.honorific}"
    end
  end

  private

  def redirect_to_pending_onboarding
    next_path = pending_onboarding_path_for(current_user)
    redirect_to next_path if next_path
  end
end
