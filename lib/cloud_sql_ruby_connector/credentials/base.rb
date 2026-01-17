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
  module Credentials
    # Base class for all credential types
    class Base
      SCOPES = {
        admin: "https://www.googleapis.com/auth/sqlservice.admin",
        login: "https://www.googleapis.com/auth/sqlservice.login"
      }.freeze

      TOKEN_URI = "https://oauth2.googleapis.com/token"

      def initialize
        @tokens = {}
        @token_expiries = {}
        @mutex = Mutex.new
      end

      # Get an access token for the specified scope
      # @param scope [Symbol] :admin or :login
      # @return [String] the access token
      def access_token(scope: :admin)
        @mutex.synchronize do
          refresh_token(scope) if token_expired?(scope)
          @tokens[scope]
        end
      end

      protected

      def token_expired?(scope)
        @tokens[scope].nil? || @token_expiries[scope].nil? || Time.now >= @token_expiries[scope]
      end

      def refresh_token(scope)
        raise NotImplementedError, "Subclasses must implement #refresh_token"
      end

      def store_token(scope, token, expires_in)
        @tokens[scope] = token
        # Refresh 60 seconds before actual expiration
        @token_expiries[scope] = Time.now + expires_in.to_i - 60
      end
    end
  end
end
