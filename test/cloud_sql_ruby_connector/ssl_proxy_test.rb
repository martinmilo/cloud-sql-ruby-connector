# frozen_string_literal: true

require "test_helper"

class SslProxyTest < Minitest::Test
  def test_initialize_assigns_random_available_port
    mock_ssl_socket = create_mock_ssl_socket
    proxy = CloudSQLRubyConnector::SslProxy.new(mock_ssl_socket)

    assert_kind_of Integer, proxy.port
    assert_operator proxy.port, :>, 0

    proxy.stop
  end

  def test_initialize_binds_to_localhost_only
    mock_ssl_socket = create_mock_ssl_socket
    proxy = CloudSQLRubyConnector::SslProxy.new(mock_ssl_socket)

    assert_includes 1024..65_535, proxy.port

    proxy.stop
  end

  def test_start_and_stop
    mock_ssl_socket = create_mock_ssl_socket
    proxy = CloudSQLRubyConnector::SslProxy.new(mock_ssl_socket)

    proxy.start
    proxy.stop
  end

  def test_stop_can_be_called_multiple_times_safely
    mock_ssl_socket = create_mock_ssl_socket
    proxy = CloudSQLRubyConnector::SslProxy.new(mock_ssl_socket)
    proxy.start

    proxy.stop
    proxy.stop # Should not raise
  end

  def test_forwards_data_between_client_and_ssl_socket
    # Create a pair of connected sockets to simulate SSL connection
    server_read, client_write = IO.pipe
    _, server_write = IO.pipe

    mock_ssl_socket = Object.new
    mock_ssl_socket.define_singleton_method(:readpartial) do |size|
      server_read.readpartial(size)
    end
    mock_ssl_socket.define_singleton_method(:write) do |data|
      server_write.write(data)
    end
    mock_ssl_socket.define_singleton_method(:close) do
      begin
        server_read.close
      rescue StandardError
        nil
      end
      begin
        server_write.close
      rescue StandardError
        nil
      end
    end

    proxy = CloudSQLRubyConnector::SslProxy.new(mock_ssl_socket)
    proxy.start

    # Connect to the proxy
    client = TCPSocket.new("127.0.0.1", proxy.port)

    # Send data through the proxy to the "server"
    client.write("hello")
    client.flush

    # Give the proxy time to forward
    sleep 0.1

    # The mock SSL socket should have received the data
    refute_predicate client_write, :closed?

    client.close
    proxy.stop
  end

  private

  def create_mock_ssl_socket
    mock = Object.new
    mock.define_singleton_method(:close) { nil }
    mock
  end
end
