class Reader < ApplicationRecord
  class DataMismatch < StandardError
    def initialize(message = "Reader data does not match the existing library card")
      super
    end
  end

  has_many :loans

  normalizes :email, with: ->(value) { value.strip.downcase }
  normalizes :full_name, with: ->(value) { value.strip }

  validates :card_number, format: { with: /\A\d{6}\z/ }, uniqueness: true
  validates :full_name, presence: true, length: { maximum: 255 }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true

  def self.resolve!(card_number:, full_name:, email:)
    candidate = new(card_number:, full_name:, email:)
    existing  = find_by(card_number: candidate.card_number)
    return same_person!(existing, candidate) if existing

    transaction(requires_new: true) { candidate.save! }
    candidate
  rescue ActiveRecord::RecordNotUnique
    existing = find_by(card_number: candidate.card_number)
    return same_person!(existing, candidate) if existing

    candidate.errors.add(:email, :taken)
    raise ActiveRecord::RecordInvalid, candidate
  end

  def self.same_person!(existing, candidate)
    return existing if existing.full_name == candidate.full_name && existing.email == candidate.email
    raise DataMismatch
  end

  private_class_method :same_person!
end
