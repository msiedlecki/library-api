class Book < ApplicationRecord
  class CurrentlyBorrowed < StandardError; end

  SERIAL_FORMAT = /\A\d{6}\z/

  has_many :loans, dependent: :restrict_with_exception
  has_one  :active_loan, -> { where(returned_at: nil) }, class_name: "Loan"

  normalizes :title, :author, with: ->(value) { value.strip }

  validates :serial_number, format: { with: SERIAL_FORMAT }, uniqueness: { message: "is already taken or reserved" }
  validates :title, :author, presence: true, length: { maximum: 255 }

  scope :active, -> { where(discarded_at: nil) }
  scope :borrowed, -> { active.where(id: Loan.active.select(:book_id)) }
  scope :available, -> { active.where.not(id: Loan.active.select(:book_id)) }

  def self.register!(attributes)
    create!(attributes)
  rescue ActiveRecord::RecordNotUnique
    new(attributes).validate!
    raise
  end

  def self.find_active!(serial_number)
    raise ActiveRecord::RecordNotFound, "Book not found" unless serial_number.to_s.match?(SERIAL_FORMAT)

    active.find_by!(serial_number: serial_number)
  end

  def borrow_for!(card_number:, full_name:, email:)
    with_lock do
      raise ActiveRecord::RecordNotFound if discarded_at
      raise CurrentlyBorrowed, "Book is already borrowed" if active_loan.present?

      reader = Reader.resolve!(card_number: card_number, full_name: full_name, email: email)
      Loan.create!(book: self, reader: reader, borrowed_at: Time.current, due_on: Time.current.to_date + Loan::LOAN_PERIOD_DAYS)
    end
  end

  def return!
    with_lock do
      loan = active_loan
      raise ActiveRecord::RecordNotFound, "Loan not found" unless loan

      loan.update!(returned_at: Time.current)
      loan
    end
  end

  def discard!
    with_lock do
      raise CurrentlyBorrowed if loans.active.exists?
      update!(discarded_at: Time.current)
    end
  end
end
