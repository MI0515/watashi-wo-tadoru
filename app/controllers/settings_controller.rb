class SettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_to_pending_onboarding
  before_action :load_settings_data

  def show
  end

  def update
    @user.assign_attributes(settings_params)

    # 初期設定と同じ入力チェックを、呼ばれ方とタイプの両方に適用する
    if @user.save(context: [ :nickname_setup, :personality_type_setup ])
      redirect_to settings_path,
                  notice: "設定を変更しました。",
                  status: :see_other
    else
      render :show, status: :unprocessable_content
    end
  end

  private

  def redirect_to_pending_onboarding
    next_path = pending_onboarding_path_for(current_user)
    redirect_to next_path if next_path
  end

  def load_settings_data
    @user = current_user
    @companion = @user.companion
    @personality_types = PersonalityType.order(:id)
  end

  def settings_params
    params.require(:user).permit(:nickname, :honorific, :personality_type_id)
  end
end
