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

require_relative "cloud_sql_ruby_connector/version"
require_relative "cloud_sql_ruby_connector/errors"
require_relative "cloud_sql_ruby_connector/ip_address_types"
require_relative "cloud_sql_ruby_connector/auth_types"
require_relative "cloud_sql_ruby_connector/credentials/base"
require_relative "cloud_sql_ruby_connector/credentials/service_account"
require_relative "cloud_sql_ruby_connector/credentials/user_credentials"
require_relative "cloud_sql_ruby_connector/credentials/metadata"
require_relative "cloud_sql_ruby_connector/ssl_proxy"
require_relative "cloud_sql_ruby_connector/sqladmin_fetcher"
require_relative "cloud_sql_ruby_connector/postgresql/connector"

# Cloud SQL Ruby Connector
#
# A Ruby connector for Google Cloud SQL that provides secure, IAM-based
# authentication without requiring the Cloud SQL Auth Proxy.
#
# @example Basic usage with PostgreSQL
#   require 'cloud_sql_ruby_connector'
#   require 'pg'
#
#   connector = CloudSQLRubyConnector::PostgreSQL::Connector.new("my-project:us-central1:my-instance")
#   conn = connector.connect(user: "myuser", password: "mypass", dbname: "mydb")
#   result = conn.exec("SELECT NOW()")
#   puts result.first
#   conn.close
#   connector.close
#
# @example Using IAM authentication
#   connector = CloudSQLRubyConnector::PostgreSQL::Connector.new(
#     "my-project:us-central1:my-instance",
#     auth_type: :iam,
#     ip_type: :private
#   )
#   conn = connector.connect(
#     user: "service-account@project.iam.gserviceaccount.com",
#     dbname: "mydb"
#   )
#
module CloudSQLRubyConnector
  module PostgreSQL
  end
end
