# Building a Langfuse Ruby Client: A Step-by-Step Tutorial

This tutorial will guide you through building a Ruby client for Langfuse, focusing on implementing background processing with Sidekiq for efficient API communication. We'll explain each concept as we go, making this accessible for developers new to Ruby concurrency, Sidekiq, and the Langfuse API.

## Table of Contents

1. [Understanding Langfuse](#understanding-langfuse)
2. [Setting Up Your Environment](#setting-up-your-environment)
3. [Basic Client Architecture](#basic-client-architecture)
4. [Implementing the Core Client](#implementing-the-core-client)
5. [Adding Background Processing with Sidekiq](#adding-background-processing-with-sidekiq)
6. [Error Handling and Retries](#error-handling-and-retries)
7. [Testing Your Implementation](#testing-your-implementation)
8. [Deploying to Production](#deploying-to-production)
9. [Advanced Topics](#advanced-topics)
10. [Complete Code Example](#complete-code-example)

## Understanding Langfuse

Langfuse is an observability platform designed specifically for LLM applications. It helps you track, monitor, and analyze your AI interactions through a data model that consists of:

- **Traces**: Top-level entities representing a complete user interaction or workflow
- **Spans**: Time-bounded operations within a trace (e.g., preprocessing, API calls)
- **Generations**: LLM text generation events with input/output and metrics
- **Events**: Point-in-time occurrences within a trace
- **Scores**: Numeric evaluations of quality or performance

The Langfuse API follows a batched ingestion pattern where multiple events are sent in a single HTTP request. This approach is more efficient than sending individual events, especially for applications with high throughput.

Let's examine a simplified version of the Langfuse ingestion API schema:

```yaml
# Simplified view of the API schema
batch:
  type: list<IngestionEvent>

IngestionEvent:
  discriminant: "type"
  union:
    trace-create: TraceEvent
    span-create: CreateSpanEvent
    span-update: UpdateSpanEvent
    generation-create: CreateGenerationEvent
    generation-update: UpdateGenerationEvent
    event-create: CreateEventEvent
    score-create: ScoreEvent

# Each event type has a common structure:
BaseEvent:
  properties:
    id: string  # Unique ID for the event
    timestamp: string  # ISO 8601 timestamp
    body: any  # The actual trace/span/generation/etc data
```

## Setting Up Your Environment

Before we begin coding, let's set up our environment. This tutorial assumes you're working in a Rails application, but the core concepts apply to any Ruby project.

1. First, add the required gems to your Gemfile:

```ruby
# Gemfile
gem 'sidekiq', '~> 6.5'  # For background processing
gem 'concurrent-ruby', '~> 1.2'  # For thread-safe data structures
```

2. Run `bundle install` to install the dependencies.

3. Make sure Sidekiq is configured to run in your environment:

```ruby
# config/sidekiq.yml
:queues:
  - default
  - langfuse
```

## Basic Client Architecture

Before diving into the code, let's understand the architecture we're building:

1. **In-Memory Collection**: Events are initially stored in memory for low latency
2. **Thread-Safe Buffer**: A mutex-protected array holds events before processing
3. **Periodic Flushing**: A background thread periodically sends events to the API
4. **Size-Based Flushing**: When enough events accumulate, they're sent immediately
5. **Background Processing**: Sidekiq workers handle the actual API communication
6. **Error Handling**: Failed events are retried with exponential backoff

This hybrid approach balances two key concerns:

- **Performance**: In-memory collection avoids the overhead of database/Redis operations for every event
- **Reliability**: Sidekiq ensures events are eventually processed, even if the application restarts

## Implementing the Core Client

Let's start by implementing the core client class. We'll build it step by step, explaining each component.

### Step 1: Create the Basic Structure

First, let's create the directory structure:

```
lib/
  langfuse/
    models/
      trace.rb
      span.rb
      generation.rb
      event.rb
      score.rb
      ingestion_event.rb
    api_client.rb
    batch_worker.rb
    client.rb
    configuration.rb
```

Now let's start with the configuration class, which will store API keys and settings:

```ruby
# lib/langfuse/configuration.rb
module Langfuse
  class Configuration
    attr_accessor :public_key, :secret_key, :host, 
                  :batch_size, :flush_interval, :debug

    def initialize
      # Default configuration with environment variable fallbacks
      @public_key = ENV['LANGFUSE_PUBLIC_KEY']
      @secret_key = ENV['LANGFUSE_SECRET_KEY']
      @host = ENV.fetch('LANGFUSE_HOST', 'https://cloud.langfuse.com')
      @batch_size = ENV.fetch('LANGFUSE_BATCH_SIZE', '10').to_i
      @flush_interval = ENV.fetch('LANGFUSE_FLUSH_INTERVAL', '60').to_i
      @debug = ENV.fetch('LANGFUSE_DEBUG', 'false') == 'true'
    end
  end
end
```

This configuration class follows Ruby conventions by using attribute accessors for settings and providing sensible defaults. Using environment variables for configuration makes it easier to adjust settings in different environments (development, staging, production) without code changes.

### Step 2: Implement the Models

Next, let's implement the core data models that match Langfuse's API schema:

```ruby
# lib/langfuse/models/ingestion_event.rb
require 'securerandom'

module Langfuse
  module Models
    class IngestionEvent
      attr_accessor :id, :type, :timestamp, :body, :metadata

      def initialize(type:, body:, metadata: nil)
        @id = SecureRandom.uuid
        @type = type
        @timestamp = Time.now.utc.iso8601(3)  # Millisecond precision
        @body = body
        @metadata = metadata
      end

      def to_h
        {
          id: @id,
          type: @type,
          timestamp: @timestamp,
          body: @body.respond_to?(:to_h) ? @body.to_h : @body,
          metadata: @metadata
        }.compact
      end
    end
  end
end
```

The `IngestionEvent` class wraps our data for the API. Each event needs a unique ID, a type (like 'trace-create'), a timestamp, and a body containing the actual data. The `to_h` method converts the object to a hash for JSON serialization.

Now, let's implement the Trace model as an example:

```ruby
# lib/langfuse/models/trace.rb
module Langfuse
  module Models
    class Trace
      attr_accessor :id, :name, :user_id, :input, :output, 
                    :session_id, :metadata, :tags, :public
      
      def initialize(attributes = {})
        attributes.each do |key, value|
          send("#{key}=", value) if respond_to?("#{key}=")
        end
        @id ||= SecureRandom.uuid
      end
      
      def to_h
        {
          id: @id,
          name: @name,
          userId: @user_id,
          input: @input,
          output: @output,
          sessionId: @session_id,
          metadata: @metadata,
          tags: @tags,
          public: @public
        }.compact
      end
    end
  end
end
```

This pattern of having a model class with attributes and a `to_h` method will be repeated for each entity type (Span, Generation, Event, Score). The key thing to notice is that we're transforming snake_case Ruby attributes to camelCase JSON properties, following Langfuse's API conventions.

### Step 3: Implement the Client Class

Now let's build the main client class that applications will interact with:

```ruby
# lib/langfuse/client.rb
require 'singleton'
require 'concurrent'

module Langfuse
  class Client
    include Singleton
    
    def initialize
      @config = Langfuse.configuration
      @events = Concurrent::Array.new  # Thread-safe array
      @mutex = Mutex.new  # For operations that need additional thread safety
      
      # Start periodic flusher only in server context
      schedule_periodic_flush if defined?(Rails) && Rails.server?
      
      # Register shutdown hook
      at_exit { flush }
    end
    
    def trace(attributes = {})
      trace = Models::Trace.new(attributes)
      event = Models::IngestionEvent.new(
        type: 'trace-create',
        body: trace
      )
      enqueue_event(event)
      trace
    end
    
    # Similar methods for span, generation, event, score...
    
    def flush
      events_to_process = nil
      
      # Atomically swap the events array to avoid race conditions
      @mutex.synchronize do
        events_to_process = @events.dup
        @events.clear
      end
      
      unless events_to_process.empty?
        # Convert objects to hashes for serialization
        event_hashes = events_to_process.map(&:to_h)
        
        # Send to background worker
        if defined?(Sidekiq)
          BatchWorker.perform_async(event_hashes)
        else
          # Fallback to synchronous processing
          ApiClient.new(@config).ingest(event_hashes)
        end
      end
    end
    
    private
    
    def enqueue_event(event)
      @events << event
      
      # Trigger immediate flush if batch size reached
      flush if @events.size >= @config.batch_size
    end
    
    def schedule_periodic_flush
      Thread.new do
        loop do
          sleep @config.flush_interval
          flush
        rescue => e
          Rails.logger.error("Error in Langfuse flush thread: #{e.message}")
          sleep 1  # Avoid tight loop on persistent errors
          retry
        end
      end
    end
  end
  
  # Configuration management
  class << self
    attr_writer :configuration
    
    def configuration
      @configuration ||= Configuration.new
    end
    
    def configure
      yield(configuration)
    end
    
    # Convenience delegators to the client instance
    def trace(...) = Client.instance.trace(...)
    def flush(...) = Client.instance.flush(...)
    # Add others as needed...
  end
end
```

Let's break down what's happening in this client class:

1. **Singleton Pattern**: We use Ruby's `Singleton` module to ensure there's only one client instance. This prevents duplicating event queues and background threads.

2. **Thread-Safe Collection**: We use `Concurrent::Array` from the concurrent-ruby gem, which is thread-safe. This prevents race conditions when multiple threads add events simultaneously.

3. **Event Creation**: Methods like `trace()` create model objects and wrap them in `IngestionEvent` objects before adding them to the queue.

4. **Periodic Flushing**: A background thread runs in server environments to periodically flush events. This ensures events get sent even if the batch size isn't reached.

5. **Size-Based Flushing**: When the event queue reaches a certain size, it's immediately flushed to prevent memory growth.

6. **Configuration**: Class-level methods let users configure the client with a block syntax.

## Adding Background Processing with Sidekiq

Now let's implement the Sidekiq worker that will handle the actual API communication:

```ruby
# lib/langfuse/batch_worker.rb
require 'sidekiq'

module Langfuse
  class BatchWorker
    include Sidekiq::Worker
    
    sidekiq_options queue: 'langfuse', retry: 5, backtrace: true
    
    # Custom retry delay logic (exponential backoff)
    sidekiq_retry_in do |count|
      10 * (count + 1)  # 10s, 20s, 30s, 40s, 50s
    end
    
    def perform(event_hashes)
      # Create API client
      api_client = ApiClient.new(Langfuse.configuration)
      
      begin
        response = api_client.ingest(event_hashes)
        
        # Check for partial failures
        if response && response["errors"]&.any?
          response["errors"].each do |error|
            logger.error("Langfuse API error for event #{error['id']}: #{error['message']}")
          end
        end
        
      rescue => e
        logger.error("Langfuse API request failed: #{e.message}")
        
        # Let Sidekiq handle the retry
        raise
      end
    end
  end
end
```

The Sidekiq worker does several important things:

1. **Queue Designation**: Events are processed in a dedicated 'langfuse' queue, which can be scaled independently.

2. **Retry Logic**: Failed jobs are retried up to 5 times with exponential backoff. This handles transient API failures.

3. **Error Handling**: We log both complete failures and partial failures (where some events in a batch succeeded and others failed).

4. **Exception Propagation**: By re-raising exceptions, we let Sidekiq handle the retry scheduling.

Now let's implement the API client that handles HTTP communication:

```ruby
# lib/langfuse/api_client.rb
require 'net/http'
require 'uri'
require 'json'

module Langfuse
  class ApiClient
    def initialize(config)
      @config = config
    end
    
    def ingest(events)
      uri = URI.parse("#{@config.host}/api/public/ingestion")
      
      # Build the request
      request = Net::HTTP::Post.new(uri.path)
      request.content_type = 'application/json'
      request.basic_auth(@config.public_key, @config.secret_key)
      
      # Set the payload
      request.body = {
        batch: events
      }.to_json
      
      # Send the request
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.read_timeout = 10  # 10 seconds
      
      response = http.request(request)
      
      if response.code.to_i == 207  # Partial success
        JSON.parse(response.body)
      elsif response.code.to_i >= 200 && response.code.to_i < 300
        JSON.parse(response.body)
      else
        raise "API error: #{response.code} #{response.message}"
      end
    end
  end
end
```

The API client is responsible for:

1. **HTTP Request Formation**: Building a POST request with the proper authentication and JSON payload.

2. **Response Handling**: Parsing the JSON response and handling different status codes. Note that Langfuse uses HTTP 207 for partial success.

3. **Error Detection**: Raising exceptions for non-success responses to trigger retries.

## Error Handling and Retries

Let's dive deeper into error handling. In distributed systems, failures are inevitable, so we need robust error handling.

### Types of Failures

With Langfuse, we can encounter several types of failures:

1. **Network Issues**: Timeouts, connection errors, or DNS problems
2. **API Service Errors**: 5xx errors from the Langfuse API
3. **Authentication Errors**: Invalid API keys (401/403)
4. **Validation Errors**: Invalid data format (400)
5. **Partial Failures**: Some events in a batch succeed while others fail (207)

Our strategy for handling these varies:

- **Retryable Errors** (Network, 5xx): These are retried with exponential backoff
- **Non-Retryable Errors** (Auth, Validation): These are logged but not retried
- **Partial Failures**: Successful events are acknowledged, failed events are logged

Let's add a more sophisticated error handler to our worker:

```ruby
# Enhanced error handling in lib/langfuse/batch_worker.rb
def perform(event_hashes)
  api_client = ApiClient.new(Langfuse.configuration)
  
  begin
    response = api_client.ingest(event_hashes)
    
    # Check for partial failures
    if response && response["errors"]&.any?
      response["errors"].each do |error|
        logger.error("Langfuse API error for event #{error['id']}: #{error['message']}")
        
        # Store permanently failed events if needed
        if non_retryable_error?(error["status"])
          store_failed_event(event_hashes.find { |e| e[:id] == error["id"] }, error["message"])
        end
      end
    end
    
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED => e
    # Network errors - Sidekiq will retry
    logger.error("Langfuse network error: #{e.message}")
    raise
    
  rescue => e
    # Other errors
    logger.error("Langfuse API error: #{e.message}")
    
    # Check if it's the final retry
    if Sidekiq::RetryCount.for_job(self) >= self.class.sidekiq_options["retry"]
      # This is the final retry, store events for later inspection
      event_hashes.each do |event|
        store_failed_event(event, e.message)
      end
    else
      # Let Sidekiq retry
      raise
    end
  end
end

private

def non_retryable_error?(status)
  # 4xx errors except 429 (rate limit) are not retryable
  status >= 400 && status < 500 && status != 429
end

def store_failed_event(event, error)
  # Store in Redis for later inspection/retry
  Sidekiq.redis do |redis|
    redis.rpush("langfuse:failed_events", {
      event: event,
      error: error,
      timestamp: Time.now.utc.iso8601
    }.to_json)
  end
end
```

This enhanced error handling gives us:

1. **Error Classification**: We distinguish between retryable and non-retryable errors
2. **Dead Letter Queue**: Permanently failed events are stored in Redis for inspection
3. **Detailed Logging**: Error messages include event IDs and specific error details

## Concurrency in Ruby: A Brief Explanation

Since this pattern heavily relies on concurrency, let's briefly explain how concurrency works in Ruby:

Ruby uses a Global VM Lock (GVL), also known as the Global Interpreter Lock (GIL), which means that only one thread can execute Ruby code at a time. However, the GVL is released during I/O operations (like network requests), which means that I/O-bound tasks can still benefit from concurrency.

For our Langfuse client, this means:

1. Event collection uses a thread-safe data structure (`Concurrent::Array`) because multiple web requests might create events simultaneously.

2. The periodic flush happens in a background thread, but it doesn't block the main application when sleeping.

3. The actual API communication is handed off to Sidekiq, which uses separate processes that don't share the GVL with the main application.

This design leverages Ruby's concurrency model effectively:

- **Low Latency**: Event collection is fast because it just adds to an in-memory array
- **Non-Blocking**: The background flush thread mostly sleeps and only briefly acquires the GVL when flushing
- **Parallelism**: Sidekiq workers run in separate processes, providing true parallelism for API communication

## Testing Your Implementation

Let's add some tests to verify our implementation:

```ruby
# spec/lib/langfuse/client_spec.rb
require 'rails_helper'

RSpec.describe Langfuse::Client do
  before do
    # Clear events before each test
    Langfuse::Client.instance.instance_variable_set(:@events, Concurrent::Array.new)
  end
  
  describe "#trace" do
    it "creates a trace and adds an event to the queue" do
      client = Langfuse::Client.instance
      trace = client.trace(name: "test-trace")
      
      expect(trace.name).to eq("test-trace")
      expect(trace.id).not_to be_nil
      
      events = client.instance_variable_get(:@events)
      expect(events.size).to eq(1)
      expect(events.first.type).to eq("trace-create")
    end
  end
  
  describe "#flush" do
    it "sends events to the worker" do
      client = Langfuse::Client.instance
      client.trace(name: "test-trace")
      
      expect(Langfuse::BatchWorker).to receive(:perform_async).once
      client.flush
      
      # Queue should be empty after flush
      events = client.instance_variable_get(:@events)
      expect(events).to be_empty
    end
  end
end
```

For testing the BatchWorker, we can use Sidekiq's testing helpers:

```ruby
# spec/lib/langfuse/batch_worker_spec.rb
require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe Langfuse::BatchWorker do
  before do
    Sidekiq::Testing.fake!
  end
  
  after do
    Sidekiq::Worker.clear_all
  end
  
  it "processes a batch of events" do
    event_hashes = [
      {
        id: "123",
        type: "trace-create",
        timestamp: Time.now.utc.iso8601,
        body: { id: "456", name: "test-trace" }
      }
    ]
    
    # Mock the API client
    api_client = instance_double(Langfuse::ApiClient)
    expect(Langfuse::ApiClient).to receive(:new).and_return(api_client)
    expect(api_client).to receive(:ingest).with(event_hashes).and_return({"successes" => [{"id" => "123"}]})
    
    # Enqueue and process the job
    Langfuse::BatchWorker.perform_async(event_hashes)
    Langfuse::BatchWorker.drain
  end
  
  it "handles API errors" do
    event_hashes = [
      {
        id: "123",
        type: "trace-create",
        timestamp: Time.now.utc.iso8601,
        body: { id: "456", name: "test-trace" }
      }
    ]
    
    # Mock API error
    api_client = instance_double(Langfuse::ApiClient)
    expect(Langfuse::ApiClient).to receive(:new).and_return(api_client)
    expect(api_client).to receive(:ingest).and_raise("API error")
    
    # Job should be retried
    expect {
      Langfuse::BatchWorker.new.perform(event_hashes)
    }.to raise_error("API error")
  end
end
```

## Deploying to Production

When deploying to production, follow these best practices:

1. **Environment Variables**: Set API keys as environment variables rather than hardcoding them:
   ```ruby
   # config/initializers/langfuse.rb
   Langfuse.configure do |config|
     # Config is already set from environment variables by default
     # Adjust batch settings if needed
     config.batch_size = 20
     config.flush_interval = 30
   end
   ```

2. **Monitoring**: Add monitoring for Sidekiq queues and failed jobs:
   ```ruby
   # Add Prometheus/Datadog/NewRelic metrics for:
   # - Queue size
   # - Processing time
   # - Error rates
   ```

3. **Graceful Shutdown**: Ensure all pending events are flushed during deployment:
   ```ruby
   # Already handled by at_exit hook
   ```

4. **Rate Limiting**: Implement rate limiting if you generate many events:
   ```ruby
   # Consider adding a rate limiter to avoid overwhelming the API
   ```

## Advanced Topics

Here are some advanced topics to consider as your implementation matures:

### Connection Pooling

For high-volume applications, consider using a connection pool:

```ruby
# lib/langfuse/api_client.rb
require 'connection_pool'

module Langfuse
  class ApiClient
    def initialize(config)
      @config = config
      @pool = ConnectionPool.new(size: 5, timeout: 5) do
        http = Net::HTTP.new(URI.parse(@config.host).host, URI.parse(@config.host).port)
        http.use_ssl = URI.parse(@config.host).scheme == 'https'
        http.read_timeout = 10
        http
      end
    end
    
    def ingest(events)
      uri = URI.parse("#{@config.host}/api/public/ingestion")
      
      request = Net::HTTP::Post.new(uri.path)
      request.content_type = 'application/json'
      request.basic_auth(@config.public_key, @config.secret_key)
      
      request.body = {
        batch: events
      }.to_json
      
      @pool.with do |http|
        response = http.request(request)
        # Process response
      end
    end
  end
end
```

### Circuit Breaker

Consider adding a circuit breaker to prevent cascading failures:

```ruby
# Gemfile
gem 'circuitbox'

# lib/langfuse/api_client.rb
require 'circuitbox'

module Langfuse
  class ApiClient
    def initialize(config)
      @config = config
      @circuit = Circuitbox.circuit(:langfuse_api, 
        exceptions: [Net::OpenTimeout, Net::ReadTimeout],
        volume_threshold: 10,
        sleep_window: 30,
        time_window: 60
      )
    end
    
    def ingest(events)
      @circuit.run do
        # Original ingest code
      end
    end
  end
end
```

### ActiveSupport::Notifications Integration

For seamless integration with Rails applications:

```ruby
# config/initializers/langfuse_notifications.rb
ActiveSupport::Notifications.subscribe(/langfuse/) do |name, start, finish, id, payload|
  case name
  when 'langfuse.trace'
    Langfuse.trace(payload)
  when 'langfuse.span'
    Langfuse.span(payload)
  # etc.
  end
end

# Usage in application code
ActiveSupport::Notifications.instrument('langfuse.trace', {
  name: 'user-login',
  metadata: { user_id: current_user.id }
})
```

## Complete Code Example

For the complete implementation, please refer to the full code example in the repository. The key files are:

1. `lib/langfuse/client.rb`: The main client class
2. `lib/langfuse/models/*`: Data models for traces, spans, etc.
3. `lib/langfuse/batch_worker.rb`: Sidekiq worker for processing batches
4. `lib/langfuse/api_client.rb`: HTTP client for API communication
5. `lib/langfuse/configuration.rb`: Configuration management

## Conclusion

In this tutorial, we've built a robust Ruby client for Langfuse that efficiently handles event collection and processing. By combining in-memory buffering with Sidekiq background jobs, we've created a solution that's both performant and reliable.

Key takeaways:

1. **Hybrid Approach**: In-memory collection with background processing gives us the best of both worlds
2. **Thread Safety**: Careful design ensures our client works well in concurrent environments
3. **Error Handling**: Comprehensive error handling with retries ensures data reliability
4. **Configuration**: Flexible configuration options adapt to different environments

Remember that this implementation is just a starting point. As your application's needs evolve, you may need to adapt the client accordingly. Always monitor performance and reliability in production, and adjust settings like batch size and flush interval based on your specific workload.

Happy tracing with Langfuse! 