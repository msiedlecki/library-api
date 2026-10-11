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

  def discard!
    with_lock do
      raise CurrentlyBorrowed if loans.active.exists?
      update!(discarded_at: Time.current)
    end
  end
end
