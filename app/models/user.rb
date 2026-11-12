class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # 初期設定前は、タイプを選んでいなくても登録できる
  belongs_to :personality_type, optional: true

  # 初期設定前は、ミツメイトを選んでいなくても登録できる
  belongs_to :companion, optional: true
  has_many :reflections, dependent: :destroy

  # 同意チェックの値を一時的に保持する。DBには保存しない
  attr_accessor :terms_accepted

  # 新規登録時は、チェック済みの値「1」を必須にする
  validates :terms_accepted,
            acceptance: { accept: "1" },
            allow_nil: false,
            on: :create

  # 呼ばれ方の初期設定を保存するときだけ検証する
  validates :nickname,
            presence: true,
            length: { maximum: 20 },
            on: :nickname_setup

  validates :honorific,
            length: { maximum: 10 },
            allow_blank: true,
            on: :nickname_setup

  # 自分の16タイプを設定するときだけ、存在するタイプを必須にする
  validates :personality_type,
            presence: true,
            on: :personality_type_setup

  # ミツメイトを設定するときだけ、存在するミツメイトを必須にする
  validates :companion,
            presence: true,
            on: :companion_setup
end
