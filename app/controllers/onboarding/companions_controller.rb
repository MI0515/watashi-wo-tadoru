module Onboarding
  class CompanionsController < ApplicationController
    include CompanionSelectionData

    before_action :authenticate_user!

    def edit
      load_companion_selection_data
    end

    def update
      load_companion_selection_data
      @user.assign_attributes(companion_params)

      if @user.save(context: :companion_setup)
        redirect_to home_path, status: :see_other
      else
        selected_type = PersonalityType.find_by(
          id: params[:companion_type_id]
        )
        @selected_type_id = selected_type.id if selected_type

        render :edit, status: :unprocessable_content
      end
    end

    private

    def companion_params
      params.require(:user).permit(:companion_id)
    end
  end
end
