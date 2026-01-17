# frozen_string_literal: true

require "test_helper"

class MetadataCredentialsTest < Minitest::Test
  def setup
    @credentials = CloudSQLRubyConnector::Credentials::Metadata.new
  end

  def test_access_token_fetches_token_from_metadata_server
    stub_metadata_request

    token = @credentials.access_token(scope: :admin)

    assert_equal "ya29.metadata-token", token
  end

  def test_access_token_includes_metadata_flavor_header
    stub_metadata_request

    @credentials.access_token(scope: :admin)

    assert_requested :get, /169\.254\.169\.254/ do |req|
      req.headers["Metadata-Flavor"] == "Google"
    end
  end

  def test_access_token_includes_scope_in_request
    stub_metadata_request

    @credentials.access_token(scope: :admin)

    assert_requested :get, /scopes=https.*sqlservice\.admin/
  end

  def test_access_token_raises_authentication_error_when_not_on_gce
    stub_request(:get, /169\.254\.169\.254/).to_timeout

    error = assert_raises(CloudSQLRubyConnector::AuthenticationError) do
      @credentials.access_token(scope: :admin)
    end
    assert_match(/Not running on GCE/, error.message)
  end

  def test_access_token_raises_authentication_error_on_metadata_server_error
    stub_request(:get, /169\.254\.169\.254/)
      .to_return(status: 404, body: { "error" => "not_found" }.to_json)

    error = assert_raises(CloudSQLRubyConnector::AuthenticationError) do
      @credentials.access_token(scope: :admin)
    end
    assert_match(/Failed to get metadata token/, error.message)
  end

  private

  def stub_metadata_request
    stub_request(:get, /169\.254\.169\.254.*token/)
      .with(headers: { "Metadata-Flavor" => "Google" })
      .to_return(
        status: 200,
        body: {
          "access_token" => "ya29.metadata-token",
          "expires_in" => 3600,
          "token_type" => "Bearer"
        }.to_json
      )
  end
end
