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

require_relative "../cloud_sql_ruby_connector"
require "active_record"
require "active_record/connection_adapters/postgresql_adapter"

module CloudSQLRubyConnector
  # Rails integration for Cloud SQL Connector
  #
  # @example Usage in config/initializers/cloud_sql.rb
  #   require "cloud_sql_ruby_connector/rails"
  #
  #   CloudSQLRubyConnector::Rails.setup!(
  #     instance: "project:region:instance",
  #     ip_type: :private,
  #     auth_type: :iam
  #   )
  #
  # @example Then in database.yml
  #   production:
  #     adapter: cloud_sql_postgresql
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
      # @param ip_type [String, Symbol] IP address type (default: :public)
      # @param auth_type [String, Symbol] Authentication type (default: :password)
      # @param credentials [Credentials::Base] Optional custom credentials
      def setup!(instance:, ip_type: IpAddressTypes::PUBLIC, auth_type: AuthTypes::PASSWORD, credentials: nil)
        @connector = PostgreSQL::Connector.new(
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
        ActiveRecord::ConnectionAdapters.register(
          "cloud_sql_postgresql",
          "CloudSQLRubyConnector::Rails::CloudSQLPostgreSQLAdapter",
          "cloud_sql_ruby_connector/rails"
        )
      end

      def register_shutdown_hook!
        at_exit { shutdown! }
      end
    end

    # Custom adapter that uses CloudSQLRubyConnector for connections
    class CloudSQLPostgreSQLAdapter < ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
      ADAPTER_NAME = "CloudSQL PostgreSQL"

      # PG connection options that can be passed through to PG.connect
      # See: https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-PARAMKEYWORDS
      ALLOWED_PG_OPTIONS = %i[
        application_name
        client_encoding
        connect_timeout
        options
        keepalives
        keepalives_idle
        keepalives_interval
        keepalives_count
        tcp_user_timeout
        target_session_attrs
      ].freeze

      class << self
        # In Rails 7.1+, new_client receives processed conn_params (user, dbname)
        # not the raw config (username, database)
        def new_client(conn_params)
          connector = CloudSQLRubyConnector::Rails.connector
          raise ConfigurationError, "CloudSQLRubyConnector::Rails.setup! not called" unless connector

          # conn_params already has :user and :dbname (processed by parent's initialize)
          cfg = if conn_params.respond_to?(:symbolize_keys)
                  conn_params.symbolize_keys
                else
                  conn_params.to_h.transform_keys(&:to_sym)
                end

          # Only pass through known PG connection options
          extra_options = cfg.slice(*ALLOWED_PG_OPTIONS)

          connector.connect(
            user: cfg[:user],
            password: cfg[:password],
            dbname: cfg[:dbname],
            **extra_options
          )
        end
      end
    end
  end
end
