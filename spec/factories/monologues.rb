FactoryBot.define do
  factory :monologue do
    association :personality_type
    content { "一人で黙々と考える時間も、けっこう楽しいよね。" }
  end
end
