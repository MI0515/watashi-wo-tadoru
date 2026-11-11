class HomesController < ApplicationController
  # 順番に意味がある：current_user を使うため、ログイン確認を先に実行する
  before_action :authenticate_user!
  before_action :redirect_to_pending_onboarding

  def show
    # 初期設定が済んでいることは before_action で保証済みなので、nil チェックはしない
    @companion = current_user.companion
    # 画面で独り言を切り替えるため、1件ではなく全件を渡す
    @monologues = @companion.personality_type.monologues.to_a
    @monologue = @monologues.sample

    if current_user.nickname.present?
      @display_name = "#{current_user.nickname}#{current_user.honorific}"
    end
  end

  private

  def redirect_to_pending_onboarding
    next_path = pending_onboarding_path_for(current_user)
    redirect_to next_path if next_path
  end
end
