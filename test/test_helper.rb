# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "cloud_sql_ruby_connector"
require "minitest/autorun"
require "webmock/minitest"

# Enable parallel test execution
require "minitest/parallel"
Minitest.parallel_executor = Minitest::Parallel::Executor.new(4)

# Disable all external HTTP connections in tests
WebMock.disable_net_connect!

# Helper module for fixtures
module FixtureHelpers
  def fixture_path(name)
    File.join(File.dirname(__FILE__), "fixtures", name)
  end

  def fixture(name)
    File.read(fixture_path(name))
  end

  def fixture_json(name)
    JSON.parse(fixture(name))
  end
end

# Helper to generate test certificates
module CertificateHelpers
  def self.test_key
    @test_key ||= OpenSSL::PKey::RSA.new(1024)
  end

  def self.test_cert
    @test_cert ||= begin
      key = test_key
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 1
      cert.subject = OpenSSL::X509::Name.new([%w[CN test]])
      cert.issuer = cert.subject
      cert.public_key = key.public_key
      cert.not_before = Time.now
      cert.not_after = Time.now + 3600
      cert.sign(key, OpenSSL::Digest.new("SHA256"))
      cert
    end
  end

  def generate_test_key
    CertificateHelpers.test_key
  end

  def generate_test_cert
    CertificateHelpers.test_cert
  end
end

# Mock credentials class for testing
class MockCredentials
  def access_token(scope:)
    scope == :admin ? "admin-token" : "login-token"
  end
end
