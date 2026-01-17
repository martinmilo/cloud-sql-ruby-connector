# frozen_string_literal: true

require_relative "lib/cloudsql_ruby_connector/version"

Gem::Specification.new do |spec|
  spec.name = "cloudsql_ruby_connector"
  spec.version = CloudsqlRubyConnector::VERSION
  spec.authors = ["Martin Milo"]
  spec.email = ["your-email@example.com"]

  spec.summary = "Cloud SQL Ruby Connector"
  spec.description = "An unofficial Ruby connector for Google Cloud SQL that provides secure, " \
                     "IAM-based authentication without requiring the Cloud SQL Auth Proxy."
  spec.homepage = "https://github.com/your-username/cloudsql-ruby-connector"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.glob("{lib}/**/*") + %w[
    LICENSE
    README.md
    CHANGELOG.md
    CODE_OF_CONDUCT.md
    CONTRIBUTING.md
    SECURITY.md
  ]

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Ruby 3.4+ removed base64 from default gems
  spec.add_dependency "base64"
end
