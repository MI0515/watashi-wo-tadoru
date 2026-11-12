FactoryBot.define do
  factory :reflection do
    association :user
    association :companion
    initial_text { "友達と話したあと、少しモヤモヤした。" }
  end
end
