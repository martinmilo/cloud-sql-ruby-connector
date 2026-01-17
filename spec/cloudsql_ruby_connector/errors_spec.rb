# frozen_string_literal: true

RSpec.describe CloudsqlRubyConnector::Error do
  it "stores error code" do
    error = described_class.new("test message", code: "ECODE")
    expect(error.message).to eq("test message")
    expect(error.code).to eq("ECODE")
  end
end

RSpec.describe CloudsqlRubyConnector::AuthenticationError do
  it "has default code" do
    error = described_class.new("auth failed")
    expect(error.code).to eq("EAUTH")
  end
end

RSpec.describe CloudsqlRubyConnector::ConnectionError do
  it "has default code" do
    error = described_class.new("connection failed")
    expect(error.code).to eq("ECONNECTION")
  end
end

RSpec.describe CloudsqlRubyConnector::ConfigurationError do
  it "has default code" do
    error = described_class.new("config invalid")
    expect(error.code).to eq("ECONFIG")
  end
end

RSpec.describe CloudsqlRubyConnector::IpAddressError do
  it "has default code" do
    error = described_class.new("no ip")
    expect(error.code).to eq("ENOIPADDRESS")
  end
end
