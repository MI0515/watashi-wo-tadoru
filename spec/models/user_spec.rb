require "rails_helper"

RSpec.describe User, type: :model do
  it "正しい値なら登録できる" do
    user = build(:user)

    expect(user.save).to be true
    expect(user).to be_persisted
  end

  it "メールアドレスが空なら無効になる" do
    user = build(:user, email: "")

    expect(user).to be_invalid
    expect(user.errors.of_kind?(:email, :blank)).to be true
  end

  it "メールアドレスの形式が不正なら無効になる" do
    user = build(:user, email: "invalid-email")

    expect(user).to be_invalid
    expect(user.errors.of_kind?(:email, :invalid)).to be true
  end

  it "登録済みのメールアドレスと重複すると無効になる" do
    existing_user = create(:user)
    user = build(:user, email: existing_user.email)

    expect(user).to be_invalid
    expect(user.errors.of_kind?(:email, :taken)).to be true
  end

  it "パスワードが空なら無効になる" do
    user = build(:user, password: "", password_confirmation: "")

    expect(user).to be_invalid
    expect(user.errors.of_kind?(:password, :blank)).to be true
  end

  it "パスワードが5文字なら無効になる" do
    user = build(:user, password: "abc12", password_confirmation: "abc12")

    expect(user).to be_invalid
    expect(user.errors.of_kind?(:password, :too_short)).to be true
  end
end
