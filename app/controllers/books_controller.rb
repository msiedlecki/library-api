class BooksController < ApplicationController
  STATUSES = %w[ available borrowed ].freeze
  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100
  READER_FIELDS = %i[ card_number full_name email ].freeze

  def index
    status, page, per_page = list_params

    scope = Book.active
    scope = scope.public_send(status) if status   # status przeszedł whitelistę
    total = scope.count
    books = scope.includes(active_loan: :reader)
                 .order(:serial_number, :id)
                 .limit(per_page).offset((page - 1) * per_page)

    render json: {
      data: books.map { |book| BookSerializer.new(book).as_json },
      meta: { page: page, per_page: per_page, total: total }
    }
  end

  def show
    book = Book.includes(loans: :reader).find_active!(params[:serial_number])
    render json: BookSerializer.new(book, with_loans: true)
  end

  def create
    book = Book.register!(book_params)
    render json: BookSerializer.new(book), status: :created
  end

  def destroy
    Book.find_active!(params[:serial_number]).discard!
    head :no_content
  end

  def borrow
    book = Book.find_active!(params[:serial_number])
    loan = book.borrow_for!(**reader_params)
    render json: LoanSerializer.new(loan), status: :created
  end

  def return
    book = Book.find_active!(params[:serial_number])
    render json: LoanSerializer.new(book.return!)
  end

  private

  def book_params
    params.permit(:serial_number, :title, :author)
  end

  def reader_params
    given = params.expect(reader: READER_FIELDS).to_h.symbolize_keys
    READER_FIELDS.index_with(nil).merge(given)
  end

  def list_params
    errors = {}

    status = params[:status]
    if !status.nil? && !STATUSES.include?(status)
      errors[:status] = [ "must be one of: #{STATUSES.join(', ')}" ]
    end

    page = positive_int_param(:page, 1, errors)
    per_page = positive_int_param(:per_page, DEFAULT_PER_PAGE, errors)

    raise ErrorHandling::InvalidParams.new(errors) if errors.any?

    [ status, page, [ per_page, MAX_PER_PAGE ].min ]
  end

  def positive_int_param(key, default, errors)
    value = params[key]
    return default if value.nil?

    if value.is_a?(String) && value.match?(/\A\d{1,9}\z/) && value.to_i >= 1
      value.to_i
    else
      errors[key] = [ "must be a positive integer" ]
      default
    end
  end
end
