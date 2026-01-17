# frozen_string_literal: true

require "test_helper"

class AuthTypesTest < Minitest::Test
  def test_valid_returns_true_for_valid_types
    assert CloudSQLRubyConnector::AuthTypes.valid?("PASSWORD")
    assert CloudSQLRubyConnector::AuthTypes.valid?("IAM")
    assert CloudSQLRubyConnector::AuthTypes.valid?("password")
  end

  def test_valid_returns_false_for_invalid_types
    refute CloudSQLRubyConnector::AuthTypes.valid?("INVALID")
    refute CloudSQLRubyConnector::AuthTypes.valid?("")
  end

  def test_normalize_normalizes_valid_types_to_uppercase
    assert_equal "PASSWORD", CloudSQLRubyConnector::AuthTypes.normalize("password")
    assert_equal "IAM", CloudSQLRubyConnector::AuthTypes.normalize("Iam")
    assert_equal "IAM", CloudSQLRubyConnector::AuthTypes.normalize(:iam)
  end

  def test_normalize_raises_for_invalid_types
    assert_raises(CloudSQLRubyConnector::ConfigurationError) do
      CloudSQLRubyConnector::AuthTypes.normalize("invalid")
    end
  end
end
