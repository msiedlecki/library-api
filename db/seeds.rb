books = [
  [ "000001", "A Wizard of Earthsea", "Ursula K. Le Guin" ],
  [ "000002", "Blade Runner", "Philip K. Dick" ],
  [ "000003", "Dune", "Frank Herbert" ],
  [ "000004", "Lord of the Rings", "J. R. R. Tolkien" ],
  [ "000005", "This Is How You Lose the Time War", "Amal El-Mohtar" ],
  [ "000006", "The Last Wish", "Andrzej Sapkowski" ],
  [ "000007", "Agla: Alef", "Radek Rak" ]
].each_with_object({}) do |(serial_number, title, author), records|
  records[serial_number] = Book.find_or_create_by!(serial_number:) do |book|
    book.title = title
    book.author = author
  end
end

readers = [
  [ "100001", "Sam Kerr", "sam.kerr@example.com" ],
  [ "100002", "Alessandro Del Piero", "alex.delpiero@example.com" ],
  [ "100003", "Gonzalo Higuain", "gonzalo.higuain@example.com" ],
  [ "100004", "Cole Palmer", "cole.palmer@example.com" ]
].each_with_object({}) do |(card_number, full_name, email), records|
  records[card_number] = Reader.find_or_create_by!(card_number:) do |reader|
    reader.full_name = full_name
    reader.email = email
  end
end

[
  { serial_number: "000006", card_number: "100001", days_until_due: 0 },
  { serial_number: "000007", card_number: "100002", days_until_due: 3 }
].each do |attributes|
  due_on = Date.current + attributes[:days_until_due].days
  borrowed_at = Time.current - (Loan::LOAN_PERIOD_DAYS - attributes[:days_until_due]).days
  loan = Loan.find_or_initialize_by(book: books.fetch(attributes[:serial_number]), returned_at: nil)
  loan.assign_attributes(
    reader: readers.fetch(attributes[:card_number]),
    borrowed_at:,
    due_on:
  )
  loan.save!
end

[
  {
    serial_number: "000005",
    card_number: "100003",
    borrowed_at: Time.zone.local(2025, 3, 1, 9),
    returned_at: Time.zone.local(2025, 3, 20, 10)
  },
  {
    serial_number: "000005",
    card_number: "100004",
    borrowed_at: Time.zone.local(2025, 4, 1, 9),
    returned_at: Time.zone.local(2025, 4, 20, 10)
  }
].each do |attributes|
  Loan.find_or_create_by!(
    book: books.fetch(attributes[:serial_number]),
    reader: readers.fetch(attributes[:card_number]),
    borrowed_at: attributes[:borrowed_at]
  ) do |loan|
    loan.due_on = attributes[:borrowed_at].to_date + Loan::LOAN_PERIOD_DAYS
    loan.returned_at = attributes[:returned_at]
  end
end
