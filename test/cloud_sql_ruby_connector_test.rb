# frozen_string_literal: true

require "test_helper"

class CloudSQLRubyConnectorTest < Minitest::Test
  def test_has_a_version_number
    refute_nil CloudSQLRubyConnector::VERSION
    assert_equal "0.1.0", CloudSQLRubyConnector::VERSION
  end
end
