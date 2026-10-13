require "swagger_helper"

RSpec.describe "Books API", type: :request do
  path "/books/{serial_number}" do
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
end
