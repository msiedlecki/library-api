class LoanReminderMailer < ApplicationMailer
  before_action :set_loan

  def due_soon
    @days_left = @loan.days_left
    mail to: @reader.email, subject: "Return reminder: #{@book.title}"
  end

  def due_today
    mail to: @reader.email, subject: "Due today: #{@book.title}"
  end

  private

  def set_loan
    @loan = params.fetch(:loan)
    @book = @loan.book
    @reader = @loan.reader
  end
end
