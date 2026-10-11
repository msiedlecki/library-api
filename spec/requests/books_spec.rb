require "rails_helper"

RSpec.describe "Books API", type: :request do
  describe "GET /books" do
    it "lists active books in serial-number order with default pagination" do
      create(:book, serial_number: "000003", title: "Third")
      create(:book, serial_number: "000001", title: "First")
      create(:book, serial_number: "000002", title: "Discarded").update!(discarded_at: Time.current)

      get "/books"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "data" => [
          include("serial_number" => "000001", "title" => "First", "status" => "available", "current_loan" => nil),
          include("serial_number" => "000003", "title" => "Third", "status" => "available", "current_loan" => nil)
        ],
        "meta" => { "page" => 1, "per_page" => 25, "total" => 2 }
      )
    end

    describe "status filter" do
      let!(:available_book) { create(:book, serial_number: "000010") }
      let!(:returned_book) do
        create(:book, serial_number: "000011").tap do |book|
          create(:loan, book: book, borrowed_at: 10.days.ago, returned_at: 1.day.ago)
        end
      end
      let!(:borrowed_book) { create(:book, serial_number: "000012") }
      let!(:loan) { create(:loan, book: borrowed_book) }

      it "returns only borrowed books with the current loan and reader" do
        get "/books", params: { status: "borrowed" }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["data"]).to match([
          include(
            "serial_number" => borrowed_book.serial_number,
            "status" => "borrowed",
            "current_loan" => {
              "borrowed_at" => loan.borrowed_at.iso8601,
              "due_on" => loan.due_on.iso8601,
              "reader" => {
                "card_number" => loan.reader.card_number,
                "full_name" => loan.reader.full_name,
                "email" => loan.reader.email
              }
            }
          )
        ])
        expect(response.parsed_body.dig("meta", "total")).to eq(1)
      end

      it "returns books that are not currently borrowed as available" do
        get "/books", params: { status: "available" }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["data"].pluck("serial_number")).to eq(
          [ available_book.serial_number, returned_book.serial_number ]
        )
        expect(response.parsed_body.dig("meta", "total")).to eq(2)
      end
    end

    it "returns the requested page with the real total" do
      5.times { |index| create(:book, serial_number: format("%06d", index + 1)) }

      get "/books", params: { page: "3", per_page: "2" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["meta"]).to eq("page" => 3, "per_page" => 2, "total" => 5)
      expect(response.parsed_body["data"].pluck("serial_number")).to eq([ "000005" ])
    end

    it "caps per_page at 100" do
      create(:book)

      get "/books", params: { per_page: "101" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("meta", "per_page")).to eq(100)
    end

    it "returns details for every invalid list parameter" do
      get "/books", params: { status: "lost", page: "0", per_page: "many" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_params")
      expect(response.parsed_body.dig("error", "details")).to eq(
        "status" => [ "must be one of: available, borrowed" ],
        "page" => [ "must be a positive integer" ],
        "per_page" => [ "must be a positive integer" ]
      )
    end

    it "returns 500 internal_error without leaking details" do
      allow(Book).to receive(:active).and_raise(StandardError, "secret db detail")

      get "/books"

      expect(response).to have_http_status(:internal_server_error)
      expect(response.parsed_body["error"]).to include("code" => "internal_error", "details" => {})
      expect(response.body).not_to include("secret db detail")
    end
  end

  describe "GET /books/:serial_number" do
    it "returns the current loan and the loan history, newest first" do
      book = create(:book, serial_number: "123456")
      returned_loan = create(:loan, book: book, borrowed_at: 2.days.ago, returned_at: 1.day.ago)
      active_loan = create(:loan, book: book, borrowed_at: 1.hour.ago)

      get "/books/#{book.serial_number}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "serial_number" => book.serial_number,
        "status" => "borrowed",
        "current_loan" => include("reader" => include("card_number" => active_loan.reader.card_number)),
        "loans" => [
          include("borrowed_at" => active_loan.borrowed_at.iso8601, "returned_at" => nil),
          include("borrowed_at" => returned_loan.borrowed_at.iso8601, "returned_at" => returned_loan.returned_at.iso8601)
        ]
      )
    end

    it "returns not_found for a discarded book" do
      create(:book, serial_number: "654321").update!(discarded_at: Time.current)

      get "/books/654321"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["error"]).to include("code" => "not_found", "details" => {})
    end

    it "returns not_found for a malformed serial number" do
      get "/books/abcdef"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body.dig("error", "code")).to eq("not_found")
    end
  end

  describe "DELETE /books/:serial_number" do
    it "marks an active book as discarded and returns no content" do
      book = create(:book, serial_number: "222222")

      delete "/books/#{book.serial_number}"

      expect(response).to have_http_status(:no_content)
      expect(response.body).to eq("")
      expect(book.reload.discarded_at).to be_present
    end

    it "returns not_found for a discarded book" do
      create(:book, serial_number: "333333").update!(discarded_at: Time.current)

      delete "/books/333333"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["error"]).to include("code" => "not_found")
    end

    it "returns conflict when a book is currently borrowed" do
      book = create(:book, serial_number: "444444")
      create(:loan, book: book, borrowed_at: 1.hour.ago)

      delete "/books/#{book.serial_number}"

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body["error"]).to include("code" => "currently_borrowed")
    end
  end

  describe "POST /books" do
    let(:attributes) do
      { serial_number: "123456", title: "  The Hobbit  ", author: "  J. R. R. Tolkien  " }
    end

    it "registers a book and returns the normalized resource" do
      post "/books", params: attributes, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include(
        "serial_number" => "123456",
        "title" => "The Hobbit",
        "author" => "J. R. R. Tolkien",
        "status" => "available",
        "current_loan" => nil
      )
      expect(Book.find_by!(serial_number: "123456")).to be_persisted
    end

    it "returns validation details for invalid book attributes" do
      post "/books", params: attributes.merge(serial_number: "invalid", title: " "), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("validation_failed")
      expect(response.parsed_body.dig("error", "details")).to include(
        "serial_number" => [ "is invalid" ],
        "title" => [ "can't be blank" ]
      )
    end

    it "returns a validation error when the serial number is already registered" do
      create(:book, serial_number: attributes.fetch(:serial_number))

      post "/books", params: attributes, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("validation_failed")
      expect(response.parsed_body.dig("error", "details", "serial_number")).to include("is already taken or reserved")
    end

    it "keeps the serial number of a discarded book reserved" do
      create(:book, serial_number: attributes.fetch(:serial_number)).update!(discarded_at: Time.current)

      post "/books", params: attributes, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "details", "serial_number")).to include("is already taken or reserved")
    end

    it "returns 400 bad_request for malformed JSON" do
      post "/books", params: "{oops", headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["error"]).to include("code" => "bad_request", "details" => {})
    end
  end
end
