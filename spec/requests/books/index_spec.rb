require "swagger_helper"

RSpec.describe "Books API", type: :request do
  path "/books" do
    get "lists active books" do
      tags "Books"
      produces "application/json"

      response "200", "lists active books in serial-number order with default pagination" do
        example "application/json", :list_books_default,
          {
            data: [
              { serial_number: "000001", title: "First", status: "available", current_loan: nil },
              { serial_number: "000003", title: "Third", status: "available", current_loan: nil }
            ],
            meta: { page: 1, per_page: 25, total: 2 }
          },
          "List books"

        before do
          create(:book, serial_number: "000003", title: "Third")
          create(:book, serial_number: "000001", title: "First")
          create(:book, serial_number: "000002", title: "Discarded").update!(discarded_at: Time.current)
          get "/books"
        end

        it "returns the default collection" do
          body = JSON.parse(response.body)
          expect(response.status).to eq(200)
          expect(body).to include(
            "data" => [
              include("serial_number" => "000001", "title" => "First", "status" => "available", "current_loan" => nil),
              include("serial_number" => "000003", "title" => "Third", "status" => "available", "current_loan" => nil)
            ],
            "meta" => { "page" => 1, "per_page" => 25, "total" => 2 }
          )
        end
      end

      response "200", "returns only borrowed books with the current loan and reader" do
        example "application/json", :borrowed_books,
          {
            data: [
              {
                serial_number: "000012",
                status: "borrowed",
                current_loan: {
                  borrowed_at: "2026-10-12T08:00:00.000Z",
                  due_on: "2026-11-11",
                  reader: {
                    card_number: "1001",
                    full_name: "Jane Doe",
                    email: "jane@example.com"
                  }
                }
              }
            ],
            meta: { page: 1, per_page: 25, total: 1 }
          },
          "Borrowed books"

        before do
          create(:book, serial_number: "000010")
          create(:book, serial_number: "000011").tap do |book|
            create(:loan, book: book, borrowed_at: 10.days.ago, returned_at: 1.day.ago)
          end
          @borrowed_book = create(:book, serial_number: "000012")
          @loan = create(:loan, book: @borrowed_book)
          get "/books", params: { status: "borrowed" }
        end

        it "returns only borrowed books" do
          body = JSON.parse(response.body)
          expect(response.status).to eq(200)
          expect(body["data"]).to match([
            include(
              "serial_number" => @borrowed_book.serial_number,
              "status" => "borrowed",
              "current_loan" => {
                "borrowed_at" => @loan.borrowed_at.iso8601,
                "due_on" => @loan.due_on.iso8601,
                "reader" => {
                  "card_number" => @loan.reader.card_number,
                  "full_name" => @loan.reader.full_name,
                  "email" => @loan.reader.email
                }
              }
            )
          ])
          expect(body.dig("meta", "total")).to eq(1)
        end
      end

      response "200", "returns books that are not currently borrowed as available" do
        example "application/json", :available_books,
          {
            data: [
              { serial_number: "000010", title: "Available", status: "available", current_loan: nil },
              { serial_number: "000011", title: "Returned", status: "available", current_loan: nil }
            ],
            meta: { page: 1, per_page: 25, total: 2 }
          },
          "Available books"

        before do
          @available_book = create(:book, serial_number: "000010")
          @returned_book = create(:book, serial_number: "000011").tap do |book|
            create(:loan, book: book, borrowed_at: 10.days.ago, returned_at: 1.day.ago)
          end
          @borrowed_book = create(:book, serial_number: "000012")
          create(:loan, book: @borrowed_book)
          get "/books", params: { status: "available" }
        end

        it "returns available books only" do
          body = JSON.parse(response.body)
          expect(response.status).to eq(200)
          expect(body["data"].pluck("serial_number")).to eq([ @available_book.serial_number, @returned_book.serial_number ])
          expect(body.dig("meta", "total")).to eq(2)
        end
      end

      response "200", "returns the requested page with the real total" do
        example "application/json", :paged_books,
          {
            data: [
              { serial_number: "000005", title: "Book 5", status: "available", current_loan: nil }
            ],
            meta: { page: 3, per_page: 2, total: 5 }
          },
          "Paginated books"

        before do
          5.times { |index| create(:book, serial_number: format("%06d", index + 1)) }
          get "/books", params: { page: "3", per_page: "2" }
        end

        it "returns the requested page" do
          body = JSON.parse(response.body)
          expect(response.status).to eq(200)
          expect(body["meta"]).to eq("page" => 3, "per_page" => 2, "total" => 5)
          expect(body["data"].pluck("serial_number")).to eq([ "000005" ])
        end
      end

      response "200", "caps per_page at 100" do
        example "application/json", :per_page_capped,
          {
            data: [
              { serial_number: "000001", title: "Book 1", status: "available", current_loan: nil }
            ],
            meta: { page: 1, per_page: 100, total: 1 }
          },
          "Per page capped"

        before do
          create(:book)
          get "/books", params: { per_page: "101" }
        end

        it "caps the page size" do
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body).dig("meta", "per_page")).to eq(100)
        end
      end

      response "422", "returns details for every invalid list parameter" do
        example "application/json", :invalid_list_params,
          {
            error: {
              code: "invalid_params",
              details: {
                status: [ "must be one of: available, borrowed" ],
                page: [ "must be a positive integer" ],
                per_page: [ "must be a positive integer" ]
              }
            }
          },
          "Invalid list parameters"

        before do
          get "/books", params: { status: "lost", page: "0", per_page: "many" }
        end

        it "returns validation details for invalid params" do
          body = JSON.parse(response.body)
          expect(response.status).to eq(422)
          expect(body.dig("error", "code")).to eq("invalid_params")
          expect(body.dig("error", "details")).to eq(
            "status" => [ "must be one of: available, borrowed" ],
            "page" => [ "must be a positive integer" ],
            "per_page" => [ "must be a positive integer" ]
          )
        end
      end

      response "500", "returns 500 internal_error without leaking details" do
        example "application/json", :internal_error,
          {
            error: {
              code: "internal_error",
              details: {}
            }
          },
          "Internal error"

        before do
          allow(Book).to receive(:active).and_raise(StandardError, "secret db detail")
          get "/books"
        end

        it "does not leak internal details" do
          expect(response.status).to eq(500)
          expect(JSON.parse(response.body)["error"]).to include("code" => "internal_error", "details" => {})
          expect(response.body).not_to include("secret db detail")
        end
      end
    end
  end
end
