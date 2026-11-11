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

  def complete_guide
    # 二重送信されても、最初の案内完了日時を保持する
    current_user.with_lock do
      if current_user.onboarding_completed_at.nil?
        current_user.update!(onboarding_completed_at: Time.current)
      end
    end

    redirect_to home_path, status: :see_other
  end

  private

  def redirect_to_pending_onboarding
    next_path = pending_onboarding_path_for(current_user)
    redirect_to next_path if next_path
  end
end
