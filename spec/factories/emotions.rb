FactoryBot.define do
  factory :emotion do
    sequence(:name) { |n| "テスト感情#{n}" }
    display_order { 1 }
  end
end
