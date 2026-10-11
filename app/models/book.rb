class Book < ApplicationRecord
  SERIAL_FORMAT = /\A\d{6}\z/

  has_many :loans, dependent: :restrict_with_exception

  normalizes :title, :author, with: ->(value) { value.strip }

  validates :serial_number, format: { with: SERIAL_FORMAT }, uniqueness: { message: "is already taken or reserved" }
  validates :title, :author, presence: true, length: { maximum: 255 }
end
