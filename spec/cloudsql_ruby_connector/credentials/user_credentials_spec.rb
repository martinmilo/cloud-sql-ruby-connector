# frozen_string_literal: true

RSpec.describe CloudsqlRubyConnector::Credentials::UserCredentials do
  let(:user_credentials_data) { fixture_json("user_credentials.json") }
  let(:credentials) { described_class.new(user_credentials_data) }

  describe "#access_token" do
    let(:token_response) do
      {
        "access_token" => "ya29.user-token",
        "expires_in" => 3600,
        "token_type" => "Bearer"
      }
    end

    before do
      stub_request(:post, "https://oauth2.googleapis.com/token")
        .to_return(status: 200, body: token_response.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "fetches an access token using refresh token" do
      token = credentials.access_token(scope: :admin)
      expect(token).to eq("ya29.user-token")
    end

    it "sends refresh token in request" do
      credentials.access_token(scope: :admin)

      expect(WebMock).to have_requested(:post, "https://oauth2.googleapis.com/token")
        .with(body: hash_including(
          "grant_type" => "refresh_token",
          "refresh_token" => "test-refresh-token",
          "client_id" => "123456789.apps.googleusercontent.com",
          "client_secret" => "test-client-secret"
        ))
    end

    it "caches the token" do
      credentials.access_token(scope: :admin)
      credentials.access_token(scope: :admin)

      expect(WebMock).to have_requested(:post, "https://oauth2.googleapis.com/token").once
    end

    context "when refresh fails" do
      before do
        stub_request(:post, "https://oauth2.googleapis.com/token")
          .to_return(status: 400, body: { "error" => "invalid_grant" }.to_json)
      end

      it "raises AuthenticationError" do
        expect do
          credentials.access_token(scope: :admin)
        end.to raise_error(CloudsqlRubyConnector::AuthenticationError, /invalid_grant/)
      end
    end
  end
end
