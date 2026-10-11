class ReaderSerializer
  def initialize(reader)
    @reader = reader
  end

  def as_json(*)
    {
      card_number: @reader.card_number,
      full_name: @reader.full_name,
      email: @reader.email
    }
  end
end
