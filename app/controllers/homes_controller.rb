class HomesController < ApplicationController
  before_action :authenticate_user!

  def show
    @companion = current_user.companion
    @monologue = @companion&.personality_type&.random_monologue

    if current_user.nickname.present?
      @display_name = "#{current_user.nickname}#{current_user.honorific}"
    end
  end
end
