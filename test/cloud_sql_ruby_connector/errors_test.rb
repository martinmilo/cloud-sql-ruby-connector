# frozen_string_literal: true

require "test_helper"

class ErrorTest < Minitest::Test
  def test_stores_error_code
    error = CloudSQLRubyConnector::Error.new("test message", code: "ECODE")

    assert_equal "test message", error.message
    assert_equal "ECODE", error.code
  end
end

class AuthenticationErrorTest < Minitest::Test
  def test_has_default_code
    error = CloudSQLRubyConnector::AuthenticationError.new("auth failed")

    assert_equal "EAUTH", error.code
  end
end

class ConnectionErrorTest < Minitest::Test
  def test_has_default_code
    error = CloudSQLRubyConnector::ConnectionError.new("connection failed")

    assert_equal "ECONNECTION", error.code
  end
end

class ConfigurationErrorTest < Minitest::Test
  def test_has_default_code
    error = CloudSQLRubyConnector::ConfigurationError.new("config invalid")

    assert_equal "ECONFIG", error.code
  end
end

class IpAddressErrorTest < Minitest::Test
  def test_has_default_code
    error = CloudSQLRubyConnector::IpAddressError.new("no ip")

    assert_equal "ENOIPADDRESS", error.code
  end
end
