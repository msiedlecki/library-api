require "rails_helper"

RSpec.describe Loan, type: :model do
  describe "validations" do
    it "is valid with a book and a reader" do
      expect(build(:loan)).to be_valid
    end

    it "requires a book and a reader" do
      loan = build(:loan, book: nil, reader: nil)

      expect(loan).not_to be_valid
      expect(loan.errors).to include(:book, :reader)
    end
  end

  describe "active loan constraint" do
    it "allows only one active loan per book" do
      loan = create(:loan)

      expect { create(:loan, book: loan.book) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows a new loan after the previous loan is returned" do
      previous_loan = create(:loan, borrowed_at: 1.hour.ago, returned_at: Time.current)

      expect(create(:loan, book: previous_loan.book)).to be_persisted
    end
  end
end
