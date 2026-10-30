# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# 4グループごとに、16タイプの初期データを用意する
# %w[...]は、文字列の配列を短く書くRubyの記法
personality_type_groups = {
  "NT" => %w[INTJ INTP ENTJ ENTP],
  "NF" => %w[INFJ INFP ENFJ ENFP],
  "SP" => %w[ISTP ISFP ESTP ESFP],
  "SJ" => %w[ISTJ ISFJ ESTJ ESFJ]
}

personality_type_groups.each do |group_code, codes|
  codes.each do |code|
    # 同じコードがあれば再利用し、なければ新しく作る
    personality_type = PersonalityType.find_or_initialize_by(code: code)

    # 既存データも、定義したグループにそろえる
    personality_type.update!(group_code: group_code)
  end
end

# 敬語で話すミツメイトのタイプ
polite_type_codes = %w[ISTJ ISFJ INFJ INTJ]

# 各タイプに動物のミツメイトを1件ずつ登録する
personality_type_groups.each do |group_code, codes|
  codes.each do |code|
    personality_type = PersonalityType.find_by!(code: code)

    # 動物画像はグループ単位で共有する
    image_prefix = group_code.downcase

    speaking_style = polite_type_codes.include?(code) ? "polite" : "casual"

    companion = Companion.find_or_initialize_by(
      personality_type: personality_type,
      appearance_type: "animal"
    )

    companion.update!(
      sd_image_path: "companions/#{image_prefix}-animal-sd.png",
      full_image_path: "companions/#{image_prefix}-animal-full.png",
      speaking_style: speaking_style
    )
  end
end

# INTPには男の子・女の子も追加する
intp = PersonalityType.find_by!(code: "INTP")

%w[male female].each do |appearance_type|
  companion = Companion.find_or_initialize_by(
    personality_type: intp,
    appearance_type: appearance_type
  )

  companion.update!(
    sd_image_path: "companions/intp-#{appearance_type}-sd.png",
    full_image_path: "companions/intp-#{appearance_type}-full.png",
    speaking_style: "casual"
  )
end
