FactoryBot.define do
  factory :loan do
    association :book
    association :reader
    borrowed_at { Time.current }
    due_on { borrowed_at.to_date + Loan::LOAN_PERIOD_DAYS }
  end
end
