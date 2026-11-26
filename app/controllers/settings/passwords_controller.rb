module Settings
  class PasswordsController < ApplicationController
    before_action :authenticate_user!
    before_action :redirect_to_pending_onboarding
    before_action :load_user

    def edit
    end

    def update
      attributes = password_params

      # Deviseは空の新しいパスワードを更新対象から外すため、この画面では明示的に拒否する
      @user.errors.add(:password, :blank) if attributes[:password].blank?
      if attributes[:password_confirmation].blank?
        @user.errors.add(:password_confirmation, :blank)
      end

      if @user.errors.any?
        render :edit, status: :unprocessable_content
        return
      end

      if @user.update_with_password(attributes)
        # パスワード変更後の認証情報でセッションを更新し、ログイン状態を維持する
        bypass_sign_in(@user)

        redirect_to settings_path,
                    notice: "パスワードを変更しました。",
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

    def password_params
      params.require(:user).permit(
        :current_password,
        :password,
        :password_confirmation
      )
    end
  end
end
