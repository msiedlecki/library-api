require "rails_helper"

RSpec.describe Book, type: :model do
  describe "associations" do
    it "restricts deletion when loans exist" do
      book = create(:book)
      create(:loan, book: book)

      expect { book.destroy! }.to raise_error(ActiveRecord::DeleteRestrictionError)
    end
  end

  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:book)).to be_valid
    end

    it "requires a six-digit serial number" do
      expect(build(:book, serial_number: "12345")).not_to be_valid
      expect(build(:book, serial_number: "ABC123")).not_to be_valid
    end

    it "requires a unique serial number" do
      book = create(:book)

      expect(build(:book, serial_number: book.serial_number)).not_to be_valid
    end

    it "requires a title and author of at most 255 characters" do
      expect(build(:book, title: " ")).not_to be_valid
      expect(build(:book, author: " ")).not_to be_valid
      expect(build(:book, title: "t" * 256)).not_to be_valid
      expect(build(:book, author: "a" * 256)).not_to be_valid
    end
  end

  describe "normalizations" do
    it "strips whitespace from the title and author" do
      book = build(:book, title: "  The Hobbit  ", author: "  J. R. R. Tolkien  ")

      expect(book.title).to eq("The Hobbit")
      expect(book.author).to eq("J. R. R. Tolkien")
    end
  end
end
