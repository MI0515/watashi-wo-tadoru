module Onboarding
  class PersonalityTypesController < ApplicationController
    before_action :authenticate_user!
    before_action :load_setup_data

    def edit
    end

    def update
      @user.assign_attributes(personality_type_params)

      if @user.save(context: :personality_type_setup)
        redirect_to edit_onboarding_companion_path,
                    status: :see_other
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def load_setup_data
      @user = current_user
      @personality_type_groups =
        PersonalityType.order(:id).group_by(&:group_code)
    end

    def personality_type_params
      params.require(:user).permit(:personality_type_id)
    end
  end
end
