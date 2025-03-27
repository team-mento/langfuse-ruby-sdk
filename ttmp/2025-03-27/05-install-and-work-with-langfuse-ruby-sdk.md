# Using the Langfuse Ruby SDK in Your Project

This guide walks you through the process of integrating the locally developed Langfuse Ruby SDK into your project, configuring it, and building helpful utility methods to simplify working with nested spans and contexts.

## 1. Local Integration

### 1.1 Add the Gem to Your Project

Since you're working with a locally developed version of the gem (not from RubyGems.org), you'll need to reference it in your Gemfile using a path:

```ruby
# In your application's Gemfile
gem 'langfuse', path: '/path/to/langfuse-ruby-sdk'
```

Replace `/path/to/langfuse-ruby-sdk` with the actual path to your local langfuse-ruby-sdk directory.

### 1.2 Install Dependencies

Run Bundler to install the gem and its dependencies:

```bash
bundle install
```

## 2. Basic Configuration

### 2.1 Initialize the SDK

Create an initializer for Langfuse in your application. If you're using Rails, create a file at `config/initializers/langfuse.rb`:

```ruby
require 'langfuse'

Langfuse.configure do |config|
  # Your Langfuse credentials
  config.public_key = ENV['LANGFUSE_PUBLIC_KEY'] 
  config.secret_key = ENV['LANGFUSE_SECRET_KEY']
  
  # Optional configuration
  config.host = ENV.fetch('LANGFUSE_HOST', 'https://cloud.langfuse.com')
  config.batch_size = 20  # Events to buffer before sending
  config.flush_interval = 30  # Seconds between auto-flushes
  config.debug = Rails.env.development?  # Enable debug logging
end
```

If you're not using Rails, add this configuration code wherever you initialize your application.

### 2.2 Set Environment Variables

Make sure to set the required environment variables for your Langfuse credentials:

```bash
export LANGFUSE_PUBLIC_KEY=pk-lf-...
export LANGFUSE_SECRET_KEY=sk-lf-...
```

Or add them to your application's environment configuration.

## 3. Basic Usage

Here's a simple example of using the Langfuse SDK to track an LLM interaction:

```ruby
# Create a trace for the entire user interaction
trace = Langfuse.trace(
  name: "user-query",
  user_id: current_user.id,
  metadata: { source: "web-app" }
)

# Create a span for processing the query
span = Langfuse.span(
  name: "process-query",
  trace_id: trace.id,
  input: { query: "What is the weather today?" }
)

# Track an LLM generation
generation = Langfuse.generation(
  name: "llm-response",
  trace_id: trace.id,
  parent_observation_id: span.id,
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

# Process the request and get a response
response = call_llm_api(generation.input)

# Update the generation with the result
generation.output = response.content
generation.usage = Langfuse::Models::Usage.new(
  prompt_tokens: response.usage.prompt_tokens,
  completion_tokens: response.usage.completion_tokens,
  total_tokens: response.usage.total_tokens
)
Langfuse.update_generation(generation)

# Complete the span
span.output = { processed_response: response.content }
span.end_time = Time.now.utc
Langfuse.update_span(span)

# Manually flush events if needed
# Langfuse.flush
```

## 4. Building Helper Constructs

Now let's create some helper methods to simplify working with nested contexts and spans.

### 4.1 Create a Langfuse Helper Module

Create a module with helper methods to make Langfuse easier to use in your application:

```ruby
# lib/langfuse_helper.rb
module LangfuseHelper
  # Execute a block within the context of a span
  def with_span(name:, trace_id:, parent_id: nil, input: nil, **attributes)
    # Create the span
    span = Langfuse.span(
      name: name,
      trace_id: trace_id,
      parent_observation_id: parent_id,
      input: input,
      **attributes
    )
    
    start_time = Time.now
    result = nil
    error = nil
    
    begin
      # Execute the block with the span passed as argument
      result = yield(span)
      return result
    rescue => e
      # Capture any error
      error = e
      raise
    ensure
      # Always update the span with results
      span.end_time = Time.now.utc
      
      # Add output if there was a result
      span.output = result if result && !span.output
      
      # Add error information if there was an error
      if error
        span.level = "ERROR"
        span.status_message = error.message
        span.metadata ||= {}
        span.metadata[:error_backtrace] = error.backtrace.first(10) if error.backtrace
      end
      
      # Update the span
      Langfuse.update_span(span)
    end
  end
  
  # Execute a block within the context of an LLM generation
  def with_generation(name:, trace_id:, parent_id: nil, model:, input:, model_parameters: {}, **attributes)
    # Create the generation
    generation = Langfuse.generation(
      name: name,
      trace_id: trace_id,
      parent_observation_id: parent_id,
      model: model,
      input: input,
      model_parameters: model_parameters,
      **attributes
    )
    
    start_time = Time.now
    result = nil
    error = nil
    
    begin
      # Execute the block with the generation passed as argument
      result = yield(generation)
      return result
    rescue => e
      # Capture any error
      error = e
      raise
    ensure
      # Always update the generation with results
      generation.end_time = Time.now.utc
      
      # Add output if there was a result and it wasn't already set
      generation.output = result if result && !generation.output
      
      # Add error information if there was an error
      if error
        generation.level = "ERROR"
        generation.status_message = error.message
        generation.metadata ||= {}
        generation.metadata[:error_backtrace] = error.backtrace.first(10) if error.backtrace
      end
      
      # Update the generation
      Langfuse.update_generation(generation)
    end
  end
  
  # Execute a block within the context of a trace
  def with_trace(name:, user_id: nil, **attributes)
    # Create the trace
    trace = Langfuse.trace(
      name: name,
      user_id: user_id,
      **attributes
    )
    
    result = nil
    error = nil
    
    begin
      # Execute the block with the trace passed as argument
      result = yield(trace)
      return result
    rescue => e
      # Capture any error
      error = e
      raise
    ensure
      # Update trace output if available
      if result && !trace.output
        trace.output = result.is_a?(String) ? result : { result: result.to_s }
        
        # Create a new trace event to update the trace
        Langfuse.trace(
          id: trace.id,
          output: trace.output
        )
      end
      
      # Ensure all events are sent (only in case of error, otherwise let the automatic flushing handle it)
      Langfuse.flush if error
    end
  end
  
  # Add a score to a trace
  def score_trace(trace_id:, name:, value:, comment: nil)
    Langfuse.score(
      trace_id: trace_id,
      name: name,
      value: value,
      comment: comment
    )
  end
end
```

### 4.2 Using the Helper Methods

Now you can use these helper methods to simplify your code:

```ruby
# Include the helper module
include LangfuseHelper

# Use the helper methods
with_trace(name: "user-query", user_id: current_user.id) do |trace|
  with_span(name: "process-query", trace_id: trace.id) do |span|
    # Process the query
    query = "What is the weather today?"
    
    with_generation(
      name: "llm-response",
      trace_id: trace.id,
      parent_id: span.id,
      model: "gpt-3.5-turbo",
      input: [
        { role: "system", content: "You are a helpful assistant" },
        { role: "user", content: query }
      ],
      model_parameters: { temperature: 0.7 }
    ) do |generation|
      # Call your LLM API
      response = call_llm_api(generation.input)
      
      # Set usage information
      generation.usage = Langfuse::Models::Usage.new(
        prompt_tokens: response.usage.prompt_tokens,
        completion_tokens: response.usage.completion_tokens,
        total_tokens: response.usage.total_tokens
      )
      
      # Return the result (will be automatically set as output)
      response.content
    end
    
    # Score the trace
    score_trace(
      trace_id: trace.id,
      name: "relevance",
      value: 0.85,
      comment: "Response was accurate and helpful"
    )
  end
end
```

### 4.3 Adding Context Manager for Nested Spans

If you want to maintain a context for nested spans, you can implement a context manager:

```ruby
# lib/langfuse_context.rb
class LangfuseContext
  def self.current
    Thread.current[:langfuse_context] ||= {}
  end
  
  def self.current_trace_id
    current[:trace_id]
  end
  
  def self.current_span_id
    current[:span_id]
  end
  
  def self.with_trace(trace)
    old_context = current.dup
    begin
      Thread.current[:langfuse_context] = { trace_id: trace.id }
      yield
    ensure
      Thread.current[:langfuse_context] = old_context
    end
  end
  
  def self.with_span(span)
    old_context = current.dup
    begin
      Thread.current[:langfuse_context] = current.merge({ span_id: span.id })
      yield
    ensure
      Thread.current[:langfuse_context] = old_context
    end
  end
end
```

Now you can enhance your helper module to use this context:

```ruby
module LangfuseHelper
  # Create a trace and set it as the current context
  def with_context_trace(name:, user_id: nil, **attributes)
    trace = Langfuse.trace(
      name: name,
      user_id: user_id,
      **attributes
    )
    
    LangfuseContext.with_trace(trace) do
      yield(trace)
    end
  end
  
  # Create a span using the current trace context
  def with_context_span(name:, input: nil, **attributes)
    # Get trace_id from context
    trace_id = LangfuseContext.current_trace_id
    parent_id = LangfuseContext.current_span_id
    
    if trace_id.nil?
      raise "No trace context found. Make sure to call within with_context_trace"
    end
    
    span = Langfuse.span(
      name: name,
      trace_id: trace_id,
      parent_observation_id: parent_id,
      input: input,
      **attributes
    )
    
    LangfuseContext.with_span(span) do
      # Execute the block with the span
      with_span_implementation(span) { yield(span) }
    end
  end
  
  private
  
  def with_span_implementation(span)
    start_time = Time.now
    result = nil
    error = nil
    
    begin
      # Execute the block with the span passed as argument
      result = yield
      return result
    rescue => e
      # Capture any error
      error = e
      raise
    ensure
      # Update span
      span.end_time = Time.now.utc
      span.output = result if result && !span.output
      
      if error
        span.level = "ERROR"
        span.status_message = error.message
      end
      
      Langfuse.update_span(span)
    end
  end
end
```

### 4.4 Example Usage with Context

```ruby
include LangfuseHelper

# Use the context-aware helpers
with_context_trace(name: "user-request", user_id: user.id) do |trace|
  # All operations within this block have access to the trace context
  
  with_context_span(name: "extract-intent") do |span|
    # Process user intent
    intent = extract_intent(user_query)
    intent # Will be set as span output
  end
  
  with_context_span(name: "generate-response") do |span|
    # This span will be a sibling of the extract-intent span
    # Both nested under the same trace
    
    response = generate_response(user_query)
    response # Will be set as span output
  end
end
```

## 5. Integrating with Rails ActiveSupport::Notifications

If you're using Rails, you can integrate Langfuse with ActiveSupport::Notifications for a more declarative approach:

```ruby
# config/initializers/langfuse.rb (in addition to the configuration)

# Subscribe to langfuse notifications
ActiveSupport::Notifications.subscribe(/langfuse/) do |name, start, finish, id, payload|
  case name
  when 'langfuse.trace'
    Langfuse.trace(payload)
  when 'langfuse.span'
    # Set end_time based on notification timing if not provided
    payload[:end_time] ||= finish
    payload[:start_time] ||= start
    Langfuse.span(payload)
  when 'langfuse.generation'
    # Set end_time based on notification timing if not provided
    payload[:end_time] ||= finish
    payload[:start_time] ||= start
    Langfuse.generation(payload)
  when 'langfuse.score'
    Langfuse.score(payload)
  end
end
```

Then in your application code:

```ruby
# Instrument a trace
ActiveSupport::Notifications.instrument('langfuse.trace', {
  name: 'user-login',
  user_id: current_user.id
}) do |payload|
  # The operation to trace
  payload[:id] = SecureRandom.uuid # Capture the ID to use for child spans
  
  # Instrument a span
  ActiveSupport::Notifications.instrument('langfuse.span', {
    name: 'authenticate-user',
    trace_id: payload[:id],
    input: { username: params[:username] }
  }) do |span_payload|
    # Authentication logic
    # The timing will be automatically captured
  end
end
```

## 6. Debugging and Development Tips

### 6.1 Enable Debug Logging

To help with troubleshooting during development:

```ruby
Langfuse.configure do |config|
  # ... other config
  config.debug = true
end
```

### 6.2 Manual Flush for Testing

When testing or debugging, you might want to manually flush events:

```ruby
# Force a flush to send all queued events
Langfuse.flush
```

### 6.3 Check Connection

Verify your connection to Langfuse by sending a test trace:

```ruby
begin
  trace = Langfuse.trace(name: "connection-test", metadata: { test: true })
  Langfuse.flush
  puts "Connection to Langfuse successful with trace ID: #{trace.id}"
rescue => e
  puts "Connection to Langfuse failed: #{e.message}"
end
```

## 7. Next Steps

Now that you have integrated Langfuse and built helper constructs, you can:

1. Instrument your code to track important operations
2. Build more sophisticated helper methods tailored to your application needs
3. Create dashboards in the Langfuse UI to visualize your application's performance
4. Set up alerts based on observed metrics
5. Use the collected data to optimize your LLM usage and application performance

Remember that the best instrumentation strategy is one that captures meaningful data without introducing unnecessary overhead. Start with the most critical parts of your application and expand your instrumentation as needed.

Happy tracing with Langfuse! 