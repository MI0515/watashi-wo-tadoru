class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # 同意チェックの値を一時的に保持する。DBには保存しない
  attr_accessor :terms_accepted

  # 新規登録時は、チェック済みの値「1」を必須にする
  validates :terms_accepted,
            acceptance: { accept: "1" },
            allow_nil: false,
            on: :create
end
