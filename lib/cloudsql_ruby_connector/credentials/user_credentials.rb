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

module CloudsqlRubyConnector
  module Credentials
    # User credentials from gcloud auth application-default login
    class UserCredentials < Base
      def initialize(data)
        super()
        @client_id = data["client_id"]
        @client_secret = data["client_secret"]
        @refresh_token_value = data["refresh_token"]
      end

      protected

      def refresh_token(scope)
        uri = URI(TOKEN_URI)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 10
        http.read_timeout = 10

        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/x-www-form-urlencoded"
        request.body = URI.encode_www_form(
          client_id: @client_id,
          client_secret: @client_secret,
          refresh_token: @refresh_token_value,
          grant_type: "refresh_token"
        )

        response = http.request(request)
        data = JSON.parse(response.body)

        unless response.code.to_i == 200
          raise AuthenticationError, "Failed to refresh token: #{data["error_description"] || data["error"]}"
        end

        store_token(scope, data["access_token"], data["expires_in"])
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        raise AuthenticationError, "Token refresh timed out: #{e.message}"
      rescue JSON::ParserError => e
        raise AuthenticationError, "Invalid token response: #{e.message}"
      end
    end
  end
end
