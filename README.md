# Cloud SQL Ruby Connector

[![Gem Version](https://badge.fury.io/rb/cloud_sql_ruby_connector.svg)](https://badge.fury.io/rb/cloud_sql_ruby_connector)

An unofficial Ruby connector for Google Cloud SQL that provides secure connections without requiring the Cloud SQL Auth Proxy.

> **⚠️ Unofficial Library:** This is a community-maintained Ruby implementation, not an official Google product. For official connectors, see:
> - [cloud-sql-nodejs-connector](https://github.com/GoogleCloudPlatform/cloud-sql-nodejs-connector) (Node.js)
> - [cloud-sql-python-connector](https://github.com/GoogleCloudPlatform/cloud-sql-python-connector) (Python)
> - [cloud-sql-go-connector](https://github.com/GoogleCloudPlatform/cloud-sql-go-connector) (Go)

## Features

- **Secure Connections:** TLS 1.3 encryption with automatic certificate management
- **Multiple Auth Methods:** Supports both built-in database authentication (username/password) and IAM database authentication
- **Flexible Networking:** Connect via public IP, private IP, or Private Service Connect (PSC)
- **No Proxy Required:** Direct secure connections without running Cloud SQL Auth Proxy as a separate process
- **Automatic Credentials:** On GCE/Cloud Run, uses the metadata server automatically - no credential files needed
- **No External Dependencies:** Uses only Ruby's built-in libraries (openssl, net/http, json, socket)

## Supported Databases

Currently supported:

- PostgreSQL (via [`pg`](https://rubygems.org/gems/pg) gem)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cloud_sql_ruby_connector'
```

And then execute:

```sh
bundle install
```

Or install it yourself as:

```sh
gem install cloud_sql_ruby_connector
```

## Prerequisites

- Ruby >= 3.3
- [Cloud SQL Admin API](https://console.cloud.google.com/apis/api/sqladmin.googleapis.com) enabled in your Google Cloud Project
- The calling identity must have the [Cloud SQL Client](https://cloud.google.com/sql/docs/mysql/roles-and-permissions) role (or equivalent permissions) to fetch instance metadata and certificates

## Credentials

The connector needs Google Cloud credentials to fetch instance metadata and certificates from the Cloud SQL Admin API.

**On GCE, Cloud Run, GKE, or other Google Cloud environments:**
No configuration needed - the connector automatically uses the metadata server.

**Outside Google Cloud:**
Use one of these methods:
1. Set `GOOGLE_APPLICATION_CREDENTIALS` environment variable to a service account JSON key file path
2. Run `gcloud auth application-default login` to use your user credentials

## Usage

### Basic Usage with PostgreSQL

```ruby
require 'cloud_sql_ruby_connector'
require 'pg'

connector = CloudSQLRubyConnector::PostgreSQL::Connector.new("my-project:us-central1:my-instance")
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
connector = CloudSQLRubyConnector::PostgreSQL::Connector.new(
  "my-project:us-central1:my-instance",
  ip_type: :private
)

# Using Private Service Connect (PSC)
connector = CloudSQLRubyConnector::PostgreSQL::Connector.new(
  "my-project:us-central1:my-instance",
  ip_type: :psc
)
```

**Note:** When using Private IP or PSC, your application must be connected to the appropriate VPC network.

### IAM Database Authentication

For IAM database authentication, configure your Cloud SQL instance to allow IAM authentication and add an IAM database user:

```ruby
connector = CloudSQLRubyConnector::PostgreSQL::Connector.new(
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
require 'cloud_sql_ruby_connector/rails'

CloudSQLRubyConnector::Rails.setup!(
  instance: ENV['CLOUD_SQL_INSTANCE'],  # e.g., "my-project:us-central1:my-instance"
  ip_type: :private,                     # :public, :private, or :psc
  auth_type: :iam                        # :password or :iam
)
```

Then in `config/database.yml`:

```yaml
# With IAM authentication
production:
  adapter: cloud_sql_postgresql
  database: my_database
  username: my-sa@my-project.iam.gserviceaccount.com
  pool: 5

# With password authentication
production:
  adapter: cloud_sql_postgresql
  database: my_database
  username: my_user
  password: <%= ENV['DB_PASSWORD'] %>
  pool: 5
```

## API Reference

### CloudSQLRubyConnector::PostgreSQL::Connector

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
