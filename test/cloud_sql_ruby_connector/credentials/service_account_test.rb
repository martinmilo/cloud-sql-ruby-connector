# frozen_string_literal: true

require "test_helper"

class ServiceAccountTest < Minitest::Test
  include FixtureHelpers

  def setup
    @test_key = CertificateHelpers.test_key
    @service_account_data = {
      "type" => "service_account",
      "project_id" => "test-project",
      "private_key_id" => "key123",
      "private_key" => @test_key.to_pem,
      "client_email" => "test@test-project.iam.gserviceaccount.com",
      "client_id" => "123456789",
      "token_uri" => "https://oauth2.googleapis.com/token"
    }
    @credentials = CloudSQLRubyConnector::Credentials::ServiceAccount.new(@service_account_data)
  end

  def test_from_file_returns_user_credentials_for_authorized_user_type
    creds = CloudSQLRubyConnector::Credentials::ServiceAccount.from_file(fixture_path("user_credentials.json"))

    assert_instance_of CloudSQLRubyConnector::Credentials::UserCredentials, creds
  end

  def test_raises_configuration_error_when_client_email_missing
    data = @service_account_data.dup
    data.delete("client_email")

    error = assert_raises(CloudSQLRubyConnector::ConfigurationError) do
      CloudSQLRubyConnector::Credentials::ServiceAccount.new(data)
    end
    assert_match(/client_email/, error.message)
  end

  def test_raises_configuration_error_when_private_key_missing
    data = @service_account_data.dup
    data.delete("private_key")

    error = assert_raises(CloudSQLRubyConnector::ConfigurationError) do
      CloudSQLRubyConnector::Credentials::ServiceAccount.new(data)
    end
    assert_match(/private_key/, error.message)
  end

  def test_from_file_raises_for_nonexistent_file
    assert_raises(Errno::ENOENT) do
      CloudSQLRubyConnector::Credentials::ServiceAccount.from_file("/nonexistent/path.json")
    end
  end

  def test_access_token_fetches_token
    stub_token_request

    token = @credentials.access_token(scope: :admin)

    assert_equal "ya29.test-token", token
  end

  def test_access_token_caches_token
    stub_token_request

    @credentials.access_token(scope: :admin)
    @credentials.access_token(scope: :admin)

    assert_requested :post, "https://oauth2.googleapis.com/token", times: 1
  end

  def test_access_token_fetches_separate_tokens_for_different_scopes
    stub_token_request

    @credentials.access_token(scope: :admin)
    @credentials.access_token(scope: :login)

    assert_requested :post, "https://oauth2.googleapis.com/token", times: 2
  end

  def test_access_token_sends_jwt_assertion
    stub_token_request

    @credentials.access_token(scope: :admin)

    assert_requested :post, "https://oauth2.googleapis.com/token" do |req|
      req.body.include?("grant_type=urn") && req.body.include?("assertion=")
    end
  end

  def test_access_token_raises_authentication_error_on_failure
    stub_request(:post, "https://oauth2.googleapis.com/token")
      .to_return(
        status: 401,
        body: { "error" => "invalid_grant", "error_description" => "Token expired" }.to_json
      )

    error = assert_raises(CloudSQLRubyConnector::AuthenticationError) do
      @credentials.access_token(scope: :admin)
    end
    assert_match(/Token expired/, error.message)
  end

  def test_access_token_raises_authentication_error_on_timeout
    stub_request(:post, "https://oauth2.googleapis.com/token").to_timeout

    error = assert_raises(CloudSQLRubyConnector::AuthenticationError) do
      @credentials.access_token(scope: :admin)
    end
    assert_match(/timed out/, error.message)
  end

  private

  def stub_token_request
    stub_request(:post, "https://oauth2.googleapis.com/token")
      .to_return(
        status: 200,
        body: {
          "access_token" => "ya29.test-token",
          "expires_in" => 3600,
          "token_type" => "Bearer"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end
end
