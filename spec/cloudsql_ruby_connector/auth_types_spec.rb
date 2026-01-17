# frozen_string_literal: true

RSpec.describe CloudsqlRubyConnector::AuthTypes do
  describe ".valid?" do
    it "returns true for valid types" do
      expect(described_class.valid?("PASSWORD")).to be true
      expect(described_class.valid?("IAM")).to be true
      expect(described_class.valid?("password")).to be true
    end

    it "returns false for invalid types" do
      expect(described_class.valid?("INVALID")).to be false
      expect(described_class.valid?("")).to be false
    end
  end

  describe ".normalize" do
    it "normalizes valid types to uppercase" do
      expect(described_class.normalize("password")).to eq("PASSWORD")
      expect(described_class.normalize("Iam")).to eq("IAM")
      expect(described_class.normalize(:iam)).to eq("IAM")
    end

    it "raises for invalid types" do
      expect { described_class.normalize("invalid") }.to raise_error(CloudsqlRubyConnector::ConfigurationError)
    end
  end
end
