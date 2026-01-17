# frozen_string_literal: true

RSpec.describe CloudsqlRubyConnector::IpAddressTypes do
  describe ".valid?" do
    it "returns true for valid types" do
      expect(described_class.valid?("PUBLIC")).to be true
      expect(described_class.valid?("PRIVATE")).to be true
      expect(described_class.valid?("PSC")).to be true
      expect(described_class.valid?("public")).to be true
    end

    it "returns false for invalid types" do
      expect(described_class.valid?("INVALID")).to be false
      expect(described_class.valid?("")).to be false
    end
  end

  describe ".normalize" do
    it "normalizes valid types to uppercase" do
      expect(described_class.normalize("public")).to eq("PUBLIC")
      expect(described_class.normalize("Private")).to eq("PRIVATE")
      expect(described_class.normalize(:psc)).to eq("PSC")
    end

    it "raises for invalid types" do
      expect { described_class.normalize("invalid") }.to raise_error(CloudsqlRubyConnector::ConfigurationError)
    end
  end

  describe ".api_key" do
    it "returns correct API key for each type" do
      expect(described_class.api_key("PUBLIC")).to eq("PRIMARY")
      expect(described_class.api_key("PRIVATE")).to eq("PRIVATE")
      expect(described_class.api_key("PSC")).to eq("PSC")
    end
  end
end
