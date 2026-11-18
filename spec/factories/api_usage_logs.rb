FactoryBot.define do
  factory :api_usage_log do
    association :reflection
    user { reflection&.user || association(:user) }
    request_kind { :dialogue }
    status { :succeeded }
    initial_reply { true }

    # retryはRubyの予約語なので、属性名を明示して設定する
    add_attribute(:retry) { false }

    sequence(:response_id) { |n| "response-test-#{n}" }
    input_tokens { 100 }
    output_tokens { 30 }
  end
end
