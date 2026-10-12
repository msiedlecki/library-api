class Loan < ApplicationRecord
  LOAN_PERIOD_DAYS = 30

  belongs_to :book
  belongs_to :reader

  scope :active, -> { where(returned_at: nil) }
  scope :due_soon, ->(date = Date.current) { active.where(reminder_3d_sent_at: nil, due_on: date + 3.days) }
  scope :due_today, ->(date = Date.current) { active.where(reminder_due_sent_at: nil, due_on: date) }

  def days_left
    (due_on - Date.current).to_i
  end
end
