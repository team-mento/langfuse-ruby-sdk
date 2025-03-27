require 'bundler/setup'
require 'langfuse'
require 'concurrent'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Clear the client instance between tests
  config.before(:each) do
    if Langfuse.const_defined?(:Client) && Langfuse::Client.respond_to?(:instance)
      client = Langfuse::Client.instance
      client.instance_variable_set(:@events, Concurrent::Array.new)
    end
  end
end
