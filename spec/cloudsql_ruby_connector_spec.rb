# frozen_string_literal: true

RSpec.describe CloudsqlRubyConnector do
  it "has a version number" do
    expect(CloudsqlRubyConnector::VERSION).not_to be_nil
    expect(CloudsqlRubyConnector::VERSION).to eq("0.1.0")
  end
end
