# Langfuse Ruby SDK

A Ruby client for the [Langfuse](https://langfuse.com) observability platform.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'langfuse'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install langfuse
```

## Configuration

You need to configure the SDK with your Langfuse credentials:

```ruby
Langfuse.configure do |config|
  config.public_key = ENV['LANGFUSE_PUBLIC_KEY']  # e.g., 'pk-lf-...'
  config.secret_key = ENV['LANGFUSE_SECRET_KEY']  # e.g., 'sk-lf-...'
  config.host = ENV.fetch('LANGFUSE_HOST', 'https://cloud.langfuse.com')
  config.debug = true # Enable debug logging
end
```

### Configuration Options

- `public_key`: Your Langfuse public key (required)
- `secret_key`: Your Langfuse secret key (required)
- `host`: Langfuse API host (default: 'https://cloud.langfuse.com')
- `batch_size`: Number of events to buffer before sending (default: 10)
- `flush_interval`: Seconds between automatic flushes (default: 60)
- `debug`: Enable debug logging (default: false)
- `disable_at_exit_hook`: Disable automatic flush on program exit (default: false)
- `shutdown_timeout`: Seconds to wait for flush thread to finish on shutdown (default: 5)

## Usage

### Creating a Trace

A trace represents a complete user interaction:

```ruby
trace = Langfuse.trace(
  name: "user-query",
  user_id: "user-123",
  metadata: { source: "web-app" }
)
```

### Creating a Span

Spans represent operations within a trace:

```ruby
span = Langfuse.span(
  name: "process-query",
  trace_id: trace.id,
  input: { query: "What is the weather today?" }
)

# Later, update and close the span
span.output = { processed_result: "..." }
span.end_time = Time.now.utc
Langfuse.update_span(span)
```

### Creating a Generation

Generations track LLM invocations:

```ruby
generation = Langfuse.generation(
  name: "llm-response",
  trace_id: trace.id,
  parent_observation_id: span.id, # Optional: link to parent span
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

# Later, update with the response
generation.output = "I don't have access to real-time weather data..."
generation.usage = Langfuse::Models::Usage.new(
  prompt_tokens: 25,
  completion_tokens: 35, 
  total_tokens: 60
)
Langfuse.update_generation(generation)
```

### Creating Events

Events capture point-in-time occurrences:

```ruby
Langfuse.event(
  name: "user-feedback",
  trace_id: trace.id,
  input: { feedback_type: "thumbs_up" }
)
```

### Adding Scores

Scores help evaluate quality:

```ruby
Langfuse.score(
  trace_id: trace.id,
  name: "relevance",
  value: 0.9,
  comment: "Response was highly relevant"
)
```

### Manual Flushing

Events are automatically sent when:
- The batch size is reached
- The flush interval timer triggers
- The application exits

You can also manually flush events:

```ruby
Langfuse.flush
```

## Rails Integration

### Initializer

Create a file at `config/initializers/langfuse.rb`:

```ruby
require 'langfuse'

Langfuse.configure do |config|
  config.public_key = ENV['LANGFUSE_PUBLIC_KEY']
  config.secret_key = ENV['LANGFUSE_SECRET_KEY']
  config.batch_size = 20
  config.flush_interval = 30 # seconds
  config.debug = Rails.env.development?
end
```

### ActiveSupport::Notifications Integration

You can integrate with Rails' notification system:

```ruby
# config/initializers/langfuse.rb
ActiveSupport::Notifications.subscribe(/langfuse/) do |name, start, finish, id, payload|
  case name
  when 'langfuse.trace'
    Langfuse.trace(payload)
  when 'langfuse.span'
    Langfuse.span(payload)
  # etc.
  end
end

# In your application code
ActiveSupport::Notifications.instrument('langfuse.trace', {
  name: 'user-login',
  metadata: { user_id: current_user.id }
})
```

## Background Processing with Sidekiq

If Sidekiq is available in your application, the SDK will automatically use it for processing events in the background. This improves performance and reliability.

To enable Sidekiq integration, simply add Sidekiq to your application and it will be detected automatically.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT). 