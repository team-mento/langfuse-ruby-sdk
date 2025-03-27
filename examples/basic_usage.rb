require 'langfuse'

# Configure the client
Langfuse.configure do |config|
  config.public_key = ENV['LANGFUSE_PUBLIC_KEY']  # e.g., 'pk-lf-...'
  config.secret_key = ENV['LANGFUSE_SECRET_KEY']  # e.g., 'sk-lf-...'
  config.host = ENV.fetch('LANGFUSE_HOST', 'https://us.cloud.langfuse.com')
  config.debug = true # Enable debug logging
end

# Create a trace
trace = Langfuse.trace(
  name: 'example-trace',
  user_id: 'user-123',
  metadata: { source: 'ruby-sdk-example' }
)
puts "Created trace with ID: #{trace.id}"

# Create a span
span = Langfuse.span(
  name: 'process-query',
  trace_id: trace.id,
  level: 'DEFAULT',
  input: { query: 'What is the weather today?' }
)
puts "Created span with ID: #{span.id}"

# Create a generation
generation = Langfuse.generation(
  name: 'llm-response',
  trace_id: trace.id,
  parent_observation_id: span.id,
  model: 'gpt-3.5-turbo',
  model_parameters: {
    temperature: 0.7,
    max_tokens: 150
  },
  input: [
    { role: 'system', content: 'You are a helpful assistant' },
    { role: 'user', content: 'What is the weather today?' }
  ]
)
puts "Created generation with ID: #{generation.id}"

# Simulate LLM response
llm_response = "I cannot provide real-time weather information as I don't have access to current weather data. Please check a weather service or website for the most up-to-date information about the weather in your location."

# Update the generation with the response
generation.output = llm_response
generation.end_time = Time.now.utc
generation.usage = Langfuse::Models::Usage.new(
  prompt_tokens: 25,
  completion_tokens: 35,
  total_tokens: 60
)

# Update the generation
Langfuse.update_generation(generation)
puts 'Updated generation with output'

# Add a score
Langfuse.score(
  trace_id: trace.id,
  name: 'relevance',
  value: 0.8,
  comment: 'Response was relevant but generic'
)
puts 'Added score to trace'

# Update and close the span
span.output = { processed_response: llm_response }
span.end_time = Time.now.utc
Langfuse.update_span(span)
puts 'Updated and closed span'

# Make sure all events are sent to the API
Langfuse.flush
puts 'Flushed all events'

# In a real application, Langfuse would automatically flush:
# - When events reach the batch size (default 10)
# - On a periodic interval (default 60 seconds)
# - When the application exits
