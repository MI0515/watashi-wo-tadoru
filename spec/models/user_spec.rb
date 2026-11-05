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

  describe "呼ばれ方の初期設定" do
    let(:user) { create(:user) }

    it "ニックネームと敬称を保存できる" do
      user.assign_attributes(nickname: "七海", honorific: "さん")

      expect(user.save(context: :nickname_setup)).to be true
      expect(user.reload.attributes.slice("nickname", "honorific")).to eq(
        "nickname" => "七海",
        "honorific" => "さん"
      )
    end

    it "敬称は未入力でも有効になる" do
      user.assign_attributes(nickname: "七海", honorific: nil)

      expect(user.valid?(:nickname_setup)).to be true
    end

    it "ニックネーム20文字・敬称10文字なら有効になる" do
      user.assign_attributes(nickname: "あ" * 20, honorific: "さ" * 10)

      expect(user.valid?(:nickname_setup)).to be true
    end

    it "ニックネームが空なら無効になる" do
      user.nickname = ""

      expect(user.valid?(:nickname_setup)).to be false
      expect(user.errors.of_kind?(:nickname, :blank)).to be true
    end

    it "ニックネームが空白だけなら無効になる" do
      user.nickname = "   "

      expect(user.valid?(:nickname_setup)).to be false
      expect(user.errors.of_kind?(:nickname, :blank)).to be true
    end

    it "ニックネームが21文字なら無効になる" do
      user.nickname = "あ" * 21

      expect(user.valid?(:nickname_setup)).to be false
      expect(user.errors.of_kind?(:nickname, :too_long)).to be true
    end

    it "敬称が11文字なら無効になる" do
      user.assign_attributes(nickname: "七海", honorific: "さ" * 11)

      expect(user.valid?(:nickname_setup)).to be false
      expect(user.errors.of_kind?(:honorific, :too_long)).to be true
    end

    it "通常の新規登録ではニックネーム未設定でも有効になる" do
      new_user = build(:user, nickname: nil, honorific: nil)

      expect(new_user).to be_valid
    end
  end
  describe "自分の16タイプの初期設定" do
    let(:user) { create(:user) }

    it "登録済みのタイプを保存できる" do
      personality_type = create(:personality_type)
      user.personality_type = personality_type

      expect(user.save(context: :personality_type_setup)).to be true
      expect(user.reload.personality_type).to eq(personality_type)
    end

    it "未選択なら無効になる" do
      user.personality_type = nil

      expect(user.valid?(:personality_type_setup)).to be false
      expect(user.errors.of_kind?(:personality_type, :blank)).to be true
      expect(user.errors.full_messages).to include(
        "16タイプを選択してください"
      )
    end

    it "存在しないタイプのIDなら無効になる" do
      user.personality_type_id = PersonalityType.maximum(:id).to_i + 1

      expect(user.valid?(:personality_type_setup)).to be false
      expect(user.errors.of_kind?(:personality_type, :blank)).to be true
    end

    it "通常の新規登録ではタイプ未設定でも有効になる" do
      new_user = build(:user, personality_type: nil)

      expect(new_user).to be_valid
    end
  end
end
