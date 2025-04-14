# typed: false
# frozen_string_literal: true

require 'sorbet-runtime'
require 'langfuse/version'
require 'langfuse/configuration'

# Load models - Use fully qualified names in sigs below
require 'langfuse/models/ingestion_event'
require 'langfuse/models/trace'
require 'langfuse/models/span'
require 'langfuse/models/generation'
require 'langfuse/models/event'
require 'langfuse/models/score'
require 'langfuse/models/usage'

# Load API client
require 'langfuse/api_client'

# Load batch worker
require 'langfuse/batch_worker'

# Load main client
require 'langfuse/client'

module Langfuse
  extend T::Sig

  class << self
    extend T::Sig

    # Sig for the writer method created by attr_writer
    sig { params(configuration: ::Langfuse::Configuration).void }
    attr_writer :configuration

    # Sig for the reader method
    sig { returns(::Langfuse::Configuration) }
    def configuration
      # Use T.let for clarity on initialization
      @configuration = T.let(@configuration, T.nilable(::Langfuse::Configuration))
      @configuration ||= ::Langfuse::Configuration.new
    end

    # Configuration block
    sig { params(_block: T.proc.params(config: ::Langfuse::Configuration).void).void }
    def configure(&_block)
      # Pass the block to yield
      yield(configuration)
    end

    # --- Convenience delegators to the client instance ---

    # Create Trace
    sig { params(attributes: T::Hash[Symbol, T.untyped]).returns(::Langfuse::Models::Trace) }
    def trace(attributes = {})
      # Use T.unsafe as Client returns T.untyped for Models for now
      T.unsafe(Client.instance).trace(attributes)
    end

    # Create Span
    sig { params(attributes: T::Hash[Symbol, T.untyped]).returns(::Langfuse::Models::Span) }
    def span(attributes = {})
      T.unsafe(Client.instance).span(attributes)
    end

    # Update Span
    sig { params(span: ::Langfuse::Models::Span).void }
    def update_span(span)
      T.unsafe(Client.instance).update_span(span)
      # Return void implicitly
    end

    # Create Generation
    sig { params(attributes: T::Hash[Symbol, T.untyped]).returns(::Langfuse::Models::Generation) }
    def generation(attributes = {})
      T.unsafe(Client.instance).generation(attributes)
    end

    # Update Generation
    sig { params(generation: ::Langfuse::Models::Generation).void }
    def update_generation(generation)
      T.unsafe(Client.instance).update_generation(generation)
      # Return void implicitly
    end

    # Create Event
    sig { params(attributes: T::Hash[Symbol, T.untyped]).returns(::Langfuse::Models::Event) }
    def event(attributes = {})
      T.unsafe(Client.instance).event(attributes)
    end

    # Create Score
    sig { params(attributes: T::Hash[Symbol, T.untyped]).returns(::Langfuse::Models::Score) }
    def score(attributes = {})
      T.unsafe(Client.instance).score(attributes)
    end

    # Flush events
    sig { void }
    def flush
      Client.instance.flush
    end

    # Shutdown client
    sig { void }
    def shutdown
      Client.instance.shutdown
    end
  end
end
