class LoanSerializer
  def initialize(loan, returned: true)
    @loan = loan
    @returned = returned
  end

  def as_json(*)
    json = {
      borrowed_at: @loan.borrowed_at.iso8601,
      due_on: @loan.due_on.iso8601
    }
    json[:returned_at] = @loan.returned_at&.iso8601 if @returned
    json[:reader] = ReaderSerializer.new(@loan.reader).as_json
    json
  end
end
