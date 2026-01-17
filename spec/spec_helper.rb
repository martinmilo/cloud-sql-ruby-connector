# frozen_string_literal: true

require "cloudsql_ruby_connector"
require "webmock/rspec"

# Disable all external HTTP connections in tests
WebMock.disable_net_connect!

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end

# Helper to load fixture files
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

RSpec.configure do |config|
  config.include FixtureHelpers
end
