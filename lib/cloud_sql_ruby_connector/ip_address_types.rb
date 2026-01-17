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

module CloudSQLRubyConnector
  # IP address types for Cloud SQL connections
  module IpAddressTypes
    PUBLIC = "PUBLIC"
    PRIVATE = "PRIVATE"
    PSC = "PSC"

    ALL = [PUBLIC, PRIVATE, PSC].freeze

    class << self
      def valid?(type)
        ALL.include?(type.to_s.upcase)
      end

      def normalize(type)
        normalized = type.to_s.upcase
        unless valid?(normalized)
          raise ConfigurationError,
                "Invalid IP address type: #{type}. Valid types: #{ALL.join(", ")}"
        end

        normalized
      end

      # Returns the API key used in Cloud SQL Admin API response
      def api_key(type)
        case normalize(type)
        when PUBLIC then "PRIMARY"
        when PRIVATE then "PRIVATE"
        when PSC then "PSC"
        end
      end
    end
  end
end
