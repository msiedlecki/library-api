class SendLoanRemindersJob < ApplicationJob
  queue_as :default

  def perform(today = Date.current)
    Loan.due_soon(today).find_each do |loan|
      LoanReminderMailer.with(loan: loan).due_soon.deliver_later
      loan.update!(reminder_3d_sent_at: Time.current)
    end

    Loan.due_today(today).find_each do |loan|
      LoanReminderMailer.with(loan: loan).due_today.deliver_later
      loan.update!(reminder_due_sent_at: Time.current)
    end
  end
end
