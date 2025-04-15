#!/usr/bin/env ruby
# typed: false
require 'bundler/setup'
require 'langfuse'
require_relative '../../lib/langfuse_helper'
require_relative '../../lib/langfuse_context'

# Configure with real credentials for testing
Langfuse.configure do |config|
  config.public_key = ENV['LANGFUSE_TEST_PUBLIC_KEY']
  config.secret_key = ENV['LANGFUSE_TEST_SECRET_KEY']
  config.debug = true
  config.batch_size = 1 # For immediate feedback
end

class IntegrationTest
  include LangfuseHelper

  def run_full_flow
    puts "\n=== Running Full Flow Test ==="
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
        puts 'Added score to trace'
      end
    end
    puts 'Full flow completed successfully'
  end

  def test_error_handling
    puts "\n=== Testing Error Handling ==="
    begin
      with_context_trace(name: 'error-test') do |trace|
        puts "Created error test trace: #{trace.id}"
        with_context_span(name: 'error-span') do
          raise 'Intentional error for testing'
        end
      end
    rescue StandardError => e
      puts "Successfully caught error: #{e.message}"
    end
  end

  def test_batch_operations
    puts "\n=== Testing Batch Operations ==="
    # Configure for batch operations
    Langfuse.configure { |c| c.batch_size = 5 }

    traces = []
    5.times do |i|
      with_trace(name: "batch-test-#{i}") do |trace|
        traces << trace.id
        puts "Created trace #{i}: #{trace.id}"
      end
    end

    Langfuse.flush
    puts 'Flushed batch operations'

    # Reset configuration
    Langfuse.configure { |c| c.batch_size = 1 }
  end

  def run_all_tests
    if ENV['LANGFUSE_TEST_PUBLIC_KEY'].nil? || ENV['LANGFUSE_TEST_SECRET_KEY'].nil?
      puts 'Error: Please set LANGFUSE_TEST_PUBLIC_KEY and LANGFUSE_TEST_SECRET_KEY environment variables'
      exit 1
    end

    puts 'Starting integration tests...'
    run_full_flow
    test_error_handling
    test_batch_operations
    puts "\nAll integration tests completed!"
  rescue StandardError => e
    puts "Error during integration tests: #{e.message}"
    puts e.backtrace
    exit 1
  end
end

IntegrationTest.new.run_all_tests if __FILE__ == $0
