class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # 新しいWeb機能に対応したブラウザーだけを許可する
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  # JavaScriptの読み込み設定が変わったら、HTMLのキャッシュ判定も更新する
  stale_when_importmap_changes

  # Deviseの処理時に、追加の入力項目を許可する
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def after_sign_in_path_for(resource)
    pending_onboarding_path_for(resource) || home_path
  end

  def pending_onboarding_path_for(user)
    return edit_onboarding_nickname_path if user.nickname.blank?
    return edit_onboarding_personality_type_path if user.personality_type_id.nil?
    return edit_onboarding_companion_path if user.companion_id.nil?

    nil
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :terms_accepted ])
  end
end
