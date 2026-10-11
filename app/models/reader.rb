class Reader < ApplicationRecord
  has_many :loans

  normalizes :email, with: ->(value) { value.strip.downcase }
  normalizes :full_name, with: ->(value) { value.strip }

  validates :card_number, format: { with: /\A\d{6}\z/ }, uniqueness: true
  validates :full_name, presence: true, length: { maximum: 255 }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
end
