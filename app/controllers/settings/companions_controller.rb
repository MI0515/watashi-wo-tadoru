module Settings
  class CompanionsController < ApplicationController
    include CompanionSelectionData

    before_action :authenticate_user!
    before_action :redirect_to_pending_onboarding

    def edit
      load_companion_selection_data
    end

    def update
      load_companion_selection_data
      @user.assign_attributes(companion_params)

      if @user.save(context: :companion_setup)
        redirect_to home_path,
                    notice: "ミツメイトを変更しました。",
                    status: :see_other
      else
        selected_type = PersonalityType.find_by(
          id: params[:companion_type_id]
        )
        @selected_type_id = selected_type.id if selected_type

        render :edit, status: :unprocessable_content
      end
    end

    private

    def redirect_to_pending_onboarding
      next_path = pending_onboarding_path_for(current_user)
      redirect_to next_path if next_path
    end

    def companion_params
      params.require(:user).permit(:companion_id)
    end
  end
end
