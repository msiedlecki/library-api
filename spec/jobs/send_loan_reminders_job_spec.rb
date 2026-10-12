require "rails_helper"

RSpec.describe SendLoanRemindersJob, type: :job do
  include ActiveJob::TestHelper

  before do
    ActionMailer::Base.deliveries.clear
  end

  it "sends due-soon and due-today reminders only for eligible active loans" do
    soon_loan = create(:loan, due_on: Date.current + 3.days)
    today_loan = create(:loan, due_on: Date.current)
    already_notified_soon = create(:loan, due_on: Date.current + 3.days, reminder_3d_sent_at: Time.current)
    already_notified_today = create(:loan, due_on: Date.current, reminder_due_sent_at: Time.current)

    perform_enqueued_jobs do
      described_class.perform_now(Date.current)
    end

    expect(soon_loan.reload.reminder_3d_sent_at).to be_present
    expect(today_loan.reload.reminder_due_sent_at).to be_present
    expect(already_notified_soon.reload.reminder_3d_sent_at).to be_present
    expect(already_notified_today.reload.reminder_due_sent_at).to be_present

    expect(ActionMailer::Base.deliveries.map(&:subject)).to contain_exactly(
      "Return reminder: #{soon_loan.book.title}",
      "Due today: #{today_loan.book.title}"
    )
  end
end
