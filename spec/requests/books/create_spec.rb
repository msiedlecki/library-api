require "swagger_helper"

RSpec.describe "Books API", type: :request do
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
end
