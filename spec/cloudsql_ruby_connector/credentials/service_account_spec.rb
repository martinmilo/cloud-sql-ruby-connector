# frozen_string_literal: true

RSpec.describe CloudsqlRubyConnector::Credentials::ServiceAccount do
  let(:service_account_data) { fixture_json("service_account.json") }
  let(:credentials) { described_class.new(service_account_data) }

  describe ".from_file" do
    it "loads service account credentials" do
      creds = described_class.from_file(fixture_path("service_account.json"))
      expect(creds).to be_a(described_class)
      expect(creds.client_email).to eq("test@test-project.iam.gserviceaccount.com")
    end

    it "returns UserCredentials for authorized_user type" do
      creds = described_class.from_file(fixture_path("user_credentials.json"))
      expect(creds).to be_a(CloudsqlRubyConnector::Credentials::UserCredentials)
    end

    it "raises for non-existent file" do
      expect do
        described_class.from_file("/nonexistent/path.json")
      end.to raise_error(Errno::ENOENT)
    end
  end

  describe "#access_token" do
    let(:token_response) do
      {
        "access_token" => "ya29.test-token",
        "expires_in" => 3600,
        "token_type" => "Bearer"
      }
    end

    before do
      stub_request(:post, "https://oauth2.googleapis.com/token")
        .to_return(status: 200, body: token_response.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "fetches an access token" do
      token = credentials.access_token(scope: :admin)
      expect(token).to eq("ya29.test-token")
    end

    it "caches the token" do
      credentials.access_token(scope: :admin)
      credentials.access_token(scope: :admin)

      expect(WebMock).to have_requested(:post, "https://oauth2.googleapis.com/token").once
    end

    it "fetches separate tokens for different scopes" do
      credentials.access_token(scope: :admin)
      credentials.access_token(scope: :login)

      expect(WebMock).to have_requested(:post, "https://oauth2.googleapis.com/token").twice
    end

    it "sends JWT assertion in request" do
      credentials.access_token(scope: :admin)

      expect(WebMock).to(have_requested(:post, "https://oauth2.googleapis.com/token")
        .with { |req| req.body.include?("grant_type=urn") && req.body.include?("assertion=") })
    end

    context "when token request fails" do
      before do
        stub_request(:post, "https://oauth2.googleapis.com/token")
          .to_return(status: 401, body: { "error" => "invalid_grant", "error_description" => "Token expired" }.to_json)
      end

      it "raises AuthenticationError" do
        expect do
          credentials.access_token(scope: :admin)
        end.to raise_error(CloudsqlRubyConnector::AuthenticationError, /Token expired/)
      end
    end

    context "when request times out" do
      before do
        stub_request(:post, "https://oauth2.googleapis.com/token").to_timeout
      end

      it "raises AuthenticationError" do
        expect do
          credentials.access_token(scope: :admin)
        end.to raise_error(CloudsqlRubyConnector::AuthenticationError, /timed out/)
      end
    end
  end
end
