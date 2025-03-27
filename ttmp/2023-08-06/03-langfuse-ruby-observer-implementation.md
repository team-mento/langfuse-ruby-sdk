# Langfuse Ruby Client Implementation

This document provides a concrete implementation of the Langfuse Ruby client using the hybrid approach combining in-memory collection with Sidekiq background processing. This implementation balances performance, reliability, and seamless integration with Rails applications.

## 1. Overview

The implementation follows these design principles:

1. In-memory collection for low latency
2. Thread-safety using mutexes
3. Configurable batch sizes and flush intervals
4. Sidekiq workers for reliable processing
5. Robust error handling with retries
6. Dead letter queues for failed events
7. Graceful shutdown hooks

## 2. Core Implementation

### 2.1 Langfuse Client Class

```ruby
# lib/langfuse.rb
require 'securerandom'
require 'singleton'
require 'json'
require 'net/http'
require 'uri'

class Langfuse
  include Singleton

  attr_reader :config

  def initialize
    @events = []
    @mutex = Mutex.new
    @config = Config.new
    
    # Start periodic flusher if in server context
    schedule_periodic_flush if defined?(Rails) && Rails.server?
    
    # Register shutdown hook
    at_exit { flush }
  end
  
  # Configure the client
  def configure
    yield @config if block_given?
    self
  end
  
  # Create a trace
  def trace(params = {})
    id = params[:id] || SecureRandom.uuid
    timestamp = params[:timestamp] || Time.now.utc
    
    event = {
      id: SecureRandom.uuid,
      type: 'trace-create',
      timestamp: timestamp.iso8601(3),
      body: params.merge(id: id)
    }
    
    enqueue_event(event)
    Trace.new(self, id, params)
  end
  
  # Create a span
  def span(params = {})
    id = params[:id] || SecureRandom.uuid
    trace_id = params[:trace_id]
    
    unless trace_id
      raise ArgumentError, "trace_id is required when creating a span"
    end
    
    timestamp = params[:start_time] || Time.now.utc
    
    event = {
      id: SecureRandom.uuid,
      type: 'span-create',
      timestamp: timestamp.iso8601(3),
      body: params.merge(id: id, traceId: trace_id)
    }
    
    enqueue_event(event)
    Span.new(self, id, params)
  end
  
  # Create a generation
  def generation(params = {})
    id = params[:id] || SecureRandom.uuid
    trace_id = params[:trace_id]
    
    unless trace_id
      raise ArgumentError, "trace_id is required when creating a generation"
    end
    
    timestamp = params[:start_time] || Time.now.utc
    
    event = {
      id: SecureRandom.uuid,
      type: 'generation-create',
      timestamp: timestamp.iso8601(3),
      body: params.merge(id: id, traceId: trace_id)
    }
    
    enqueue_event(event)
    Generation.new(self, id, params)
  end
  
  # Create an event
  def event(params = {})
    id = params[:id] || SecureRandom.uuid
    trace_id = params[:trace_id]
    
    unless trace_id
      raise ArgumentError, "trace_id is required when creating an event"
    end
    
    timestamp = params[:start_time] || Time.now.utc
    
    event = {
      id: SecureRandom.uuid,
      type: 'event-create',
      timestamp: timestamp.iso8601(3),
      body: params.merge(id: id, traceId: trace_id)
    }
    
    enqueue_event(event)
    Event.new(self, id, params)
  end
  
  # Create a score
  def score(params = {})
    id = params[:id] || SecureRandom.uuid
    trace_id = params[:trace_id]
    
    unless trace_id
      raise ArgumentError, "trace_id is required when creating a score"
    end
    
    event = {
      id: SecureRandom.uuid,
      type: 'score-create',
      timestamp: Time.now.utc.iso8601(3),
      body: params.merge(id: id, traceId: trace_id)
    }
    
    enqueue_event(event)
    Score.new(self, id, params)
  end
  
  # Update a span
  def update_span(id, params = {})
    trace_id = params[:trace_id]
    
    unless trace_id
      raise ArgumentError, "trace_id is required when updating a span"
    end
    
    event = {
      id: SecureRandom.uuid,
      type: 'span-update',
      timestamp: Time.now.utc.iso8601(3),
      body: params.merge(id: id, traceId: trace_id)
    }
    
    enqueue_event(event)
  end
  
  # Update a generation
  def update_generation(id, params = {})
    trace_id = params[:trace_id]
    
    unless trace_id
      raise ArgumentError, "trace_id is required when updating a generation"
    end
    
    event = {
      id: SecureRandom.uuid,
      type: 'generation-update',
      timestamp: Time.now.utc.iso8601(3),
      body: params.merge(id: id, traceId: trace_id)
    }
    
    enqueue_event(event)
  end
  
  # Flush events to Langfuse API
  def flush
    events_to_process = nil
    
    @mutex.synchronize do
      events_to_process = @events.dup
      @events.clear
    end
    
    unless events_to_process.empty?
      if defined?(Sidekiq)
        LangfuseBatchWorker.perform_async(events_to_process, @config.to_h)
      else
        # Fallback to synchronous processing if Sidekiq is not available
        api_client = ApiClient.new(@config)
        api_client.ingest(events_to_process)
      end
    end
  end
  
  private
  
  def enqueue_event(event)
    should_flush = false
    
    @mutex.synchronize do
      @events << event
      should_flush = @events.size >= @config.batch_size
    end
    
    flush if should_flush
  end
  
  def schedule_periodic_flush
    Thread.new do
      loop do
        sleep @config.flush_interval
        flush
      rescue => e
          Rails.logger.error("Error in Langfuse flush thread: #{e.message}")
          sleep 1 # Avoid tight loop if there's a persistent error
          retry
      end
    end
  end
end
```

### 2.2 Configuration Class

```ruby
# lib/langfuse/config.rb
class Langfuse
  class Config
    attr_accessor :host, :public_key, :secret_key, :batch_size, :flush_interval
    
    def initialize
      @host = ENV.fetch('LANGFUSE_HOST', 'https://us.cloud.langfuse.com')
      @public_key = ENV['LANGFUSE_PUBLIC_KEY']
      @secret_key = ENV['LANGFUSE_SECRET_KEY']
      @batch_size = ENV.fetch('LANGFUSE_BATCH_SIZE', 10).to_i
      @flush_interval = ENV.fetch('LANGFUSE_FLUSH_INTERVAL', 60).to_i
    end
    
    def to_h
      {
        host: @host,
        public_key: @public_key,
        secret_key: @secret_key,
        batch_size: @batch_size,
        flush_interval: @flush_interval
      }
    end
  end
end
```

### 2.3 Model Classes

```ruby
# lib/langfuse/models.rb
class Langfuse
  class BaseModel
    attr_reader :id
    
    def initialize(client, id, params = {})
      @client = client
      @id = id
      @params = params
    end
  end
  
  class Trace < BaseModel
    attr_accessor :name, :user_id, :metadata, :tags
    
    def span(params = {})
      @client.span(params.merge(trace_id: @id))
    end
    
    def generation(params = {})
      @client.generation(params.merge(trace_id: @id))
    end
    
    def event(params = {})
      @client.event(params.merge(trace_id: @id))
    end
    
    def score(params = {})
      @client.score(params.merge(trace_id: @id))
    end
  end
  
  class Span < BaseModel
    attr_accessor :name, :level, :metadata, :input, :output
    
    def end(params = {})
      @client.update_span(@id, params.merge(
        trace_id: @params[:trace_id],
        end_time: Time.now.utc
      ))
      self
    end
    
    def child_span(params = {})
      @client.span(params.merge(
        trace_id: @params[:trace_id],
        parent_observation_id: @id
      ))
    end
  end
  
  class Generation < BaseModel
    attr_accessor :name, :model, :model_parameters, :input, :output, :usage
    
    def end(params = {})
      @client.update_generation(@id, params.merge(
        trace_id: @params[:trace_id],
        end_time: Time.now.utc
      ))
      self
    end
  end
  
  class Event < BaseModel
    attr_accessor :name, :metadata, :input, :output
  end
  
  class Score < BaseModel
    attr_accessor :name, :value, :comment
  end
  
  # Usage model for token counts
  class Usage
    attr_accessor :input, :output, :total, :unit, :input_cost, :output_cost, :total_cost
    
    def initialize(params = {})
      @input = params[:input]
      @output = params[:output]
      @total = params[:total]
      @unit = params[:unit] || 'TOKENS'
      @input_cost = params[:input_cost]
      @output_cost = params[:output_cost]
      @total_cost = params[:total_cost]
    end
    
    def to_h
      {
        input: @input,
        output: @output,
        total: @total,
        unit: @unit,
        inputCost: @input_cost,
        outputCost: @output_cost,
        totalCost: @total_cost
      }.compact
    end
  end
end
```

### 2.4 API Client

```ruby
# lib/langfuse/api_client.rb
class Langfuse
  class ApiClient
    attr_reader :config
    
    def initialize(config)
      @config = config
    end
    
    def ingest(events)
      uri = URI.parse("#{@config[:host]}/api/public/ingestion")
      
      request = Net::HTTP::Post.new(uri.path)
      request.content_type = 'application/json'
      request.basic_auth(@config[:public_key], @config[:secret_key])
      
      request.body = {
        batch: events
      }.to_json
      
      response = nil
      
      begin
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
          http.read_timeout = 10  # 10 seconds
          response = http.request(request)
        end
        
        case response
        when Net::HTTPSuccess
          JSON.parse(response.body)
        else
          raise "API error: #{response.code} #{response.message}"
        end
      rescue => e
        Rails.logger.error("Langfuse API error: #{e.message}") if defined?(Rails)
        raise
      end
    end
  end
end
```

### 2.5 Sidekiq Worker

```ruby
# app/workers/langfuse_batch_worker.rb
class LangfuseBatchWorker
  include Sidekiq::Worker
  
  sidekiq_options retry: 3, 
                  dead: false, 
                  queue: 'langfuse',
                  backtrace: true
  
  def perform(events, config)
    # Get the current retry count
    retry_count = 0
    if defined?(Sidekiq::RetryJobs)
      retry_count = Sidekiq::RetryJobs.job_retry_count(Sidekiq.dump_json(self)) rescue 0
    end
    
    begin
      api_client = Langfuse::ApiClient.new(config.transform_keys(&:to_sym))
      response = api_client.ingest(events)
      
      # Log any partial failures
      if response && response["errors"] && !response["errors"].empty?
        response["errors"].each do |error|
          Rails.logger.error("Langfuse API error for event #{error['id']}: #{error['message']}")
        end
      end
      
    rescue => e
      Rails.logger.error("Langfuse API request failed: #{e.message}")
      
      # If we've retried too many times, store in dead letter queue
      if retry_count >= 3
        store_failed_events(events)
      else
        # Will be retried automatically by Sidekiq with exponential backoff
        raise
      end
    end
  end
  
  private
  
  def store_failed_events(events)
    # Store in Redis for later inspection/retry
    events.each do |event|
      begin
        Sidekiq.redis do |redis|
          redis.rpush("langfuse:failed_events", event.to_json)
        end
      rescue => e
        Rails.logger.error("Failed to store failed event: #{e.message}")
      end
    end
  end
end
```

### 2.6 Rails Initializer

```ruby
# config/initializers/langfuse.rb
require 'langfuse'

Langfuse.instance.configure do |config|
  # Uncomment to override environment variables
  # config.host = 'https://eu.langfuse.com' 
  # config.public_key = 'your-public-key'
  # config.secret_key = 'your-secret-key'
  
  # Batch settings
  config.batch_size = 10 
  config.flush_interval = 30 # seconds
end

# Register shutdown hook to ensure all events are sent
at_exit do
  Langfuse.instance.flush
end
```

## 3. Usage Examples

### 3.1 Basic Usage

```ruby
# Get the singleton instance
langfuse = Langfuse.instance

# Create a trace
trace = langfuse.trace(
  name: "user-query",
  user_id: current_user.id,
  metadata: { session_id: request.session.id }
)

# Create a span
span = trace.span(
  name: "process-query",
  level: "DEFAULT",
  input: { query: "What is the weather today?" }
)

# Record an LLM generation
generation = trace.generation(
  name: "llm-response",
  model: "gpt-3.5-turbo",
  model_parameters: {
    temperature: 0.7,
    max_tokens: 150
  },
  input: [
    { role: "system", content: "You are a helpful assistant" },
    { role: "user", content: "What is the weather today?" }
  ]
)

# Process the request
response = call_openai_api(generation.input)

# Update generation with results
generation.output = response.choices.first.message
generation.usage = Langfuse::Usage.new(
  input: response.usage.prompt_tokens,
  output: response.usage.completion_tokens,
  total: response.usage.total_tokens
)
generation.end

# End the span
span.output = { processed_response: response.choices.first.message }
span.end

# Add a score
trace.score(
  name: "relevance",
  value: 0.95,
  comment: "Response was highly relevant to the query"
)
```

### 3.2 With Rails Controllers

```ruby
class QueriesController < ApplicationController
  def create
    # Start tracing
    trace = Langfuse.instance.trace(
      name: "api-query",
      user_id: current_user.id
    )
    
    span = trace.span(
      name: "process-query",
      input: params[:query]
    )
    
    # Process query
    result = process_query(params[:query])
    
    # End span
    span.output = result
    span.end
    
    render json: result
  end
  
  private
  
  def process_query(query)
    # Implementation
  end
end
```

### 3.3 With ActiveSupport::Notifications Integration

```ruby
# config/initializers/langfuse_notifications.rb
ActiveSupport::Notifications.subscribe(/langfuse/) do |name, start, finish, id, payload|
  case name
  when 'langfuse.trace'
    Langfuse.instance.trace(payload)
  when 'langfuse.span'
    Langfuse.instance.span(payload)
  when 'langfuse.generation'
    Langfuse.instance.generation(payload)
  when 'langfuse.event'
    Langfuse.instance.event(payload)
  when 'langfuse.score'
    Langfuse.instance.score(payload)
  end
end

# Usage in application code
ActiveSupport::Notifications.instrument('langfuse.trace', {
  name: 'user-login',
  metadata: { user_id: current_user.id }
})
```

## 4. Handling Errors and Recovery

### 4.1 Retry Failed Events Manually

```ruby
# lib/tasks/langfuse.rake
namespace :langfuse do
  desc "Retry failed Langfuse events"
  task retry_failed_events: :environment do
    count = 0
    
    Sidekiq.redis do |redis|
      while event_json = redis.lpop("langfuse:failed_events")
        begin
          event = JSON.parse(event_json)
          LangfuseBatchWorker.perform_async([event], Langfuse.instance.config.to_h)
          count += 1
        rescue => e
          puts "Error processing event: #{e.message}"
          # Put it back at the end of the list
          redis.rpush("langfuse:failed_events", event_json)
        end
      end
    end
    
    puts "Requeued #{count} failed events"
  end
end
```

### 4.2 Monitor Health

```ruby
# app/controllers/admin/langfuse_controller.rb
module Admin
  class LangfuseController < ApplicationController
    before_action :authenticate_admin!
    
    def index
      Sidekiq.redis do |redis|
        @failed_events_count = redis.llen("langfuse:failed_events")
      end
      
      @stats = {
        pending_events: Langfuse.instance.instance_variable_get(:@events).size,
        failed_events: @failed_events_count
      }
      
      render json: @stats
    end
    
    def retry_failed
      Rake::Task['langfuse:retry_failed_events'].invoke
      
      redirect_to admin_langfuse_path, notice: "Failed events have been requeued"
    end
  end
end
```

## 5. Testing

### 5.1 Test Helpers

```ruby
# lib/langfuse/test_helpers.rb
class Langfuse
  module TestHelpers
    def self.included(base)
      base.before(:each) do
        Langfuse.instance.instance_variable_set(:@events, [])
      end
      
      base.after(:each) do
        Langfuse.instance.instance_variable_set(:@events, [])
      end
    end
    
    def langfuse_events
      Langfuse.instance.instance_variable_get(:@events)
    end
    
    def last_langfuse_event
      langfuse_events.last
    end
    
    def expect_langfuse_event(type)
      expect(langfuse_events.any? { |e| e[:type] == type }).to be true
    end
  end
end

# In your tests
RSpec.configure do |config|
  config.include Langfuse::TestHelpers, type: :request
end
```

### 5.2 Example Test

```ruby
RSpec.describe "LLM Processing", type: :request do
  it "tracks generation in Langfuse" do
    post "/api/queries", params: { query: "What is the weather?" }
    
    expect(response).to be_successful
    expect_langfuse_event('trace-create')
    expect_langfuse_event('generation-create')
    
    generation = langfuse_events.find { |e| e[:type] == 'generation-create' }
    expect(generation[:body][:name]).to eq('llm-response')
  end
end
```

## 6. Performance Considerations

### 6.1 Memory Usage

The in-memory event queue could potentially grow large if events are generated faster than they can be flushed. To prevent excessive memory usage:

1. Set a reasonable batch size (10-50 events)
2. Configure a shorter flush interval for high-volume applications 
3. Monitor the queue size in production

### 6.2 Concurrency

The implementation is thread-safe, but keep in mind:

1. The mutex around the event queue could become a bottleneck in high-concurrency scenarios
2. The background flush thread uses minimal CPU due to Ruby's GVL
3. For very high-volume applications, consider using the Redis-backed approach instead

### 6.3 Connection Pooling

For high-volume applications, add connection pooling to the API client:

```ruby
def initialize(config)
  @config = config
  @http_pool = ConnectionPool.new(size: 5, timeout: 5) do
    Net::HTTP.new(URI.parse(@config[:host]).host, URI.parse(@config[:host]).port)
  end
end

def ingest(events)
  uri = URI.parse("#{@config[:host]}/api/public/ingestion")
  
  request = Net::HTTP::Post.new(uri.path)
  request.content_type = 'application/json'
  request.basic_auth(@config[:public_key], @config[:secret_key])
  
  request.body = {
    batch: events
  }.to_json
  
  @http_pool.with do |http|
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = 10
    response = http.request(request)
    
    case response
    when Net::HTTPSuccess
      JSON.parse(response.body)
    else
      raise "API error: #{response.code} #{response.message}"
    end
  end
end
```

## 7. Deployment Checklist

- [ ] Add langfuse gem to Gemfile
- [ ] Create the initializer with your configuration
- [ ] Set environment variables for API keys
- [ ] Ensure Sidekiq is configured and running
- [ ] Add monitoring for failed events
- [ ] Set up a process to periodically retry failed events
- [ ] Validate thread safety in your application
- [ ] Test with realistic load before deploying to production 