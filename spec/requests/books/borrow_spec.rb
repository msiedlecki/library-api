require "swagger_helper"

RSpec.describe "Books API", type: :request do
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
end
