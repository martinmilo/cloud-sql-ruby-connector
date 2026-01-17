# frozen_string_literal: true

require "test_helper"

class IpAddressTypesTest < Minitest::Test
  def test_valid_returns_true_for_valid_types
    assert CloudSQLRubyConnector::IpAddressTypes.valid?("PUBLIC")
    assert CloudSQLRubyConnector::IpAddressTypes.valid?("PRIVATE")
    assert CloudSQLRubyConnector::IpAddressTypes.valid?("PSC")
    assert CloudSQLRubyConnector::IpAddressTypes.valid?("public")
  end

  def test_valid_returns_false_for_invalid_types
    refute CloudSQLRubyConnector::IpAddressTypes.valid?("INVALID")
    refute CloudSQLRubyConnector::IpAddressTypes.valid?("")
  end

  def test_normalize_normalizes_valid_types_to_uppercase
    assert_equal "PUBLIC", CloudSQLRubyConnector::IpAddressTypes.normalize("public")
    assert_equal "PRIVATE", CloudSQLRubyConnector::IpAddressTypes.normalize("Private")
    assert_equal "PSC", CloudSQLRubyConnector::IpAddressTypes.normalize(:psc)
  end

  def test_normalize_raises_for_invalid_types
    assert_raises(CloudSQLRubyConnector::ConfigurationError) do
      CloudSQLRubyConnector::IpAddressTypes.normalize("invalid")
    end
  end

  def test_api_key_returns_correct_key_for_each_type
    assert_equal "PRIMARY", CloudSQLRubyConnector::IpAddressTypes.api_key("PUBLIC")
    assert_equal "PRIVATE", CloudSQLRubyConnector::IpAddressTypes.api_key("PRIVATE")
    assert_equal "PSC", CloudSQLRubyConnector::IpAddressTypes.api_key("PSC")
  end
end
