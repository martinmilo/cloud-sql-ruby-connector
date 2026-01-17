# frozen_string_literal: true

require "test_helper"

module CloudSQLRubyConnector
  module PostgreSQL
    class ConnectorTest < Minitest::Test
      include CertificateHelpers

      # Initialize tests

      def test_parses_instance_connection_name
        connector = Connector.new("my-project:us-central1:my-instance")

        assert_equal "my-project", connector.project
        assert_equal "us-central1", connector.region
        assert_equal "my-instance", connector.instance_name
      end

      def test_raises_for_invalid_connection_name
        error = assert_raises(CloudSQLRubyConnector::ConfigurationError) do
          Connector.new("invalid-name")
        end
        assert_match(/Invalid instance connection name/, error.message)
      end

      def test_raises_for_empty_connection_name
        error = assert_raises(CloudSQLRubyConnector::ConfigurationError) do
          Connector.new("")
        end
        assert_match(/Invalid instance connection name/, error.message)
      end

      def test_raises_for_connection_name_with_too_many_parts
        error = assert_raises(CloudSQLRubyConnector::ConfigurationError) do
          Connector.new("a:b:c:d")
        end
        assert_match(/Invalid instance connection name/, error.message)
      end

      def test_defaults_to_public_ip_type
        connector = Connector.new("p:r:i")

        assert_equal "PUBLIC", connector.ip_type
      end

      def test_defaults_to_password_auth_type
        connector = Connector.new("p:r:i")

        assert_equal "PASSWORD", connector.auth_type
      end

      def test_accepts_custom_ip_type
        connector = Connector.new("p:r:i", ip_type: "PRIVATE")

        assert_equal "PRIVATE", connector.ip_type
      end

      def test_accepts_custom_auth_type
        connector = Connector.new("p:r:i", auth_type: "IAM")

        assert_equal "IAM", connector.auth_type
      end

      def test_normalizes_ip_type_from_symbol
        connector = Connector.new("p:r:i", ip_type: :private)

        assert_equal "PRIVATE", connector.ip_type
      end

      def test_normalizes_auth_type_from_symbol
        connector = Connector.new("p:r:i", auth_type: :iam)

        assert_equal "IAM", connector.auth_type
      end

      def test_normalizes_ip_type_from_lowercase_string
        connector = Connector.new("p:r:i", ip_type: "private")

        assert_equal "PRIVATE", connector.ip_type
      end

      def test_accepts_psc_ip_type
        connector = Connector.new("p:r:i", ip_type: "PSC")

        assert_equal "PSC", connector.ip_type
      end

      def test_accepts_custom_credentials
        mock_creds = MockCredentials.new
        connector = Connector.new("p:r:i", credentials: mock_creds)

        assert_equal mock_creds, connector.instance_variable_get(:@credentials)
      end

      # Close tests

      def test_close_can_be_called_multiple_times
        connector = Connector.new("p:r:i")

        connector.close
        connector.close # Should not raise
      end

      def test_close_clears_cached_connection_info
        connector = Connector.new("p:r:i")
        connector.instance_variable_set(:@cached_info, { test: "data" })

        connector.close

        assert_nil connector.instance_variable_get(:@cached_info)
      end

      # IP address tests

      def test_ip_address_returns_ip_for_configured_type
        connector = create_mocked_connector

        assert_equal "34.1.2.3", connector.ip_address
      end

      def test_ip_address_returns_private_ip_when_configured
        connector = create_mocked_connector(ip_type: "PRIVATE")

        assert_equal "10.0.0.5", connector.ip_address
      end

      def test_ip_address_raises_when_ip_type_not_available
        connector = create_mocked_connector(ip_type: "PSC")

        error = assert_raises(CloudSQLRubyConnector::IpAddressError) do
          connector.ip_address
        end
        assert_match(/PSC IP address not found/, error.message)
      end

      # Get options tests

      def test_get_options_returns_connection_options_hash
        connector = create_mocked_connector
        options = connector.get_options

        assert_includes options.keys, :stream
        assert_includes options.keys, :ip_address
        assert_includes options.keys, :server_ca_cert
        assert_includes options.keys, :client_cert
        assert_includes options.keys, :private_key
        assert_equal "34.1.2.3", options[:ip_address]
        assert_instance_of Proc, options[:stream]
      end

      # Certificate caching tests

      def test_caches_connection_info
        mock_fetcher = create_mock_fetcher
        connector = create_mocked_connector(fetcher: mock_fetcher)

        connector.ip_address
        connector.ip_address

        assert_equal 1, mock_fetcher.fetch_metadata_call_count
        assert_equal 1, mock_fetcher.fetch_ephemeral_cert_call_count
      end

      def test_refreshes_when_certificate_expires
        mock_fetcher = create_mock_fetcher
        connector = create_mocked_connector(fetcher: mock_fetcher)

        connector.ip_address

        # Simulate time passing - cert now expires in 4 minutes (less than 5 min buffer)
        connector.instance_variable_set(:@cert_expiration, Time.now + 240)

        connector.ip_address

        assert_equal 2, mock_fetcher.fetch_metadata_call_count
      end

      # IAM user formatting tests

      def test_strips_gserviceaccount_suffix
        connector = Connector.new("p:r:i", auth_type: "IAM")
        formatted = connector.send(:format_iam_user, "sa@project.iam.gserviceaccount.com")

        assert_equal "sa@project.iam", formatted
      end

      def test_preserves_user_without_suffix
        connector = Connector.new("p:r:i", auth_type: "IAM")
        formatted = connector.send(:format_iam_user, "user@example.com")

        assert_equal "user@example.com", formatted
      end

      private

      def create_mocked_connector(ip_type: "PUBLIC", fetcher: nil)
        mock_credentials = MockCredentials.new
        connector = Connector.new(
          "project:region:instance",
          credentials: mock_credentials,
          ip_type: ip_type
        )

        fetcher ||= create_mock_fetcher
        CloudSQLRubyConnector::SQLAdminFetcher.stub :new, fetcher do
          connector.instance_variable_set(:@fetcher, fetcher)
        end

        connector
      end

      def create_mock_fetcher
        MockFetcher.new(generate_test_cert)
      end

      # Mock fetcher class for testing
      class MockFetcher
        attr_reader :fetch_metadata_call_count, :fetch_ephemeral_cert_call_count

        def initialize(test_cert)
          @test_cert = test_cert
          @fetch_metadata_call_count = 0
          @fetch_ephemeral_cert_call_count = 0
        end

        def fetch_metadata(**)
          @fetch_metadata_call_count += 1
          {
            ip_addresses: { "PRIMARY" => "34.1.2.3", "PRIVATE" => "10.0.0.5" },
            server_ca_cert: @test_cert.to_pem,
            database_version: "POSTGRES_15"
          }
        end

        def fetch_ephemeral_cert(**)
          @fetch_ephemeral_cert_call_count += 1
          {
            cert: @test_cert.to_pem,
            expiration: Time.now + 3600
          }
        end
      end
    end
  end
end
