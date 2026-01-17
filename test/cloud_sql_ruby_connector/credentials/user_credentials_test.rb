# frozen_string_literal: true

require "test_helper"

class UserCredentialsTest < Minitest::Test
  include FixtureHelpers

  def setup
    @user_credentials_data = fixture_json("user_credentials.json")
    @credentials = CloudSQLRubyConnector::Credentials::UserCredentials.new(@user_credentials_data)
  end

  def test_access_token_fetches_token_using_refresh_token
    stub_token_request

    token = @credentials.access_token(scope: :admin)

    assert_equal "ya29.user-token", token
  end

  def test_raises_configuration_error_when_client_id_missing
    data = @user_credentials_data.dup
    data.delete("client_id")

    error = assert_raises(CloudSQLRubyConnector::ConfigurationError) do
      CloudSQLRubyConnector::Credentials::UserCredentials.new(data)
    end
    assert_match(/client_id/, error.message)
  end

  def test_raises_configuration_error_when_client_secret_missing
    data = @user_credentials_data.dup
    data.delete("client_secret")

    error = assert_raises(CloudSQLRubyConnector::ConfigurationError) do
      CloudSQLRubyConnector::Credentials::UserCredentials.new(data)
    end
    assert_match(/client_secret/, error.message)
  end

  def test_raises_configuration_error_when_refresh_token_missing
    data = @user_credentials_data.dup
    data.delete("refresh_token")

    error = assert_raises(CloudSQLRubyConnector::ConfigurationError) do
      CloudSQLRubyConnector::Credentials::UserCredentials.new(data)
    end
    assert_match(/refresh_token/, error.message)
  end

  def test_access_token_sends_refresh_token_in_request
    stub_token_request

    @credentials.access_token(scope: :admin)

    assert_requested :post, "https://oauth2.googleapis.com/token" do |req|
      body = URI.decode_www_form(req.body).to_h
      body["grant_type"] == "refresh_token" &&
        body["refresh_token"] == "test-refresh-token" &&
        body["client_id"] == "123456789.apps.googleusercontent.com" &&
        body["client_secret"] == "test-client-secret"
    end
  end

  def test_access_token_caches_token
    stub_token_request

    @credentials.access_token(scope: :admin)
    @credentials.access_token(scope: :admin)

    assert_requested :post, "https://oauth2.googleapis.com/token", times: 1
  end

  def test_access_token_raises_authentication_error_on_refresh_failure
    stub_request(:post, "https://oauth2.googleapis.com/token")
      .to_return(status: 400, body: { "error" => "invalid_grant" }.to_json)

    error = assert_raises(CloudSQLRubyConnector::AuthenticationError) do
      @credentials.access_token(scope: :admin)
    end
    assert_match(/invalid_grant/, error.message)
  end

  private

  def stub_token_request
    stub_request(:post, "https://oauth2.googleapis.com/token")
      .to_return(
        status: 200,
        body: {
          "access_token" => "ya29.user-token",
          "expires_in" => 3600,
          "token_type" => "Bearer"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end
end
