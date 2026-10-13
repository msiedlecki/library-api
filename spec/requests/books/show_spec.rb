require "swagger_helper"

RSpec.describe "Books API", type: :request do
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
            create(:book, serial_number: "654321").update!(discarded_at: Time.current)
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
