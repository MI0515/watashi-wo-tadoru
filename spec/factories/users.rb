FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "test123" }
    password_confirmation { "test123" }
    terms_accepted { "1" }
  end
end
