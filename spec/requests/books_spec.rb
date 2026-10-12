require "swagger_helper"

RSpec.describe "Books API", type: :request do
  describe "GET /books" do
    it "lists active books in serial-number order with default pagination" do
      create(:book, serial_number: "000003", title: "Third")
      create(:book, serial_number: "000001", title: "First")
      create(:book, serial_number: "000002", title: "Discarded").update!(discarded_at: Time.current)

      get "/books"

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)).to include(
        "data" => [
          include("serial_number" => "000001", "title" => "First", "status" => "available", "current_loan" => nil),
          include("serial_number" => "000003", "title" => "Third", "status" => "available", "current_loan" => nil)
        ],
        "meta" => { "page" => 1, "per_page" => 25, "total" => 2 }
      )
    end

    it "returns only borrowed books with the current loan and reader" do
      available_book = create(:book, serial_number: "000010")
      returned_book = create(:book, serial_number: "000011").tap do |book|
        create(:loan, book: book, borrowed_at: 10.days.ago, returned_at: 1.day.ago)
      end
      borrowed_book = create(:book, serial_number: "000012")
      loan = create(:loan, book: borrowed_book)

      get "/books", params: { status: "borrowed" }

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)["data"]).to match([
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
      expect(JSON.parse(response.body).dig("meta", "total")).to eq(1)
    end

    it "returns books that are not currently borrowed as available" do
      available_book = create(:book, serial_number: "000010")
      returned_book = create(:book, serial_number: "000011").tap do |book|
        create(:loan, book: book, borrowed_at: 10.days.ago, returned_at: 1.day.ago)
      end
      borrowed_book = create(:book, serial_number: "000012")
      create(:loan, book: borrowed_book)

      get "/books", params: { status: "available" }

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)["data"].pluck("serial_number")).to eq([ available_book.serial_number, returned_book.serial_number ])
      expect(JSON.parse(response.body).dig("meta", "total")).to eq(2)
    end

    it "returns the requested page with the real total" do
      5.times { |index| create(:book, serial_number: format("%06d", index + 1)) }

      get "/books", params: { page: "3", per_page: "2" }

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)["meta"]).to eq("page" => 3, "per_page" => 2, "total" => 5)
      expect(JSON.parse(response.body)["data"].pluck("serial_number")).to eq([ "000005" ])
    end

    it "caps per_page at 100" do
      create(:book)

      get "/books", params: { per_page: "101" }

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body).dig("meta", "per_page")).to eq(100)
    end

    it "returns details for every invalid list parameter" do
      get "/books", params: { status: "lost", page: "0", per_page: "many" }

      expect(response.status).to eq(422)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("invalid_params")
      expect(JSON.parse(response.body).dig("error", "details")).to eq(
        "status" => [ "must be one of: available, borrowed" ],
        "page" => [ "must be a positive integer" ],
        "per_page" => [ "must be a positive integer" ]
      )
    end

    it "returns 500 internal_error without leaking details" do
      allow(Book).to receive(:active).and_raise(StandardError, "secret db detail")

      get "/books"

      expect(response.status).to eq(500)
      expect(JSON.parse(response.body)["error"]).to include("code" => "internal_error", "details" => {})
      expect(response.body).not_to include("secret db detail")
    end
  end

  path "/books" do
    post "registers a book" do
      tags "Books"
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          serial_number: { type: :string },
          title: { type: :string },
          author: { type: :string }
        },
        required: %w[serial_number title author]
      }

      response "201", "creates a book" do
        example "application/json", :book_created,
          {
            serial_number: "123456",
            title: "The Hobbit",
            author: "J. R. R. Tolkien",
            status: "available",
            current_loan: nil
          },
          "Book created"

        let(:body) do
          { serial_number: "123456", title: "  The Hobbit  ", author: "  J. R. R. Tolkien  " }
        end

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(response.status).to eq(201)
          expect(body).to include(
            "serial_number" => "123456",
            "title" => "The Hobbit",
            "author" => "J. R. R. Tolkien",
            "status" => "available",
            "current_loan" => nil
          )
          expect(Book.find_by!(serial_number: "123456")).to be_persisted
        end
      end

      response "422", "returns validation details for invalid book attributes" do
        example "application/json", :invalid_book_attributes,
          {
            error: {
              code: "validation_failed",
              details: {
                serial_number: [ "is invalid" ],
                title: [ "can't be blank" ]
              }
            }
          },
          "Invalid book attributes"

        let(:body) do
          { serial_number: "invalid", title: " ", author: "J. R. R. Tolkien" }
        end

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(response.status).to eq(422)
          expect(body.dig("error", "code")).to eq("validation_failed")
          expect(body.dig("error", "details")).to include(
            "serial_number" => [ "is invalid" ],
            "title" => [ "can't be blank" ]
          )
        end
      end

      response "422", "returns a validation error when the serial number is already registered" do
        example "application/json", :serial_number_taken,
          {
            error: {
              code: "validation_failed",
              details: {
                serial_number: [ "is already taken or reserved" ]
              }
            }
          },
          "Serial number already taken"

        let(:body) do
          { serial_number: "123456", title: "The Hobbit", author: "J. R. R. Tolkien" }
        end

        before do
          create(:book, serial_number: "123456")
        end

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(response.status).to eq(422)
          expect(body.dig("error", "code")).to eq("validation_failed")
          expect(body.dig("error", "details", "serial_number")).to include("is already taken or reserved")
        end
      end

      response "422", "keeps the serial number of a discarded book reserved" do
        example "application/json", :discarded_serial_number_reserved,
          {
            error: {
              code: "validation_failed",
              details: {
                serial_number: [ "is already taken or reserved" ]
              }
            }
          },
          "Discarded serial number reserved"

        let(:body) do
          { serial_number: "123456", title: "The Hobbit", author: "J. R. R. Tolkien" }
        end

        before do
          create(:book, serial_number: "123456").update!(discarded_at: Time.current)
        end

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(response.status).to eq(422)
          expect(body.dig("error", "details", "serial_number")).to include("is already taken or reserved")
        end
      end
    end
  end

  it "returns 400 bad_request for malformed JSON" do
    post "/books", params: "{oops", headers: { "CONTENT_TYPE" => "application/json" }

    expect(response.status).to eq(400)
    expect(JSON.parse(response.body)["error"]).to include("code" => "bad_request", "details" => {})
  end

  path "/books/{serial_number}" do
    get "returns a book detail" do
      tags "Books"
      produces "application/json"
      parameter name: :serial_number, in: :path, type: :string, required: true

      response "200", "returns the current loan and the loan history" do
        example "application/json", :book_detail,
          {
            serial_number: "123456",
            status: "borrowed",
            current_loan: {
              borrowed_at: "2026-10-01T10:00:00.000Z",
              due_on: "2026-10-31",
              reader: {
                card_number: "1001",
                full_name: "Jane Doe",
                email: "jane@example.com"
              }
            },
            loans: [
              {
                borrowed_at: "2026-10-01T10:00:00.000Z",
                returned_at: nil,
                reader: {
                  card_number: "1001",
                  full_name: "Jane Doe",
                  email: "jane@example.com"
                }
              },
              {
                borrowed_at: "2026-09-30T10:00:00.000Z",
                returned_at: "2026-10-01T09:00:00.000Z",
                reader: {
                  card_number: "1001",
                  full_name: "Jane Doe",
                  email: "jane@example.com"
                }
              }
            ]
          },
          "Book detail"

        let(:serial_number) { "123456" }

        before do
          @book = create(:book, serial_number: "123456")
          @returned_loan = create(:loan, book: @book, borrowed_at: 2.days.ago, returned_at: 1.day.ago)
          @active_loan = create(:loan, book: @book, borrowed_at: 1.hour.ago)
        end

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(response.status).to eq(200)
          expect(body).to include(
            "serial_number" => @book.serial_number,
            "status" => "borrowed",
            "current_loan" => include("reader" => include("card_number" => @active_loan.reader.card_number)),
            "loans" => [
              include("borrowed_at" => @active_loan.borrowed_at.iso8601, "returned_at" => nil),
              include("borrowed_at" => @returned_loan.borrowed_at.iso8601, "returned_at" => @returned_loan.returned_at.iso8601)
            ]
          )
        end
      end

      response "404", "malformed serial_number or discarded book" do
        example "application/json", :malformed_serial_number,
          {
            error: {
              code: "not_found",
              details: {}
            }
          },
          "Malformed serial number"

        example "application/json", :discarded_book,
          {
            error: {
              code: "not_found",
              details: {}
            }
          },
          "Discarded book"

        context "when serial number is malformed" do
          let(:serial_number) { "abcdef" }

          run_test! do |response|
            body = JSON.parse(response.body)

            expect(response.status).to eq(404)
            expect(body.dig("error", "code")).to eq("not_found")
          end
        end

        context "when book is discarded" do
          let(:serial_number) { "654321" }

          before do
            create(:book, serial_number: "654321")
              .update!(discarded_at: Time.current)
          end

          run_test! do |response|
            body = JSON.parse(response.body)

            expect(response.status).to eq(404)
            expect(body["error"]).to include(
              "code" => "not_found",
              "details" => {}
            )
          end
        end
      end
    end

    delete "marks a book as discarded" do
      tags "Books"
      parameter name: :serial_number, in: :path, type: :string, required: true

      response "204", "marks an active book as discarded" do
        example "application/json", :book_discarded_delete,
          {},
          "Book discarded"

        let(:serial_number) { "222222" }

        before do
          @book = create(:book, serial_number: "222222")
        end

        run_test! do |response|
          expect(response.status).to eq(204)
          expect(response.body).to eq("")
          expect(@book.reload.discarded_at).to be_present
        end
      end

      response "404", "returns not_found for a discarded book" do
        example "application/json", :discarded_book_delete,
          {
            error: {
              code: "not_found",
              details: {}
            }
          },
          "Book discarded"

        let(:serial_number) { "333333" }

        before do
          create(:book, serial_number: "333333").update!(discarded_at: Time.current)
        end

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(response.status).to eq(404)
          expect(body["error"]).to include("code" => "not_found")
        end
      end

      response "409", "returns conflict when a book is currently borrowed" do
        example "application/json", :book_currently_borrowed_delete,
          {
            error: {
              code: "currently_borrowed",
              details: {}
            }
          },
          "Book currently borrowed"

        let(:serial_number) { "444444" }

        before do
          @book = create(:book, serial_number: "444444")
          create(:loan, book: @book, borrowed_at: 1.hour.ago)
        end

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(response.status).to eq(409)
          expect(body["error"]).to include("code" => "currently_borrowed")
        end
      end
    end
  end

  path "/books/{serial_number}/borrow" do
    post "creates a current loan" do
      tags "Books"
      consumes "application/json"
      produces "application/json"
      parameter name: :serial_number, in: :path, type: :string, required: true
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          reader: {
            type: :object,
            properties: {
              card_number: { type: :string },
              full_name: { type: :string },
              email: { type: :string }
            },
            required: %w[card_number full_name email]
          }
        },
        required: %w[reader]
      }

      response "201", "creates a current loan and stores the reader data" do
        example "application/json", :book_borrowed,
          {
            borrowed_at: "2026-10-12T08:00:00.000Z",
            due_on: "2026-11-11",
            reader: {
              card_number: "123456",
              full_name: "Jane Doe",
              email: "jane@example.com"
            }
          },
          "Book borrowed"

        let(:serial_number) { "555555" }
        let(:body) do
          { reader: { card_number: "123456", full_name: "Jane Doe", email: "jane@example.com" } }
        end

        before do
          @book = create(:book, serial_number: "555555")
        end

        run_test! do |response|
          parsed = JSON.parse(response.body)
          expect(response.status).to eq(201)
          expect(parsed).to include(
            "borrowed_at" => a_kind_of(String),
            "due_on" => a_kind_of(String),
            "reader" => include(
              "card_number" => "123456",
              "full_name" => "Jane Doe",
              "email" => "jane@example.com"
            )
          )
          expect(@book.reload.active_loan).to be_present
          expect(@book.active_loan.reader.email).to eq("jane@example.com")
        end
      end

      response "409", "returns conflict when the book is already borrowed" do
        example "application/json", :book_already_borrowed,
          {
            error: {
              code: "currently_borrowed",
              details: {}
            }
          },
          "Book already borrowed"

        let(:serial_number) { "666666" }
        let(:body) do
          { reader: { card_number: "123456", full_name: "Jane Doe", email: "jane@example.com" } }
        end

        before do
          @book = create(:book, serial_number: "666666")
          create(:loan, book: @book, reader: create(:reader, card_number: "654321"), borrowed_at: 1.hour.ago)
        end

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(response.status).to eq(409)
          expect(body["error"]).to include("code" => "currently_borrowed")
        end
      end
    end
  end

  path "/books/{serial_number}/return" do
    post "marks the active loan as returned" do
      tags "Books"
      produces "application/json"
      parameter name: :serial_number, in: :path, type: :string, required: true

      response "200", "marks the active loan as returned" do
        example "application/json", :loan_returned,
          {
            borrowed_at: "2026-10-10T10:00:00.000Z",
            returned_at: "2026-10-12T10:00:00.000Z",
            reader: {
              card_number: "1001",
              full_name: "Jane Doe",
              email: "jane@example.com"
            }
          },
          "Loan returned"

        let(:serial_number) { "777777" }

        before do
          @book = create(:book, serial_number: "777777")
          @loan = create(:loan, book: @book, borrowed_at: 2.days.ago, due_on: 30.days.from_now.to_date)
        end

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(response.status).to eq(200)
          expect(body).to include(
            "borrowed_at" => @loan.borrowed_at.iso8601,
            "returned_at" => a_kind_of(String),
            "reader" => include("card_number" => @loan.reader.card_number)
          )
          expect(@book.reload.active_loan).to be_nil
        end
      end

      response "404", "returns not_found when the book cannot be returned" do
        example "application/json", :malformed_serial_number_return,
          {
            error: {
              code: "not_found",
              details: {}
            }
          },
          "Malformed serial number"

        example "application/json", :no_active_loan_return,
          {
            error: {
              code: "not_found",
              details: {}
            }
          },
          "No active loan to return"

        context "when serial number is malformed" do
          let(:serial_number) { "abcdef" }

          run_test! do |response|
            body = JSON.parse(response.body)

            expect(response.status).to eq(404)
            expect(body.dig("error", "code")).to eq("not_found")
          end
        end

        context "when the book has no active loan" do
          let(:serial_number) { "888888" }

          before do
            @book = create(:book, serial_number: "888888")
            create(:loan, book: @book, borrowed_at: 3.days.ago, returned_at: 1.day.ago)
          end

          run_test! do |response|
            body = JSON.parse(response.body)

            expect(response.status).to eq(404)
            expect(body["error"]).to include(
              "code" => "not_found",
              "details" => {}
            )
          end
        end
      end
    end
  end
end
