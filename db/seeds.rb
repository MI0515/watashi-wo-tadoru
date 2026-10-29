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
