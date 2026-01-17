# frozen_string_literal: true

# Copyright 2026 Martin Milo
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
require "net/http"
require "json"
require "base64"

module CloudSQLRubyConnector
  module Credentials
    # Service Account credentials from JSON key file
    class ServiceAccount < Base
      attr_reader :client_email

      # Load credentials from a JSON file
      # @param path [String] path to the JSON key file
      # @return [ServiceAccount, UserCredentials] depending on the credential type
      def self.from_file(path)
        data = JSON.parse(File.read(path))

        if data["type"] == "authorized_user"
          UserCredentials.new(data)
        else
          new(data)
        end
      end

      def initialize(data)
        super()
        validate_required_fields!(data)
        @client_email = data["client_email"]
        @private_key = OpenSSL::PKey::RSA.new(data["private_key"])
      end

      private

      def validate_required_fields!(data)
        raise ConfigurationError, "Missing 'client_email' in service account credentials" if data["client_email"].nil?
        raise ConfigurationError, "Missing 'private_key' in service account credentials" if data["private_key"].nil?
      end

      protected

      def refresh_token(scope)
        now = Time.now.to_i
        payload = {
          iss: @client_email,
          scope: SCOPES[scope],
          aud: TOKEN_URI,
          iat: now,
          exp: now + 3600
        }

        jwt = encode_jwt(payload)

        uri = URI(TOKEN_URI)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 10
        http.read_timeout = 10

        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/x-www-form-urlencoded"
        request.body = URI.encode_www_form(
          grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
          assertion: jwt
        )

        response = http.request(request)
        data = JSON.parse(response.body)

        unless response.code.to_i == 200
          raise AuthenticationError, "Failed to get access token: #{data["error_description"] || data["error"]}"
        end

        store_token(scope, data["access_token"], data["expires_in"])
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        raise AuthenticationError, "Token request timed out: #{e.message}"
      rescue JSON::ParserError => e
        raise AuthenticationError, "Invalid token response: #{e.message}"
      end

      private

      def encode_jwt(payload)
        header = { alg: "RS256", typ: "JWT" }
        segments = [
          base64url_encode(header.to_json),
          base64url_encode(payload.to_json)
        ]
        signing_input = segments.join(".")
        signature = @private_key.sign("SHA256", signing_input)
        segments << base64url_encode(signature)
        segments.join(".")
      end

      def base64url_encode(data)
        Base64.urlsafe_encode64(data, padding: false)
      end
    end
  end
end
