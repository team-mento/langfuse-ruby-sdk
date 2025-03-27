require 'langfuse/version'
require 'langfuse/configuration'

# Load models
require 'langfuse/models/ingestion_event'
require 'langfuse/models/trace'
require 'langfuse/models/span'
require 'langfuse/models/generation'
require 'langfuse/models/event'
require 'langfuse/models/score'
require 'langfuse/models/usage'

# Load API client
require 'langfuse/api_client'

# Load batch worker (works with or without Sidekiq)
require 'langfuse/batch_worker'

# Load main client
require 'langfuse/client'

module Langfuse
  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    # Convenience delegators to the client instance
    def trace(attributes = {})
      Client.instance.trace(attributes)
    end

    def span(attributes = {})
      Client.instance.span(attributes)
    end

    def update_span(span)
      Client.instance.update_span(span)
    end

    def generation(attributes = {})
      Client.instance.generation(attributes)
    end

    def update_generation(generation)
      Client.instance.update_generation(generation)
    end

    def event(attributes = {})
      Client.instance.event(attributes)
    end

    def score(attributes = {})
      Client.instance.score(attributes)
    end

    def flush
      Client.instance.flush
    end

    def shutdown
      Client.instance.shutdown
    end
  end
end
