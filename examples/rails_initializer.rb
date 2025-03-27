# config/initializers/langfuse.rb
require 'langfuse'

Langfuse.configure do |config|
  config.public_key = ENV['LANGFUSE_PUBLIC_KEY']
  config.secret_key = ENV['LANGFUSE_SECRET_KEY']

  # Optional configuration
  config.host = ENV.fetch('LANGFUSE_HOST', 'https://us.cloud.langfuse.com')
  config.batch_size = ENV.fetch('LANGFUSE_BATCH_SIZE', '20').to_i
  config.flush_interval = ENV.fetch('LANGFUSE_FLUSH_INTERVAL', '30').to_i # seconds
  config.debug = Rails.env.development? || ENV['LANGFUSE_DEBUG'] == 'true'
end

# Ensure Langfuse events are flushed when the Rails app is shut down
Rails.application.config.after_initialize do
  at_exit do
    Rails.logger.info 'Flushing Langfuse events before shutdown'
    Langfuse.flush
  end
end

# Optional: ActiveSupport::Notifications integration
if ENV['LANGFUSE_USE_NOTIFICATIONS'] == 'true'
  ActiveSupport::Notifications.subscribe(/langfuse/) do |name, _start, _finish, _id, payload|
    case name
    when 'langfuse.trace'
      Langfuse.trace(payload)
    when 'langfuse.span'
      Langfuse.span(payload)
    when 'langfuse.generation'
      Langfuse.generation(payload)
    when 'langfuse.event'
      Langfuse.event(payload)
    when 'langfuse.score'
      Langfuse.score(payload)
    end
  end
end
