module Settings
  class EmailsController < ApplicationController
    before_action :authenticate_user!
    before_action :redirect_to_pending_onboarding
    before_action :load_user

    def edit
    end

    def update
      if @user.update_with_password(email_params)
        redirect_to settings_path,
                    notice: "メールアドレスを変更しました。",
                    status: :see_other
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def redirect_to_pending_onboarding
      next_path = pending_onboarding_path_for(current_user)
      redirect_to next_path if next_path
    end

    def load_user
      @user = current_user
      @companion = @user.companion
    end

    def email_params
      params.require(:user).permit(:email, :current_password)
    end
  end
end
