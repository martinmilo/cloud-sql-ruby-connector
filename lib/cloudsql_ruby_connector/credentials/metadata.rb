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
    # GCE/Cloud Run metadata server credentials
    class Metadata < Base
      METADATA_BASE = "http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default"

      protected

      def refresh_token(scope)
        uri = URI("#{METADATA_BASE}/token?scopes=#{SCOPES[scope]}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = 2
        http.read_timeout = 2

        request = Net::HTTP::Get.new(uri)
        request["Metadata-Flavor"] = "Google"

        response = http.request(request)
        data = JSON.parse(response.body)

        raise AuthenticationError, "Failed to get metadata token: #{response.body}" unless response.code.to_i == 200

        store_token(scope, data["access_token"], data["expires_in"])
      rescue Errno::EHOSTUNREACH, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout
        raise AuthenticationError, "Not running on GCE/Cloud Run and no credentials found"
      rescue JSON::ParserError => e
        raise AuthenticationError, "Invalid metadata response: #{e.message}"
      end
    end
  end
end
