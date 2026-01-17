# frozen_string_literal: true

require "test_helper"

class ConcurrencyTest < Minitest::Test
  include CertificateHelpers

  # Credentials thread safety tests

  def test_credentials_handle_concurrent_token_requests_safely
    test_key = CertificateHelpers.test_key
    credentials = CloudSQLRubyConnector::Credentials::ServiceAccount.new(
      "type" => "service_account",
      "private_key" => test_key.to_pem,
      "client_email" => "test@test.iam.gserviceaccount.com",
      "token_uri" => "https://oauth2.googleapis.com/token"
    )

    stub_request(:post, "https://oauth2.googleapis.com/token")
      .to_return(status: 200, body: {
        "access_token" => "token-#{rand(1000)}",
        "expires_in" => 3600
      }.to_json)

    thread_count = 10
    results = []
    mutex = Mutex.new

    threads = thread_count.times.map do
      Thread.new do
        token = credentials.access_token(scope: :admin)
        mutex.synchronize { results << token }
      end
    end

    threads.each(&:join)

    # All threads should get a token (same cached one after first request)
    assert_equal thread_count, results.size
    assert_equal thread_count, results.compact.size
  end

  def test_credentials_handle_concurrent_requests_for_different_scopes
    test_key = CertificateHelpers.test_key
    credentials = CloudSQLRubyConnector::Credentials::ServiceAccount.new(
      "type" => "service_account",
      "private_key" => test_key.to_pem,
      "client_email" => "test@test.iam.gserviceaccount.com",
      "token_uri" => "https://oauth2.googleapis.com/token"
    )

    stub_request(:post, "https://oauth2.googleapis.com/token")
      .to_return(status: 200, body: {
        "access_token" => "token-#{rand(1000)}",
        "expires_in" => 3600
      }.to_json)

    thread_count = 10
    results = { admin: [], login: [] }
    mutex = Mutex.new

    threads = thread_count.times.map do |i|
      Thread.new do
        scope = i.even? ? :admin : :login
        token = credentials.access_token(scope: scope)
        mutex.synchronize { results[scope] << token }
      end
    end

    threads.each(&:join)

    assert_equal 5, results[:admin].size
    assert_equal 5, results[:login].size
  end

  # Connector thread safety tests

  def test_connector_handles_concurrent_ip_address_calls_safely
    connector = create_mocked_connector

    thread_count = 10
    results = []
    mutex = Mutex.new

    threads = thread_count.times.map do
      Thread.new do
        ip = connector.ip_address
        mutex.synchronize { results << ip }
      end
    end

    threads.each(&:join)
    connector.close

    assert_equal thread_count, results.size
    assert_equal ["34.1.2.3"], results.uniq
  end

  def test_connector_handles_concurrent_get_options_calls_safely
    connector = create_mocked_connector

    thread_count = 10
    results = []
    mutex = Mutex.new

    threads = thread_count.times.map do
      Thread.new do
        opts = connector.get_options
        mutex.synchronize { results << opts[:ip_address] }
      end
    end

    threads.each(&:join)
    connector.close

    assert_equal thread_count, results.size
    assert_equal ["34.1.2.3"], results.uniq
  end

  def test_connector_refreshes_certificate_only_once_under_concurrent_access
    mock_fetcher = create_mock_fetcher
    connector = create_mocked_connector(fetcher: mock_fetcher)

    thread_count = 10
    threads = thread_count.times.map do
      Thread.new { connector.ip_address }
    end

    threads.each(&:join)
    connector.close

    # Should only fetch once despite concurrent requests
    assert_equal 1, mock_fetcher.fetch_metadata_call_count
    assert_equal 1, mock_fetcher.fetch_ephemeral_cert_call_count
  end

  # Connection pooling simulation tests

  def test_reuses_cached_connection_info_across_multiple_requests
    mock_fetcher = create_mock_fetcher
    connector = create_mocked_connector(fetcher: mock_fetcher)

    request_count = 10

    # Simulate pool: reuse connector for multiple requests
    request_count.times do
      connector.get_options
    end

    connector.close

    # Connection info should be fetched only once
    assert_equal 1, mock_fetcher.fetch_metadata_call_count
    assert_equal 1, mock_fetcher.fetch_ephemeral_cert_call_count
  end

  def test_handles_simulated_pool_with_concurrent_workers
    mock_fetcher = create_mock_fetcher
    connector = create_mocked_connector(fetcher: mock_fetcher)

    pool_size = 3
    request_count = 10
    completed = 0
    completed_mutex = Mutex.new

    # Simulate workers from a pool making requests
    semaphore = Mutex.new
    active_workers = 0

    threads = request_count.times.map do
      Thread.new do
        semaphore.synchronize do
          active_workers += 1
          # Simulate pool limit
          sleep 0.01 while active_workers > pool_size
        end

        connector.get_options
        completed_mutex.synchronize { completed += 1 }

        semaphore.synchronize { active_workers -= 1 }
      end
    end

    threads.each(&:join)
    connector.close

    assert_equal request_count, completed
  end

  private

  def create_mocked_connector(fetcher: nil)
    mock_credentials = MockCredentials.new
    connector = CloudSQLRubyConnector::PostgreSQL::Connector.new(
      "project:region:instance",
      credentials: mock_credentials
    )

    fetcher ||= create_mock_fetcher
    connector.instance_variable_set(:@fetcher, fetcher)

    connector
  end

  def create_mock_fetcher
    MockFetcher.new(generate_test_cert)
  end

  # Thread-safe mock fetcher for concurrency tests
  class MockFetcher
    attr_reader :fetch_metadata_call_count, :fetch_ephemeral_cert_call_count

    def initialize(test_cert)
      @test_cert = test_cert
      @fetch_metadata_call_count = 0
      @fetch_ephemeral_cert_call_count = 0
      @mutex = Mutex.new
    end

    def fetch_metadata(**)
      @mutex.synchronize { @fetch_metadata_call_count += 1 }
      {
        ip_addresses: { "PRIMARY" => "34.1.2.3", "PRIVATE" => "10.0.0.5" },
        server_ca_cert: @test_cert.to_pem,
        database_version: "POSTGRES_15"
      }
    end

    def fetch_ephemeral_cert(**)
      @mutex.synchronize { @fetch_ephemeral_cert_call_count += 1 }
      {
        cert: @test_cert.to_pem,
        expiration: Time.now + 3600
      }
    end
  end
end
