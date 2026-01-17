# Cloud SQL Ruby Connector

[![Gem Version](https://badge.fury.io/rb/cloudsql_ruby_connector.svg)](https://badge.fury.io/rb/cloudsql_ruby_connector)

An unofficial Ruby connector for Google Cloud SQL that provides secure, IAM-based authentication without requiring the Cloud SQL Auth Proxy.

> **⚠️ Unofficial Library:** This is a community-maintained Ruby implementation, not an official Google product. For official connectors, see:
> - [cloud-sql-nodejs-connector](https://github.com/GoogleCloudPlatform/cloud-sql-nodejs-connector) (Node.js)
> - [cloud-sql-python-connector](https://github.com/GoogleCloudPlatform/cloud-sql-python-connector) (Python)
> - [cloud-sql-go-connector](https://github.com/GoogleCloudPlatform/cloud-sql-go-connector) (Go)

## Features

- **IAM Authorization:** Uses IAM permissions to control who/what can connect to your Cloud SQL instances
- **Improved Security:** Uses robust, updated TLS 1.3 encryption and identity verification between the client connector and the server-side proxy, independent of the database protocol
- **Convenience:** Removes the requirement to use and distribute SSL certificates, as well as manage firewalls or source/destination IP addresses
- **IAM DB Authentication:** Supports Cloud SQL's automatic IAM DB authentication feature
- **No External Dependencies:** Uses only Ruby's built-in libraries (openssl, net/http, json, socket)

## Supported Databases

Currently supported:

- PostgreSQL (via [`pg`](https://rubygems.org/gems/pg) gem)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cloudsql_ruby_connector'
```

And then execute:

```sh
bundle install
```

Or install it yourself as:

```sh
gem install cloudsql_ruby_connector
```

## Prerequisites

- Ruby >= 3.3
- IAM principal (user, service account, etc.) with the [Cloud SQL Client](https://cloud.google.com/sql/docs/mysql/roles-and-permissions) role
- [Cloud SQL Admin API](https://console.cloud.google.com/apis/api/sqladmin.googleapis.com) enabled in your Google Cloud Project

## Credentials

This library uses the Application Default Credentials (ADC) strategy for resolving credentials:

1. `GOOGLE_APPLICATION_CREDENTIALS` environment variable pointing to a service account JSON key file
2. User credentials from `gcloud auth application-default login` (stored in `~/.config/gcloud/application_default_credentials.json`)
3. GCE/Cloud Run metadata server (when running on Google Cloud)

## Usage

### Basic Usage with PostgreSQL

```ruby
require 'cloudsql_ruby_connector'
require 'pg'

connector = CloudsqlRubyConnector::Connector.new("my-project:us-central1:my-instance")
conn = connector.connect(
  user: "my-user",
  password: "my-password",
  dbname: "my-database"
)

result = conn.exec("SELECT NOW()")
puts result.first

conn.close
connector.close
```

### Specifying IP Address Type

The connector supports `:public` (default), `:private`, and `:psc` IP address types:

```ruby
# Using Private IP
connector = CloudsqlRubyConnector::Connector.new(
  "my-project:us-central1:my-instance",
  ip_type: :private
)

# Using Private Service Connect (PSC)
connector = CloudsqlRubyConnector::Connector.new(
  "my-project:us-central1:my-instance",
  ip_type: :psc
)
```

**Note:** When using Private IP or PSC, your application must be connected to the appropriate VPC network.

### IAM Database Authentication

For IAM database authentication, configure your Cloud SQL instance to allow IAM authentication and add an IAM database user:

```ruby
connector = CloudsqlRubyConnector::Connector.new(
  "my-project:us-central1:my-instance",
  ip_type: :private,
  auth_type: :iam
)

# For service accounts, use the full email - the connector strips .gserviceaccount.com automatically
conn = connector.connect(
  user: "my-service-account@my-project.iam.gserviceaccount.com",
  dbname: "my-database"
)
# Note: password is not required for IAM authentication
```

### Using with Rails

Create an initializer at `config/initializers/cloud_sql.rb`:

```ruby
require 'cloudsql_ruby_connector'
require 'cloudsql_ruby_connector/rails'

CloudsqlRubyConnector::Rails.setup!(
  instance: ENV['CLOUD_SQL_INSTANCE'],  # e.g., "my-project:us-central1:my-instance"
  ip_type: :private,
  auth_type: :iam
)
```

Then in `config/database.yml`:

```yaml
production:
  adapter: cloudsql_postgresql
  database: my_database
  username: my-sa@my-project.iam.gserviceaccount.com
  pool: 5
  # Note: password is not needed for IAM auth
```

## API Reference

### CloudsqlRubyConnector::Connector

#### `#initialize(instance_connection_name, **options)`

Creates a new connector instance.

**Parameters:**
- `instance_connection_name` (String): Cloud SQL instance connection name in format `PROJECT:REGION:INSTANCE`
- `credentials` (Credentials::Base, optional): Custom credentials object
- `ip_type` (Symbol/String, optional): IP address type - `:public` (default), `:private`, or `:psc`
- `auth_type` (Symbol/String, optional): Authentication type - `:password` (default) or `:iam`
- `api_endpoint` (String, optional): Custom Cloud SQL Admin API endpoint

#### `#connect(user:, dbname:, password: nil, **options)`

Creates a connected `PG::Connection`.

**Parameters:**
- `user` (String): Database username
- `dbname` (String): Database name
- `password` (String, optional): Database password (not required for IAM auth)
- Additional options are passed to `PG.connect`

**Returns:** `PG::Connection`

#### `#get_options`

Returns connection options that can be used with `PG.connect`.

**Returns:** Hash with `:stream`, `:ip_address`, `:server_ca_cert`, `:client_cert`, `:private_key`

#### `#ip_address`

Returns the IP address of the Cloud SQL instance.

**Returns:** String

#### `#close`

Closes the connector and cleans up resources.

### IP Address Types

Use symbols (recommended) or constants:

| Symbol | Constant | Description |
|--------|----------|-------------|
| `:public` | `IpAddressTypes::PUBLIC` | Connect via public IP (default) |
| `:private` | `IpAddressTypes::PRIVATE` | Connect via private IP (requires VPC) |
| `:psc` | `IpAddressTypes::PSC` | Connect via Private Service Connect |

### Authentication Types

| Symbol | Constant | Description |
|--------|----------|-------------|
| `:password` | `AuthTypes::PASSWORD` | Built-in database authentication (default) |
| `:iam` | `AuthTypes::IAM` | IAM database authentication |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## Code of Conduct

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for details.

## Security

See [SECURITY.md](SECURITY.md) for reporting vulnerabilities.

## License

Apache License 2.0 - see [LICENSE](LICENSE) for details.
