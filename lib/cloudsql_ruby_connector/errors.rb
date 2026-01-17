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

module CloudsqlRubyConnector
  # Base error class for all Cloud SQL Connector errors
  class Error < StandardError
    attr_reader :code

    def initialize(message, code: nil)
      @code = code
      super(message)
    end
  end

  # Raised when authentication fails
  class AuthenticationError < Error
    def initialize(message, code: "EAUTH")
      super
    end
  end

  # Raised when connection to Cloud SQL instance fails
  class ConnectionError < Error
    def initialize(message, code: "ECONNECTION")
      super
    end
  end

  # Raised when configuration is invalid
  class ConfigurationError < Error
    def initialize(message, code: "ECONFIG")
      super
    end
  end

  # Raised when IP address is not available
  class IpAddressError < Error
    def initialize(message, code: "ENOIPADDRESS")
      super
    end
  end
end
