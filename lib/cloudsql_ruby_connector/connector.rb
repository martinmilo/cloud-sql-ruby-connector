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

require "openssl"
require "socket"

module CloudsqlRubyConnector
  # Main connector class for Cloud SQL connections
  #
  # @example Basic usage with PostgreSQL
  #   connector = CloudsqlRubyConnector::Connector.new("my-project:us-central1:my-instance")
  #   conn = connector.connect(user: "myuser", password: "mypass", dbname: "mydb")
  #   result = conn.exec("SELECT NOW()")
  #   conn.close
  #   connector.close
  #
  # @example Using IAM authentication
  #   connector = CloudsqlRubyConnector::Connector.new(
  #     "my-project:us-central1:my-instance",
  #     auth_type: CloudsqlRubyConnector::AuthTypes::IAM
  #   )
  #   conn = connector.connect(user: "sa@project.iam", dbname: "mydb")
  #
  class Connector
    CLOUD_SQL_PORT = 3307
    CERT_REFRESH_BUFFER = 300 # Refresh certificate 5 minutes before expiration

    attr_reader :project, :region, :instance_name, :ip_type, :auth_type

    # Initialize a new connector
    #
    # @param instance_connection_name [String] Cloud SQL instance connection name (PROJECT:REGION:INSTANCE)
    # @param credentials [Credentials::Base] Optional credentials object
    # @param ip_type [String] IP address type: PUBLIC, PRIVATE, or PSC (default: PUBLIC)
    # @param auth_type [String] Authentication type: PASSWORD or IAM (default: PASSWORD)
    # @param api_endpoint [String] Optional custom API endpoint
    def initialize(instance_connection_name, credentials: nil, ip_type: IpAddressTypes::PUBLIC,
                   auth_type: AuthTypes::PASSWORD, api_endpoint: nil)
      @project, @region, @instance_name = parse_connection_name(instance_connection_name)
      @ip_type = IpAddressTypes.normalize(ip_type)
      @auth_type = AuthTypes.normalize(auth_type)
      @credentials = credentials || default_credentials
      @api_endpoint = api_endpoint

      # Generate RSA key pair once per connector instance
      @private_key, @public_key = generate_keys

      # Certificate cache with expiration tracking
      @cached_info = nil
      @cert_expiration = Time.at(0)
      @lock = Mutex.new

      # SQL Admin API fetcher
      @fetcher = SqlAdminFetcher.new(credentials: @credentials, api_endpoint: @api_endpoint)

      # Track active proxies for cleanup
      @proxies = []
    end

    # Create a connected PG::Connection
    #
    # @param user [String] Database username
    # @param password [String] Database password (optional for IAM auth)
    # @param dbname [String] Database name
    # @param extra_options [Hash] Additional options to pass to PG.connect
    # @return [PG::Connection] Connected PostgreSQL connection
    def connect(user:, dbname:, password: nil, **extra_options)
      require "pg"

      conn_info = ensure_valid_connection_info!

      effective_user = @auth_type == AuthTypes::IAM ? format_iam_user(user) : user
      effective_password = @auth_type == AuthTypes::IAM ? @credentials.access_token(scope: :login) : password

      ssl_socket = create_ssl_connection(conn_info)
      proxy = SslProxy.new(ssl_socket)
      proxy.start
      @lock.synchronize { @proxies << proxy }

      begin
        PG.connect(
          host: "127.0.0.1",
          port: proxy.port,
          user: effective_user,
          password: effective_password,
          dbname: dbname,
          sslmode: "disable",
          **extra_options
        )
      rescue StandardError => e
        proxy.stop
        raise e
      end
    end

    # Get connection options that can be used with PG.connect
    # This is an alternative to using #connect directly
    #
    # @return [Hash] Connection options including :stream proc
    def get_options
      conn_info = ensure_valid_connection_info!

      {
        stream: -> { create_ssl_connection(conn_info) },
        ip_address: conn_info[:ip_address],
        server_ca_cert: conn_info[:server_ca_cert],
        client_cert: conn_info[:client_cert],
        private_key: conn_info[:private_key]
      }
    end

    # Get the IP address for the instance
    #
    # @return [String] IP address
    def ip_address
      ensure_valid_connection_info![:ip_address]
    end

    # Close the connector and clean up resources
    def close
      @lock.synchronize do
        @proxies.each(&:stop)
        @proxies.clear
        @cached_info = nil
      end
    end

    private

    def parse_connection_name(name)
      parts = name.to_s.split(":")
      unless parts.length == 3
        raise ConfigurationError, "Invalid instance connection name '#{name}'. Expected format: PROJECT:REGION:INSTANCE"
      end

      parts
    end

    def generate_keys
      key = OpenSSL::PKey::RSA.new(2048)
      [key.to_pem, key.public_key.to_pem]
    end

    def default_credentials
      if ENV["GOOGLE_APPLICATION_CREDENTIALS"]
        return Credentials::ServiceAccount.from_file(ENV["GOOGLE_APPLICATION_CREDENTIALS"])
      end

      gcloud_path = File.expand_path("~/.config/gcloud/application_default_credentials.json")
      return Credentials::ServiceAccount.from_file(gcloud_path) if File.exist?(gcloud_path)

      Credentials::Metadata.new
    rescue JSON::ParserError => e
      raise ConfigurationError, "Invalid credentials file: #{e.message}"
    end

    def ensure_valid_connection_info!
      @lock.synchronize do
        refresh_connection_info! if @cached_info.nil? || Time.now > (@cert_expiration - CERT_REFRESH_BUFFER)
        @cached_info
      end
    end

    def refresh_connection_info!
      metadata = @fetcher.fetch_metadata(
        project: @project,
        region: @region,
        instance: @instance_name
      )

      cert_data = @fetcher.fetch_ephemeral_cert(
        project: @project,
        instance: @instance_name,
        public_key: @public_key,
        auth_type: @auth_type
      )

      ip_address = select_ip_address(metadata[:ip_addresses])

      @cert_expiration = cert_data[:expiration]
      @cached_info = {
        ip_address: ip_address,
        server_ca_cert: metadata[:server_ca_cert],
        client_cert: cert_data[:cert],
        private_key: @private_key
      }
    end

    def select_ip_address(ip_addresses)
      api_key = IpAddressTypes.api_key(@ip_type)
      ip = ip_addresses[api_key]

      unless ip
        raise IpAddressError.new(
          "Cannot connect to instance, #{@ip_type} IP address not found",
          code: "ENO#{@ip_type}IPADDRESS"
        )
      end

      ip
    end

    def format_iam_user(user)
      suffix = ".gserviceaccount.com"
      user.end_with?(suffix) ? user[0...-suffix.length] : user
    end

    def create_ssl_connection(conn_info)
      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_context.min_version = OpenSSL::SSL::TLS1_3_VERSION
      ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER

      ssl_context.cert = OpenSSL::X509::Certificate.new(conn_info[:client_cert])
      ssl_context.key = OpenSSL::PKey::RSA.new(conn_info[:private_key])
      ssl_context.cert_store = OpenSSL::X509::Store.new
      ssl_context.cert_store.add_cert(OpenSSL::X509::Certificate.new(conn_info[:server_ca_cert]))

      tcp_socket = Socket.tcp(conn_info[:ip_address], CLOUD_SQL_PORT, connect_timeout: 30)

      ssl_socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, ssl_context)
      ssl_socket.sync_close = true
      ssl_socket.connect

      ssl_socket
    rescue Errno::ETIMEDOUT, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
      raise ConnectionError, "Failed to connect to Cloud SQL instance: #{e.message}"
    end
  end
end
