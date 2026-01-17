#!/usr/bin/env ruby
# frozen_string_literal: true

# Basic PostgreSQL connection example using Cloud SQL Ruby Connector
#
# Prerequisites:
#   - gem install cloud_sql_ruby_connector pg
#   - Set GOOGLE_APPLICATION_CREDENTIALS or run `gcloud auth application-default login`
#
# Usage:
#   INSTANCE_CONNECTION_NAME=project:region:instance \
#   DB_USER=myuser \
#   DB_PASS=mypassword \
#   DB_NAME=mydb \
#   ruby basic.rb

require "cloud_sql_ruby_connector"
require "pg"

instance_connection_name = ENV.fetch("INSTANCE_CONNECTION_NAME")
db_user = ENV.fetch("DB_USER")
db_pass = ENV.fetch("DB_PASS")
db_name = ENV.fetch("DB_NAME")

# Create a connector instance
connector = CloudSQLRubyConnector::PostgreSQL::Connector.new(instance_connection_name)

# Connect to the database
conn = connector.connect(
  user: db_user,
  password: db_pass,
  dbname: db_name
)

# Execute a query
result = conn.exec("SELECT NOW() as current_time")
puts "Current time from database: #{result.first["current_time"]}"

# Clean up
conn.close
connector.close
