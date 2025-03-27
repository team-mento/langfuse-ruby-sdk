#!/usr/bin/env ruby
require 'bundler/setup'
require 'langfuse'
require_relative '../lib/langfuse_helper'
require_relative '../lib/langfuse_context'
require 'memory_profiler'

class ManualTest
  include LangfuseHelper

  def initialize
    Langfuse.configure do |config|
      config.public_key = ENV['LANGFUSE_TEST_PUBLIC_KEY']
      config.secret_key = ENV['LANGFUSE_TEST_SECRET_KEY']
      config.debug = true
      config.batch_size = 1 # For immediate feedback
    end
  end

  def run_all_tests
    check_configuration
    test_basic_trace
    test_nested_spans
    test_generation
    test_error_handling
    test_scoring
    test_batch_operations
    test_thread_safety
    test_memory_usage
  end

  private

  def check_configuration
    puts "\n=== Checking Configuration ==="
    begin
      trace = Langfuse.trace(name: 'config-test', metadata: { test: true })
      Langfuse.flush
      puts "✓ Connection to Langfuse successful with trace ID: #{trace.id}"
    rescue StandardError => e
      puts "✗ Connection to Langfuse failed: #{e.message}"
      exit 1
    end
  end

  def test_basic_trace
    puts "\n=== Testing Basic Trace ==="
    with_trace(name: 'manual-test') do |trace|
      puts "Created trace: #{trace.id}"
      'test result'
    end
    puts '✓ Basic trace test completed'
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
    puts '✓ Nested spans test completed'
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
    puts '✓ Generation test completed'
  end

  def test_error_handling
    puts "\n=== Testing Error Handling ==="
    begin
      with_context_trace(name: 'error-test') do
        raise 'Test error'
      end
    rescue StandardError => e
      puts "Successfully caught error: #{e.message}"
      puts '✓ Error handling test completed'
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
    puts '✓ Scoring test completed'
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
    puts 'Flushed batch operations'
    puts '✓ Batch operations test completed'
  ensure
    Langfuse.configure { |c| c.batch_size = 1 }
  end

  def test_thread_safety
    puts "\n=== Testing Thread Safety ==="
    threads = 10.times.map do |i|
      Thread.new do
        with_context_trace(name: "thread-#{i}") do |_trace|
          with_context_span(name: "span-#{i}") do |_span|
            sleep(rand * 0.1) # Simulate work
            puts "Thread #{i}: trace=#{LangfuseContext.current_trace_id} span=#{LangfuseContext.current_span_id}"
          end
        end
      end
    end

    threads.each(&:join)
    puts '✓ Thread safety test completed'
  end

  def test_memory_usage
    puts "\n=== Testing Memory Usage ==="
    report = MemoryProfiler.report do
      100.times do
        with_context_trace(name: 'memory-test') do |_trace|
          with_context_span(name: 'test-span') do |_span|
            # Simulate work
            'test'
          end
        end
      end
    end

    puts "\nMemory Usage Summary:"
    puts "Total allocated: #{report.total_allocated} objects"
    puts "Total retained: #{report.total_retained} objects"
    puts '✓ Memory usage test completed'
  end
end

if __FILE__ == $0
  if ENV['LANGFUSE_TEST_PUBLIC_KEY'].nil? || ENV['LANGFUSE_TEST_SECRET_KEY'].nil?
    puts 'Error: Please set LANGFUSE_TEST_PUBLIC_KEY and LANGFUSE_TEST_SECRET_KEY environment variables'
    exit 1
  end

  puts 'Starting manual tests...'
  ManualTest.new.run_all_tests
  puts "\nAll manual tests completed successfully!"
end
