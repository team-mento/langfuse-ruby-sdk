# Testing and Exercising the Langfuse Ruby SDK Before Release

This guide provides a comprehensive approach to testing and validating the Langfuse Ruby SDK before releasing it or integrating it into larger projects. We'll cover different testing approaches, from unit tests to integration testing and manual validation.

## 1. Setting Up the Test Environment

### 1.1 Test Dependencies

First, add the necessary testing dependencies to your gemspec or Gemfile:

```ruby
# langfuse.gemspec
Gem::Specification.new do |spec|
  # ... other specifications ...
  
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'webmock', '~> 3.18'
  spec.add_development_dependency 'vcr', '~> 6.1'
  spec.add_development_dependency 'timecop', '~> 0.9'
  spec.add_development_dependency 'faker', '~> 3.2'
  spec.add_development_dependency 'rubocop', '~> 1.50'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.20'
  spec.add_development_dependency 'simplecov', '~> 0.22'
end
```

### 1.2 RSpec Configuration

Create the RSpec configuration file:

```ruby
# spec/spec_helper.rb
require 'simplecov'
SimpleCov.start

require 'langfuse'
require 'webmock/rspec'
require 'vcr'
require 'timecop'
require 'faker'

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  
  # Filter out sensitive data
  config.filter_sensitive_data('<LANGFUSE_PUBLIC_KEY>') { ENV['LANGFUSE_PUBLIC_KEY'] }
  config.filter_sensitive_data('<LANGFUSE_SECRET_KEY>') { ENV['LANGFUSE_SECRET_KEY'] }
end

RSpec.configure do |config|
  config.before(:each) do
    Langfuse.configure do |c|
      c.public_key = 'test-public-key'
      c.secret_key = 'test-secret-key'
      c.host = 'https://us.cloud.langfuse.com'
      c.debug = false
    end
  end
end
```

## 2. Unit Testing

### 2.1 Testing the Context Manager

```ruby
# spec/lib/langfuse_context_spec.rb
require 'spec_helper'

RSpec.describe LangfuseContext do
  describe '.with_trace' do
    it 'sets and clears trace context' do
      trace = double('trace', id: 'trace-123')
      
      described_class.with_trace(trace) do
        expect(described_class.current_trace_id).to eq('trace-123')
      end
      
      expect(described_class.current_trace_id).to be_nil
    end
    
    it 'restores previous context after nested calls' do
      trace1 = double('trace1', id: 'trace-1')
      trace2 = double('trace2', id: 'trace-2')
      
      described_class.with_trace(trace1) do
        expect(described_class.current_trace_id).to eq('trace-1')
        
        described_class.with_trace(trace2) do
          expect(described_class.current_trace_id).to eq('trace-2')
        end
        
        expect(described_class.current_trace_id).to eq('trace-1')
      end
    end
  end
end
```

### 2.2 Testing the Helper Methods

```ruby
# spec/lib/langfuse_helper_spec.rb
require 'spec_helper'

RSpec.describe LangfuseHelper do
  let(:dummy_class) { Class.new { include LangfuseHelper } }
  let(:helper) { dummy_class.new }
  
  describe '#with_trace' do
    it 'creates and updates a trace', :vcr do
      result = helper.with_trace(name: 'test-trace') do |trace|
        expect(trace.id).not_to be_nil
        'test result'
      end
      
      expect(result).to eq('test result')
    end
    
    it 'handles errors and flushes' do
      expect(Langfuse).to receive(:flush)
      
      expect {
        helper.with_trace(name: 'error-trace') do
          raise 'test error'
        end
      }.to raise_error('test error')
    end
  end
  
  describe '#with_generation' do
    it 'tracks LLM generation with timing', :vcr do
      Timecop.freeze do
        start_time = Time.now
        
        result = helper.with_generation(
          name: 'test-gen',
          trace_id: 'trace-123',
          model: 'gpt-3.5-turbo',
          input: { prompt: 'test' }
        ) do |gen|
          sleep(0.1)
          'generated text'
        end
        
        expect(result).to eq('generated text')
        expect(Time.now - start_time).to be >= 0.1
      end
    end
  end
end
```

## 3. Integration Testing

### 3.1 Testing with Real API Calls

Create a test script that exercises the full functionality:

```ruby
# test/integration/full_flow_test.rb
require 'langfuse'

# Configure with real credentials for testing
Langfuse.configure do |config|
  config.public_key = ENV['LANGFUSE_TEST_PUBLIC_KEY']
  config.secret_key = ENV['LANGFUSE_TEST_SECRET_KEY']
  config.debug = true
end

class IntegrationTest
  include LangfuseHelper
  
  def run_full_flow
    with_context_trace(name: 'integration-test', user_id: 'test-user') do |trace|
      puts "Created trace: #{trace.id}"
      
      with_context_span(name: 'process-input') do |span|
        puts "Created span: #{span.id}"
        
        with_generation(
          name: 'test-generation',
          trace_id: trace.id,
          parent_id: span.id,
          model: 'gpt-3.5-turbo',
          input: [
            { role: 'system', content: 'You are a helpful assistant' },
            { role: 'user', content: 'Hello!' }
          ]
        ) do |gen|
          puts "Created generation: #{gen.id}"
          'Hello! How can I help you today?'
        end
        
        score_trace(
          trace_id: trace.id,
          name: 'response_quality',
          value: 0.95,
          comment: 'Good response'
        )
      end
    end
  end
  
  def test_error_handling
    with_context_trace(name: 'error-test') do |trace|
      with_context_span(name: 'error-span') do
        raise 'Intentional error for testing'
      end
    end
  rescue => e
    puts "Successfully caught error: #{e.message}"
  end
end

# Run the tests
test = IntegrationTest.new
test.run_full_flow
test.test_error_handling
```

### 3.2 Testing Rails Integration

Create a small Rails application for testing the Rails integration:

```ruby
# test/rails_app/config/application.rb
require 'rails'
require 'action_controller/railtie'
require 'langfuse'

class TestApp < Rails::Application
  config.secret_key_base = 'test'
  
  # Initialize configuration defaults
  config.load_defaults 7.0
  
  # Configure Langfuse
  initializer 'langfuse.configure' do
    Langfuse.configure do |config|
      config.public_key = ENV['LANGFUSE_TEST_PUBLIC_KEY']
      config.secret_key = ENV['LANGFUSE_TEST_SECRET_KEY']
      config.debug = true
    end
  end
end

# test/rails_app/app/controllers/test_controller.rb
class TestController < ActionController::Base
  include LangfuseHelper
  
  def index
    with_context_trace(name: 'rails-request', user_id: 'test-user') do |trace|
      ActiveSupport::Notifications.instrument('langfuse.span', name: 'process-request') do
        render plain: 'OK'
      end
    end
  end
end
```

## 4. Manual Testing Script

Create a comprehensive manual testing script:

```ruby
#!/usr/bin/env ruby
# test/manual_test.rb

require 'bundler/setup'
require 'langfuse'
require_relative '../lib/langfuse_helper'
require_relative '../lib/langfuse_context'

class ManualTest
  include LangfuseHelper
  
  def initialize
    Langfuse.configure do |config|
      config.public_key = ENV['LANGFUSE_TEST_PUBLIC_KEY']
      config.secret_key = ENV['LANGFUSE_TEST_SECRET_KEY']
      config.debug = true
      config.batch_size = 1  # For immediate feedback
    end
  end
  
  def run_all_tests
    test_basic_trace
    test_nested_spans
    test_generation
    test_error_handling
    test_scoring
    test_batch_operations
  end
  
  private
  
  def test_basic_trace
    puts "\n=== Testing Basic Trace ==="
    with_trace(name: 'manual-test') do |trace|
      puts "Created trace: #{trace.id}"
      'test result'
    end
  end
  
  def test_nested_spans
    puts "\n=== Testing Nested Spans ==="
    with_context_trace(name: 'nested-test') do |trace|
      puts "Created trace: #{trace.id}"
      
      with_context_span(name: 'parent-span') do |parent|
        puts "Created parent span: #{parent.id}"
        
        with_context_span(name: 'child-span') do |child|
          puts "Created child span: #{child.id}"
          'nested result'
        end
      end
    end
  end
  
  def test_generation
    puts "\n=== Testing Generation ==="
    with_context_trace(name: 'generation-test') do |trace|
      with_generation(
        name: 'test-gen',
        trace_id: trace.id,
        model: 'gpt-3.5-turbo',
        input: { prompt: 'Hello!' }
      ) do |gen|
        puts "Created generation: #{gen.id}"
        'Hello there!'
      end
    end
  end
  
  def test_error_handling
    puts "\n=== Testing Error Handling ==="
    begin
      with_context_trace(name: 'error-test') do
        raise 'Test error'
      end
    rescue => e
      puts "Successfully caught error: #{e.message}"
    end
  end
  
  def test_scoring
    puts "\n=== Testing Scoring ==="
    with_trace(name: 'score-test') do |trace|
      score_trace(
        trace_id: trace.id,
        name: 'test_score',
        value: 0.95,
        comment: 'Test scoring'
      )
      puts "Added score to trace: #{trace.id}"
    end
  end
  
  def test_batch_operations
    puts "\n=== Testing Batch Operations ==="
    Langfuse.configure { |c| c.batch_size = 5 }
    
    5.times do |i|
      with_trace(name: "batch-test-#{i}") do |trace|
        puts "Created trace #{i}: #{trace.id}"
      end
    end
    
    Langfuse.flush
    puts "Flushed batch operations"
  ensure
    Langfuse.configure { |c| c.batch_size = 1 }
  end
end

if __FILE__ == $0
  puts "Starting manual tests..."
  ManualTest.new.run_all_tests
  puts "\nAll manual tests completed!"
end
```

## 5. Running the Tests

### 5.1 Unit Tests

```bash
# Run all unit tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/lib/langfuse_helper_spec.rb

# Run with coverage report
COVERAGE=true bundle exec rspec
```

### 5.2 Integration Tests

```bash
# Set up test credentials
export LANGFUSE_TEST_PUBLIC_KEY='pk-lf-...'
export LANGFUSE_TEST_SECRET_KEY='sk-lf-...'

# Run integration test
ruby test/integration/full_flow_test.rb
```

### 5.3 Manual Tests

```bash
# Run manual test script
ruby test/manual_test.rb
```

## 6. Verifying Results

After running the tests:

1. Check the Langfuse dashboard to verify:
   - Traces are being created with correct hierarchy
   - Spans are properly nested
   - Generations include all required information
   - Errors are properly captured and reported
   - Scores are being recorded

2. Review the test coverage report:
   ```bash
   open coverage/index.html
   ```

3. Check code quality:
   ```bash
   bundle exec rubocop
   ```

## 7. Common Issues and Debugging

### 7.1 API Connection Issues

If you're having trouble connecting to the Langfuse API:

```ruby
Langfuse.configure do |config|
  config.debug = true
  config.logger = Logger.new(STDOUT)
end
```

### 7.2 Thread Safety Testing

To test thread safety of the context manager:

```ruby
require 'concurrent'

def test_thread_safety
  threads = 10.times.map do |i|
    Thread.new do
      with_context_trace(name: "thread-#{i}") do |trace|
        with_context_span(name: "span-#{i}") do |span|
          sleep(rand)  # Simulate work
          puts "Thread #{i}: trace=#{LangfuseContext.current_trace_id} span=#{LangfuseContext.current_span_id}"
        end
      end
    end
  end
  
  threads.each(&:join)
end
```

### 7.3 Memory Leak Testing

To check for memory leaks:

```ruby
require 'memory_profiler'

report = MemoryProfiler.report do
  1000.times do
    with_context_trace(name: 'memory-test') do |trace|
      with_context_span(name: 'test-span') do |span|
        # Do work
      end
    end
  end
end

report.pretty_print
```

## 8. Pre-release Checklist

Before releasing the gem:

- [ ] All unit tests pass
- [ ] Integration tests pass
- [ ] Manual tests completed successfully
- [ ] Code coverage is above 90%
- [ ] No rubocop violations
- [ ] Documentation is up to date
- [ ] CHANGELOG.md is updated
- [ ] Version number is updated
- [ ] Git tags are set
- [ ] Dependencies are properly specified
- [ ] License file is present

## 9. Next Steps

After completing these tests:

1. Address any issues found during testing
2. Update documentation based on testing insights
3. Create example applications demonstrating different use cases
4. Prepare release notes
5. Consider creating a test suite for users to validate their integrations

Remember to maintain these tests and expand them as new features are added to the SDK. 