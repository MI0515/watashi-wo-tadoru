FactoryBot.define do
  factory :reflection_emotion do
    association :reflection
    association :emotion
  end
end
