require "swagger_helper"

RSpec.describe "Books API", type: :request do
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
