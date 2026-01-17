# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-01-17

### Added

- Initial release with `CloudSQLRubyConnector::PostgreSQL::Connector`
- Support for PostgreSQL connections via Cloud SQL
- Support for PUBLIC, PRIVATE, and PSC IP address types
- Support for PASSWORD (built-in) and IAM authentication
- Automatic certificate refresh before expiration
- Service account, user credentials, and metadata server authentication
- Thread-safe connection handling with SSL proxy
- Rails integration with custom `cloud_sql_postgresql` adapter
