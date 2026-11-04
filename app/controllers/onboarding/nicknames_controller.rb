module Onboarding
  class NicknamesController < ApplicationController
    before_action :authenticate_user!

    def edit
      @user = current_user
    end

    def update
      @user = current_user
      @user.assign_attributes(nickname_params)

      if @user.save(context: :nickname_setup)
        redirect_to edit_onboarding_personality_type_path,
                    status: :see_other
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def nickname_params
      params.require(:user).permit(:nickname, :honorific)
    end
  end
end
