# Rails Integration Example

This example shows how to use the Cloud SQL Ruby Connector (`CloudSQLRubyConnector::PostgreSQL::Connector`) with Ruby on Rails.

## Setup

### 1. Add to Gemfile

```ruby
gem 'cloud_sql_ruby_connector'
gem 'pg'
```

### 2. Create initializer

Create `config/initializers/cloud_sql.rb`:

```ruby
require 'cloud_sql_ruby_connector'
require 'cloud_sql_ruby_connector/rails'

CloudSQLRubyConnector::Rails.setup!(
  instance: ENV['CLOUD_SQL_INSTANCE'],
  ip_type: ENV.fetch('CLOUD_SQL_IP_TYPE', 'PUBLIC'),
  auth_type: ENV.fetch('CLOUD_SQL_AUTH_TYPE', 'PASSWORD')
)
```

### 3. Configure database.yml

```yaml
production:
  adapter: cloud_sql_postgresql
  database: <%= ENV['DB_NAME'] %>
  username: <%= ENV['DB_USER'] %>
  password: <%= ENV['DB_PASS'] %>
  pool: <%= ENV.fetch('RAILS_MAX_THREADS', 5) %>
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `CLOUD_SQL_INSTANCE` | Instance connection name (project:region:instance) | Yes |
| `CLOUD_SQL_IP_TYPE` | IP type: PUBLIC, PRIVATE, or PSC | No (default: PUBLIC) |
| `CLOUD_SQL_AUTH_TYPE` | Auth type: PASSWORD or IAM | No (default: PASSWORD) |
| `DB_NAME` | Database name | Yes |
| `DB_USER` | Database username | Yes |
| `DB_PASS` | Database password (not needed for IAM auth) | Depends |

## IAM Authentication with Rails

For IAM authentication, set:

```bash
export CLOUD_SQL_AUTH_TYPE=IAM
export DB_USER=service-account@project.iam.gserviceaccount.com
# No DB_PASS needed
```

The initializer becomes:

```ruby
CloudSQLRubyConnector::Rails.setup!(
  instance: ENV['CLOUD_SQL_INSTANCE'],
  auth_type: :iam
)
```
