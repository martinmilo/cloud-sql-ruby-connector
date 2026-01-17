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

require_relative "../cloudsql_ruby_connector"

module CloudsqlRubyConnector
  # Rails integration for Cloud SQL Connector
  #
  # @example Usage in config/initializers/cloud_sql.rb
  #   require "cloudsql_ruby_connector/rails"
  #
  #   CloudsqlRubyConnector::Rails.setup!(
  #     instance: "project:region:instance",
  #     ip_type: CloudsqlRubyConnector::IpAddressTypes::PRIVATE,
  #     auth_type: CloudsqlRubyConnector::AuthTypes::IAM
  #   )
  #
  # @example Then in database.yml
  #   production:
  #     adapter: cloudsql_postgresql
  #     database: myapp_production
  #     username: myuser@project.iam.gserviceaccount.com
  #     pool: 5
  #
  module Rails
    class << self
      attr_reader :connector

      # Set up the Cloud SQL connector for Rails
      #
      # @param instance [String] Cloud SQL instance connection name
      # @param ip_type [String] IP address type (default: PUBLIC)
      # @param auth_type [String] Authentication type (default: PASSWORD)
      # @param credentials [Credentials::Base] Optional custom credentials
      def setup!(instance:, ip_type: IpAddressTypes::PUBLIC, auth_type: AuthTypes::PASSWORD, credentials: nil)
        @connector = Connector.new(
          instance,
          ip_type: ip_type,
          auth_type: auth_type,
          credentials: credentials
        )
        register_adapter!
        register_shutdown_hook!
      end

      # Close the connector and clean up resources
      def shutdown!
        @connector&.close
        @connector = nil
      end

      private

      def register_adapter!
        require "active_record"
        require "active_record/connection_adapters/postgresql_adapter"

        ActiveRecord::ConnectionAdapters.register(
          "cloudsql_postgresql",
          "CloudsqlRubyConnector::Rails::CloudSQLPostgreSQLAdapter",
          "cloudsql_ruby_connector/rails"
        )
      end

      def register_shutdown_hook!
        at_exit { shutdown! }
      end
    end

    # Custom adapter that uses CloudsqlRubyConnector for connections
    class CloudSQLPostgreSQLAdapter < ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
      ADAPTER_NAME = "CloudSQL PostgreSQL"

      class << self
        def new_client(config)
          connector = CloudsqlRubyConnector::Rails.connector
          raise ConfigurationError, "CloudsqlRubyConnector::Rails.setup! not called" unless connector

          connector.connect(
            user: config[:username],
            password: config[:password],
            dbname: config[:database]
          )
        end
      end
    end
  end
end
