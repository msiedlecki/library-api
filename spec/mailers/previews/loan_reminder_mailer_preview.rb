class LoanReminderMailerPreview < ActionMailer::Preview
  def due_soon
    loan = Loan.new(
      reader: Reader.new(full_name: "Jane Doe", email: "jane@example.com"),
      book: Book.new(title: "The Pragmatic Programmer", author: "Andrew Hunt", serial_number: "123456"),
      due_on: Date.current + 3.days
    )

    LoanReminderMailer.with(loan: loan).due_soon
  end

  def due_today
    loan = Loan.new(
      reader: Reader.new(full_name: "Jane Doe", email: "jane@example.com"),
      book: Book.new(title: "The Pragmatic Programmer", author: "Andrew Hunt", serial_number: "123456"),
      due_on: Date.current
    )

    LoanReminderMailer.with(loan: loan).due_today
  end
end
