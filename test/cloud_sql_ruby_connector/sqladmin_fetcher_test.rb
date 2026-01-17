# frozen_string_literal: true

require "test_helper"

class SQLAdminFetcherTest < Minitest::Test
  include CertificateHelpers

  def setup
    @mock_credentials = MockCredentials.new
    @fetcher = CloudSQLRubyConnector::SQLAdminFetcher.new(credentials: @mock_credentials)
    @api_url = "https://sqladmin.googleapis.com/sql/v1beta4/projects/my-project/instances/my-instance/connectSettings"
    @test_cert = generate_test_cert
  end

  # fetch_metadata tests

  def test_fetch_metadata_returns_instance_metadata
    stub_metadata_request

    result = @fetcher.fetch_metadata(project: "my-project", region: "us-central1", instance: "my-instance")

    assert_equal({ "PRIMARY" => "34.1.2.3", "PRIVATE" => "10.0.0.5" }, result[:ip_addresses])
    assert_includes result[:server_ca_cert], "BEGIN CERTIFICATE"
    assert_equal "POSTGRES_15", result[:database_version]
  end

  def test_fetch_metadata_raises_on_region_mismatch
    stub_metadata_request

    error = assert_raises(CloudSQLRubyConnector::ConfigurationError) do
      @fetcher.fetch_metadata(project: "my-project", region: "europe-west1", instance: "my-instance")
    end
    assert_match(/Region mismatch/, error.message)
  end

  def test_fetch_metadata_extracts_psc_dns_name
    stub_request(:get, @api_url)
      .to_return(status: 200, body: metadata_response.merge(
        "dnsNames" => [
          { "connectionType" => "PRIVATE_SERVICE_CONNECT", "dnsScope" => "INSTANCE", "name" => "abc123.xyz.sql.goog" }
        ]
      ).to_json)

    result = @fetcher.fetch_metadata(project: "my-project", region: "us-central1", instance: "my-instance")

    assert_equal "abc123.xyz.sql.goog", result[:ip_addresses]["PSC"]
  end

  def test_fetch_metadata_falls_back_to_legacy_dns_name
    stub_request(:get, @api_url)
      .to_return(status: 200, body: metadata_response.merge(
        "pscEnabled" => true,
        "dnsName" => "legacy.sql.goog"
      ).to_json)

    result = @fetcher.fetch_metadata(project: "my-project", region: "us-central1", instance: "my-instance")

    assert_equal "legacy.sql.goog", result[:ip_addresses]["PSC"]
  end

  def test_fetch_metadata_raises_connection_error_on_api_error
    stub_request(:get, @api_url)
      .to_return(status: 404, body: { "error" => { "message" => "Instance not found" } }.to_json)

    error = assert_raises(CloudSQLRubyConnector::ConnectionError) do
      @fetcher.fetch_metadata(project: "my-project", region: "us-central1", instance: "my-instance")
    end
    assert_match(/Instance not found/, error.message)
  end

  def test_fetch_metadata_raises_connection_error_when_no_ca_cert
    stub_request(:get, @api_url)
      .to_return(status: 200, body: metadata_response.merge("serverCaCert" => nil).to_json)

    error = assert_raises(CloudSQLRubyConnector::ConnectionError) do
      @fetcher.fetch_metadata(project: "my-project", region: "us-central1", instance: "my-instance")
    end
    assert_match(/No valid CA certificate/, error.message)
  end

  def test_fetch_metadata_raises_connection_error_on_timeout
    stub_request(:get, @api_url).to_timeout

    error = assert_raises(CloudSQLRubyConnector::ConnectionError) do
      @fetcher.fetch_metadata(project: "my-project", region: "us-central1", instance: "my-instance")
    end
    assert_match(/timed out/, error.message)
  end

  # fetch_ephemeral_cert tests

  def test_fetch_ephemeral_cert_for_password_auth
    stub_cert_request

    result = @fetcher.fetch_ephemeral_cert(
      project: "my-project",
      instance: "my-instance",
      public_key: "-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----",
      auth_type: CloudSQLRubyConnector::AuthTypes::PASSWORD
    )

    assert_includes result[:cert], "BEGIN CERTIFICATE"
    assert_instance_of Time, result[:expiration]
  end

  def test_fetch_ephemeral_cert_includes_login_token_for_iam_auth
    stub_cert_request

    @fetcher.fetch_ephemeral_cert(
      project: "my-project",
      instance: "my-instance",
      public_key: "public-key-pem",
      auth_type: CloudSQLRubyConnector::AuthTypes::IAM
    )

    assert_requested :post, cert_api_url do |req|
      body = JSON.parse(req.body)
      body["access_token"] == "login-token"
    end
  end

  def test_fetch_ephemeral_cert_raises_connection_error_on_api_error
    stub_request(:post, cert_api_url)
      .to_return(status: 403, body: { "error" => { "message" => "Permission denied" } }.to_json)

    error = assert_raises(CloudSQLRubyConnector::ConnectionError) do
      @fetcher.fetch_ephemeral_cert(
        project: "my-project",
        instance: "my-instance",
        public_key: "key",
        auth_type: CloudSQLRubyConnector::AuthTypes::PASSWORD
      )
    end
    assert_match(/Permission denied/, error.message)
  end

  def test_fetch_ephemeral_cert_raises_connection_error_when_cert_missing
    stub_request(:post, cert_api_url)
      .to_return(status: 200, body: { "ephemeralCert" => {} }.to_json)

    error = assert_raises(CloudSQLRubyConnector::ConnectionError) do
      @fetcher.fetch_ephemeral_cert(
        project: "my-project",
        instance: "my-instance",
        public_key: "key",
        auth_type: CloudSQLRubyConnector::AuthTypes::PASSWORD
      )
    end
    assert_match(/Failed to retrieve ephemeral certificate/, error.message)
  end

  # Custom API endpoint test

  def test_uses_custom_api_endpoint
    custom_fetcher = CloudSQLRubyConnector::SQLAdminFetcher.new(
      credentials: @mock_credentials,
      api_endpoint: "https://custom.api.com"
    )

    stub_request(:get, "https://custom.api.com/sql/v1beta4/projects/p/instances/i/connectSettings")
      .to_return(status: 200, body: {
        "region" => "r",
        "ipAddresses" => [],
        "serverCaCert" => { "cert" => "cert" }
      }.to_json)

    custom_fetcher.fetch_metadata(project: "p", region: "r", instance: "i")

    assert_requested :get, /custom\.api\.com/
  end

  private

  def metadata_response
    {
      "kind" => "sql#connectSettings",
      "region" => "us-central1",
      "databaseVersion" => "POSTGRES_15",
      "ipAddresses" => [
        { "type" => "PRIMARY", "ipAddress" => "34.1.2.3" },
        { "type" => "PRIVATE", "ipAddress" => "10.0.0.5" }
      ],
      "serverCaCert" => {
        "cert" => "-----BEGIN CERTIFICATE-----\nMIIC...\n-----END CERTIFICATE-----"
      }
    }
  end

  def cert_api_url
    "https://sqladmin.googleapis.com/sql/v1beta4/projects/my-project/instances/my-instance:generateEphemeralCert"
  end

  def stub_metadata_request
    stub_request(:get, @api_url)
      .with(headers: { "Authorization" => "Bearer admin-token" })
      .to_return(status: 200, body: metadata_response.to_json)
  end

  def stub_cert_request
    stub_request(:post, cert_api_url)
      .with(headers: { "Authorization" => "Bearer admin-token" })
      .to_return(status: 200, body: {
        "ephemeralCert" => { "cert" => @test_cert.to_pem }
      }.to_json)
  end
end
