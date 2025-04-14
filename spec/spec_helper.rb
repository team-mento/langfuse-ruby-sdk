# typed: false
require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  add_filter '/lib/version.rb'

  add_group 'Core', 'lib/langfuse'
  add_group 'Helpers', 'lib/langfuse_helper.rb'
  add_group 'Context', 'lib/langfuse_context.rb'
end

require 'bundler/setup'
require 'langfuse'
require 'concurrent'
require 'webmock/rspec'
require 'vcr'
require 'timecop'
require 'faker'
require 'logger'
require_relative '../lib/langfuse_helper'
require_relative '../lib/langfuse_context'

# Set up a test logger
TEST_LOGGER = Logger.new(STDOUT)
TEST_LOGGER.level = Logger::DEBUG

# Configure VCR
VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Filter out sensitive data
  config.filter_sensitive_data('<LANGFUSE_PUBLIC_KEY>') { ENV['LANGFUSE_PUBLIC_KEY'] }
  config.filter_sensitive_data('<LANGFUSE_SECRET_KEY>') { ENV['LANGFUSE_SECRET_KEY'] }

  # Allow real HTTP connections to localhost for integration tests
  config.allow_http_connections_when_no_cassette = true
  config.ignore_localhost = true
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Reset Langfuse configuration before each test
  config.before(:each) do
    # Allow spying on Langfuse module methods
    allow(Langfuse).to receive(:trace).and_call_original
    allow(Langfuse).to receive(:update_generation).and_call_original
    allow(Langfuse).to receive(:update_span).and_call_original
    allow(Langfuse).to receive(:score).and_call_original
    allow(Langfuse).to receive(:flush).and_call_original

    # Debug log the environment variables
    # TEST_LOGGER.debug 'Environment Variables:'
    # TEST_LOGGER.debug "LANGFUSE_PUBLIC_KEY=#{ENV['LANGFUSE_PUBLIC_KEY'].inspect}"
    # TEST_LOGGER.debug "LANGFUSE_SECRET_KEY=#{ENV['LANGFUSE_SECRET_KEY'].inspect}"
    # TEST_LOGGER.debug "LANGFUSE_TEST_PUBLIC_KEY=#{ENV['LANGFUSE_TEST_PUBLIC_KEY'].inspect}"
    # TEST_LOGGER.debug "LANGFUSE_TEST_SECRET_KEY=#{ENV['LANGFUSE_TEST_SECRET_KEY'].inspect}"

    # Use test credentials from environment if available, otherwise use dummy values
    public_key = ENV['LANGFUSE_TEST_PUBLIC_KEY'] || ENV['LANGFUSE_PUBLIC_KEY'] || 'test-public-key'
    secret_key = ENV['LANGFUSE_TEST_SECRET_KEY'] || ENV['LANGFUSE_SECRET_KEY'] || 'test-secret-key'

    Langfuse.configure do |c|
      c.public_key = public_key
      c.secret_key = secret_key
      c.host = ENV['LANGFUSE_HOST'] || 'https://us.cloud.langfuse.com'
      c.debug = true
      c.logger = TEST_LOGGER
      c.batch_size = 1 # For immediate feedback in tests
    end

    # Debug log the final configuration
    # TEST_LOGGER.debug 'Langfuse Configuration:'
    # TEST_LOGGER.debug "public_key=#{public_key}"
    # TEST_LOGGER.debug "secret_key=#{secret_key}"
    # TEST_LOGGER.debug "host=#{Langfuse.configuration.host}"
  end

  # Clean up any remaining events after each test
  config.after(:each) do
    Langfuse.flush
  end
end
