FactoryBot.define do
  factory :book do
    serial_number { Faker::Number.number(digits: 6) }
    title { Faker::Book.title }
    author { Faker::Book.author }
  end
end
