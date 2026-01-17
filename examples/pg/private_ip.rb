#!/usr/bin/env ruby
# frozen_string_literal: true

# Private IP connection example using Cloud SQL Ruby Connector
#
# This example demonstrates how to connect via private IP address.
# Your application must be running in a VPC with access to the
# Cloud SQL instance's private IP.
#
# Prerequisites:
#   - gem install cloudsql_ruby_connector pg
#   - Application running in VPC with Cloud SQL private IP access
#   - Set GOOGLE_APPLICATION_CREDENTIALS or run on GCE/Cloud Run
#
# Usage:
#   INSTANCE_CONNECTION_NAME=project:region:instance \
#   DB_USER=myuser \
#   DB_PASS=mypassword \
#   DB_NAME=mydb \
#   ruby private_ip.rb

require "cloudsql_ruby_connector"
require "pg"

instance_connection_name = ENV.fetch("INSTANCE_CONNECTION_NAME")
db_user = ENV.fetch("DB_USER")
db_pass = ENV.fetch("DB_PASS")
db_name = ENV.fetch("DB_NAME")

# Create a connector using private IP
connector = CloudsqlRubyConnector::Connector.new(
  instance_connection_name,
  ip_type: CloudsqlRubyConnector::IpAddressTypes::PRIVATE
)

# Connect to the database
conn = connector.connect(
  user: db_user,
  password: db_pass,
  dbname: db_name
)

# Execute a query
result = conn.exec("SELECT inet_server_addr() as server_ip, NOW() as current_time")
row = result.first
puts "Connected to server IP: #{row["server_ip"]}"
puts "Current time: #{row["current_time"]}"

# Clean up
conn.close
connector.close
