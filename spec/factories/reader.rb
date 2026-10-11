FactoryBot.define do
  factory :reader do
    card_number { Faker::Number.number(digits: 6) }
    email { Faker::Internet.email }
    full_name { Faker::Name.name }
  end
end
