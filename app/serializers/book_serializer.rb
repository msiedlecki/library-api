class BookSerializer
  def initialize(book, with_loans: false)
    @book = book
    @with_loans = with_loans
  end

  def as_json(*)
    current = current_loan
    json = {
      serial_number: @book.serial_number,
      title: @book.title,
      author: @book.author,
      status: current ? "borrowed" : "available",
      current_loan: current && LoanSerializer.new(current, returned: false).as_json
    }
    json[:loans] = history if @with_loans
    json
  end

  private

  def current_loan
    @with_loans ? @book.loans.to_a.find { |loan| loan.returned_at.nil? } : @book.active_loan
  end

  def history
    @book.loans.to_a
      .sort_by { |loan| [ loan.borrowed_at, loan.id ] }
      .reverse
      .map { |loan| LoanSerializer.new(loan).as_json }
  end
end
