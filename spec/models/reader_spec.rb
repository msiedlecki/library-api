require "rails_helper"

RSpec.describe Reader, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:reader)).to be_valid
    end

    it "requires a unique six-digit card number" do
      reader = create(:reader)

      expect(build(:reader, card_number: "12345")).not_to be_valid
      expect(build(:reader, card_number: reader.card_number)).not_to be_valid
    end

    it "requires a full name of at most 255 characters" do
      expect(build(:reader, full_name: " ")).not_to be_valid
      expect(build(:reader, full_name: "n" * 256)).not_to be_valid
    end

    it "requires a valid, unique email address" do
      reader = create(:reader)

      expect(build(:reader, email: "not-an-email")).not_to be_valid
      expect(build(:reader, email: reader.email)).not_to be_valid
    end
  end

  describe "normalizations" do
    it "strips the name and strips and lowercases the email" do
      reader = build(:reader, full_name: "  Frank Herbert  ", email: "  FRANK@EXAMPLE.COM  ")

      expect(reader.full_name).to eq("Frank Herbert")
      expect(reader.email).to eq("frank@example.com")
    end
  end

  describe ".resolve!" do
    it "returns the existing reader when the card number matches and the identity is the same" do
      reader = create(:reader, card_number: "123456", full_name: "Frank Herbert", email: "frank@example.com")

      expect(described_class.resolve!(card_number: "123456", full_name: "Frank Herbert", email: "frank@example.com")).to eq(reader)
    end

    it "raises DataMismatch when the same card number belongs to a different person" do
      create(:reader, card_number: "123456", full_name: "Frank Herbert", email: "frank@example.com")

      expect do
        described_class.resolve!(card_number: "123456", full_name: "Dune Reader", email: "reader@example.com")
      end.to raise_error(Reader::DataMismatch)
    end
  end
end
