#!/usr/bin/env ruby
# frozen_string_literal: true

# IAM Authentication example using Cloud SQL Ruby Connector
#
# This example demonstrates how to use IAM database authentication
# instead of traditional username/password authentication.
#
# Prerequisites:
#   - gem install cloud_sql_ruby_connector pg
#   - Cloud SQL instance configured for IAM authentication
#   - IAM database user created
#   - Service account with Cloud SQL Client role
#
# Usage:
#   INSTANCE_CONNECTION_NAME=project:region:instance \
#   DB_USER=service-account@project.iam.gserviceaccount.com \
#   DB_NAME=mydb \
#   ruby iam_auth.rb

require "cloud_sql_ruby_connector"
require "pg"

instance_connection_name = ENV.fetch("INSTANCE_CONNECTION_NAME")
db_user = ENV.fetch("DB_USER")
db_name = ENV.fetch("DB_NAME")

# Create a connector with IAM authentication
connector = CloudSQLRubyConnector::PostgreSQL::Connector.new(
  instance_connection_name,
  auth_type: :iam
)

# Connect - no password needed for IAM auth
conn = connector.connect(
  user: db_user,
  dbname: db_name
)

# Execute a query
result = conn.exec("SELECT current_user, NOW() as current_time")
row = result.first
puts "Connected as: #{row["current_user"]}"
puts "Current time: #{row["current_time"]}"

# Clean up
conn.close
connector.close
