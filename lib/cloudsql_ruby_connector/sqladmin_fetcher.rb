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

require "net/http"
require "json"
require "openssl"

module CloudsqlRubyConnector
  # Fetches instance metadata and ephemeral certificates from Cloud SQL Admin API
  class SqlAdminFetcher
    API_VERSION = "v1beta4"
    DEFAULT_ENDPOINT = "https://sqladmin.googleapis.com"
    HTTP_TIMEOUT = 30 # seconds

    def initialize(credentials:, api_endpoint: nil)
      @credentials = credentials
      @api_endpoint = api_endpoint || DEFAULT_ENDPOINT
    end

    # Fetch instance metadata including IP addresses and server CA certificate
    # @param project [String] Google Cloud project ID
    # @param region [String] Cloud SQL instance region
    # @param instance [String] Cloud SQL instance name
    # @return [Hash] instance metadata
    def fetch_metadata(project:, region:, instance:)
      token = @credentials.access_token(scope: :admin)
      uri = URI("#{@api_endpoint}/sql/#{API_VERSION}/projects/#{project}/instances/#{instance}/connectSettings")

      response = http_get(uri, token)
      data = parse_response(response)

      raise ConfigurationError, "Region mismatch: expected #{region}, got #{data["region"]}" if data["region"] != region

      ip_addresses = parse_ip_addresses(
        data["ipAddresses"],
        data["dnsName"],
        data["dnsNames"],
        data["pscEnabled"]
      )

      server_ca_cert = data.dig("serverCaCert", "cert")
      raise ConnectionError, "No valid CA certificate found for instance" if server_ca_cert.nil?

      {
        ip_addresses: ip_addresses,
        server_ca_cert: server_ca_cert,
        database_version: data["databaseVersion"],
        dns_name: data["dnsName"]
      }
    end

    # Fetch an ephemeral certificate for client authentication
    # @param project [String] Google Cloud project ID
    # @param instance [String] Cloud SQL instance name
    # @param public_key [String] RSA public key in PEM format
    # @param auth_type [String] Authentication type (PASSWORD or IAM)
    # @return [Hash] certificate data with :cert and :expiration
    def fetch_ephemeral_cert(project:, instance:, public_key:, auth_type:)
      token = @credentials.access_token(scope: :admin)
      uri = URI("#{@api_endpoint}/sql/#{API_VERSION}/projects/#{project}/instances/#{instance}:generateEphemeralCert")

      body = { "public_key" => public_key }

      # For IAM auth, include the login token
      if auth_type == AuthTypes::IAM
        login_token = @credentials.access_token(scope: :login)
        body["access_token"] = login_token
      end

      response = http_post(uri, token, body)
      data = parse_response(response)

      cert_pem = data.dig("ephemeralCert", "cert")
      raise ConnectionError, "Failed to retrieve ephemeral certificate" if cert_pem.nil?

      cert = OpenSSL::X509::Certificate.new(cert_pem)

      {
        cert: cert_pem,
        expiration: cert.not_after
      }
    end

    private

    def parse_response(response)
      data = JSON.parse(response.body)

      if response.code.to_i >= 400
        error_msg = data.dig("error", "message") || response.body
        raise ConnectionError, "API request failed: #{error_msg}"
      end

      data
    rescue JSON::ParserError => e
      raise ConnectionError, "Invalid API response: #{e.message}"
    end

    # Parse IP addresses from API response
    # Node.js ref: https://github.com/GoogleCloudPlatform/cloud-sql-nodejs-connector/blob/main/src/sqladmin-fetcher.ts
    def parse_ip_addresses(ip_data, dns_name, dns_names, psc_enabled)
      ip_addresses = {}

      # Parse regular IP addresses (PUBLIC/PRIVATE)
      ip_data&.each do |ip|
        case ip["type"]
        when "PRIMARY"
          ip_addresses["PRIMARY"] = ip["ipAddress"]
        when "PRIVATE"
          ip_addresses["PRIVATE"] = ip["ipAddress"]
        end
      end

      # PSC uses DNS names, not IP addresses
      # First, check dns_names array for PSC connection type
      if dns_names.is_a?(Array)
        dns_names.each do |dnm|
          if dnm["connectionType"] == "PRIVATE_SERVICE_CONNECT" && dnm["dnsScope"] == "INSTANCE"
            ip_addresses["PSC"] = dnm["name"]
            break
          end
        end
      end

      # Fallback to legacy dns_name field if PSC not found and pscEnabled is true
      ip_addresses["PSC"] = dns_name if ip_addresses["PSC"].nil? && dns_name && psc_enabled

      ip_addresses
    end

    def http_get(uri, token)
      http = create_http_client(uri)

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{token}"
      request["Content-Type"] = "application/json"

      http.request(request)
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise ConnectionError, "Request timed out: #{e.message}"
    rescue StandardError => e
      raise ConnectionError, "HTTP request failed: #{e.message}"
    end

    def http_post(uri, token, body)
      http = create_http_client(uri)

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{token}"
      request["Content-Type"] = "application/json"
      request.body = body.to_json

      http.request(request)
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise ConnectionError, "Request timed out: #{e.message}"
    rescue StandardError => e
      raise ConnectionError, "HTTP request failed: #{e.message}"
    end

    def create_http_client(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.open_timeout = HTTP_TIMEOUT
      http.read_timeout = HTTP_TIMEOUT
      http
    end
  end
end
