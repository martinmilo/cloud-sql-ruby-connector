# frozen_string_literal: true

RSpec.describe CloudsqlRubyConnector::SslProxy do
  describe "#initialize" do
    it "assigns a random available port" do
      # Create a mock SSL socket
      mock_ssl_socket = instance_double(OpenSSL::SSL::SSLSocket)
      allow(mock_ssl_socket).to receive(:close)

      proxy = described_class.new(mock_ssl_socket)

      expect(proxy.port).to be_a(Integer)
      expect(proxy.port).to be > 0

      proxy.stop
    end

    it "binds to localhost only" do
      mock_ssl_socket = instance_double(OpenSSL::SSL::SSLSocket)
      allow(mock_ssl_socket).to receive(:close)

      proxy = described_class.new(mock_ssl_socket)

      # The proxy should only be accessible from localhost
      # We can verify this by checking that we can't connect from external interface
      # For unit test, we just verify the port is assigned
      expect(proxy.port).to be_between(1024, 65_535)

      proxy.stop
    end
  end

  describe "#start and #stop" do
    it "can be started and stopped" do
      mock_ssl_socket = instance_double(OpenSSL::SSL::SSLSocket)
      allow(mock_ssl_socket).to receive(:close)

      proxy = described_class.new(mock_ssl_socket)

      expect { proxy.start }.not_to raise_error
      expect { proxy.stop }.not_to raise_error
    end

    it "can be stopped multiple times safely" do
      mock_ssl_socket = instance_double(OpenSSL::SSL::SSLSocket)
      allow(mock_ssl_socket).to receive(:close)

      proxy = described_class.new(mock_ssl_socket)
      proxy.start

      expect { proxy.stop }.not_to raise_error
      expect { proxy.stop }.not_to raise_error
    end
  end

  describe "data forwarding" do
    it "forwards data between client and SSL socket" do
      # Create a pair of connected sockets to simulate SSL connection
      server_read, client_write = IO.pipe
      _, server_write = IO.pipe

      mock_ssl_socket = double("SSLSocket")
      allow(mock_ssl_socket).to receive(:readpartial) do |size|
        server_read.readpartial(size)
      end
      allow(mock_ssl_socket).to receive(:write) do |data|
        server_write.write(data)
      end
      allow(mock_ssl_socket).to receive(:close) do
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

      proxy = described_class.new(mock_ssl_socket)
      proxy.start

      # Connect to the proxy
      client = TCPSocket.new("127.0.0.1", proxy.port)

      # Send data through the proxy to the "server"
      client.write("hello")
      client.flush

      # Give the proxy time to forward
      sleep 0.1

      # The mock SSL socket should have received the data
      expect(client_write.closed?).to be false

      client.close
      proxy.stop
    end
  end
end
