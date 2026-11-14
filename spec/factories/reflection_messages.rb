FactoryBot.define do
  factory :reflection_message do
    association :reflection
    role { :assistant }
    content { "そのとき、どんなところが気になった？" }
    position { 1 }
  end
end
