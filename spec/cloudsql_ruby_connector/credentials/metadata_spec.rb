# frozen_string_literal: true

RSpec.describe CloudsqlRubyConnector::Credentials::Metadata do
  let(:credentials) { described_class.new }
  let(:metadata_url) { "http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token" }

  describe "#access_token" do
    let(:token_response) do
      {
        "access_token" => "ya29.metadata-token",
        "expires_in" => 3600,
        "token_type" => "Bearer"
      }
    end

    before do
      stub_request(:get, /169\.254\.169\.254.*token/)
        .with(headers: { "Metadata-Flavor" => "Google" })
        .to_return(status: 200, body: token_response.to_json)
    end

    it "fetches token from metadata server" do
      token = credentials.access_token(scope: :admin)
      expect(token).to eq("ya29.metadata-token")
    end

    it "includes Metadata-Flavor header" do
      credentials.access_token(scope: :admin)

      expect(WebMock).to have_requested(:get, /169\.254\.169\.254/)
        .with(headers: { "Metadata-Flavor" => "Google" })
    end

    it "includes scope in request" do
      credentials.access_token(scope: :admin)

      expect(WebMock).to have_requested(:get, /scopes=https.*sqlservice\.admin/)
    end

    context "when not running on GCE" do
      before do
        stub_request(:get, /169\.254\.169\.254/).to_timeout
      end

      it "raises AuthenticationError" do
        expect do
          credentials.access_token(scope: :admin)
        end.to raise_error(CloudsqlRubyConnector::AuthenticationError, /Not running on GCE/)
      end
    end

    context "when metadata server returns error" do
      before do
        stub_request(:get, /169\.254\.169\.254/)
          .to_return(status: 404, body: { "error" => "not_found" }.to_json)
      end

      it "raises AuthenticationError" do
        expect do
          credentials.access_token(scope: :admin)
        end.to raise_error(CloudsqlRubyConnector::AuthenticationError, /Failed to get metadata token/)
      end
    end
  end
end
