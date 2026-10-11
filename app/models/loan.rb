class Loan < ApplicationRecord
  LOAN_PERIOD_DAYS = 30

  belongs_to :book
  belongs_to :reader
end
