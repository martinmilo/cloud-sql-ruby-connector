# frozen_string_literal: true

# Copyright 2024 Martin Milo
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "socket"

module CloudsqlRubyConnector
  # Local TCP proxy that bridges pg (plain) to Cloud SQL (SSL)
  #
  # This proxy is necessary because Cloud SQL requires direct TLS connections,
  # but libpq (PostgreSQL client) sends an SSLRequest message first, which
  # Cloud SQL doesn't understand. The proxy accepts plain TCP connections
  # locally and forwards them over the pre-established SSL connection.
  class SslProxy
    attr_reader :port

    def initialize(ssl_socket)
      @ssl_socket = ssl_socket
      @server = TCPServer.new("127.0.0.1", 0) # Port 0 = kernel assigns available port
      @port = @server.addr[1]
      @running = false
      @threads = []
      @mutex = Mutex.new
    end

    # Start the proxy server in a background thread
    def start
      @running = true
      @accept_thread = Thread.new { accept_loop }
    end

    # Stop the proxy server and clean up resources
    def stop
      @mutex.synchronize do
        @running = false
        @threads.each { |t| t.kill if t.alive? }
        begin
          @server.close
        rescue StandardError
          nil
        end
        begin
          @ssl_socket.close
        rescue StandardError
          nil
        end
      end
    end

    private

    def accept_loop
      client = @server.accept
      @server.close # Close listener immediately - we only need one client

      @mutex.synchronize do
        @threads << Thread.new { forward(client, @ssl_socket) }
        @threads << Thread.new { forward(@ssl_socket, client) }
      end
    rescue IOError
      # Server closed
    end

    def forward(from, to)
      while @running
        data = from.readpartial(16_384)
        to.write(data)
      end
    rescue EOFError, IOError, Errno::ECONNRESET, Errno::EPIPE
      # Close the other side to unblock the paired thread
      begin
        to.close
      rescue StandardError
        nil
      end
    end
  end
end
