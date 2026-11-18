class ApiUsageLog < ApplicationRecord
  belongs_to :user
  belongs_to :reflection, optional: true

  enum :request_kind,
       { dialogue: 0, summary: 1 },
       prefix: true,
       validate: true

  enum :status,
       { processing: 0, succeeded: 1, failed: 2, timed_out: 3 },
       prefix: true,
       validate: true

  validates :initial_reply, :retry, inclusion: { in: [ true, false ] }

  validates :input_tokens, :output_tokens,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true
end
