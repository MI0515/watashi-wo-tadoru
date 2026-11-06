module Onboarding
  class CompanionsController < ApplicationController
    before_action :authenticate_user!

    def edit
      load_setup_data
    end

    def update
      load_setup_data
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

    def load_setup_data
      @user = current_user

      @personality_type_groups =
        PersonalityType.order(:id).group_by(&:group_code)

      @companions_by_type =
        Companion.includes(personality_type: :monologues)
                 .order(:id)
                 .group_by(&:personality_type_id)

      @selected_type_id =
        @user.companion&.personality_type_id || @user.personality_type_id

      load_preview_lines
    end

    def load_preview_lines
      @preview_lines = {}

      @companions_by_type.each_value do |companions|
        monologues = companions.first.personality_type.monologues
                               .to_a.sample(companions.length)

        companions.each_with_index do |companion, index|
          @preview_lines[companion.id] = monologues[index]&.content
        end
      end
    end

    def companion_params
      params.require(:user).permit(:companion_id)
    end
  end
end
