require "rails_helper"

RSpec.describe LoanReminderMailer, type: :mailer do
  describe "#due_soon" do
    it "renders the reminder body with the days left and due date" do
      loan = create(:loan, due_on: Date.current + 3.days)

      mail = described_class.with(loan: loan).due_soon

      expect(mail.to).to eq([ loan.reader.email ])
      expect(mail.subject).to eq("Return reminder: #{loan.book.title}")
      expect(mail.body.encoded).to include("Hello #{loan.reader.full_name}")
      expect(mail.body.encoded).to include("the book below is due in 3 days")
      expect(mail.body.encoded).to include(loan.book.title)
      expect(mail.body.encoded).to include(loan.due_on.to_s)
    end
  end

  describe "#due_today" do
    it "renders the due-today message" do
      loan = create(:loan, due_on: Date.current)

      mail = described_class.with(loan: loan).due_today

      expect(mail.to).to eq([ loan.reader.email ])
      expect(mail.subject).to eq("Due today: #{loan.book.title}")
      expect(mail.body.encoded).to include("the book below is due today")
      expect(mail.body.encoded).to include("Please return it today.")
    end
  end
end
