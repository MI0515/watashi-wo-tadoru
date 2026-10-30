class Companion < ApplicationRecord
  belongs_to :personality_type
  has_many :users

  # 見た目は3種類。同じタイプ内での重複を防ぐ
  validates :appearance_type,
            presence: true,
            inclusion: { in: %w[male female animal] },
            uniqueness: { scope: :personality_type_id }

  # 画像の参照先と話し方は必須
  validates :sd_image_path, :full_image_path, :speaking_style,
            presence: true

  # 話し方はタメ口・敬語の2種類
  validates :speaking_style,
            inclusion: { in: %w[casual polite] }

  # SD画像と同じキャラクターの顔アイコンを参照する
  def icon_image_path
    sd_image_path.sub("-sd.png", "-icon.png")
  end
end
