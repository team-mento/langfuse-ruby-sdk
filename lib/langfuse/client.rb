# typed: strict

require 'singleton'
require 'concurrent'
require 'logger'
require 'sorbet-runtime'

# Model requires are implicitly handled by the main langfuse.rb require
# No need for placeholder type aliases here

module Langfuse
  class Client
    extend T::Sig
    include Singleton

    sig { returns(::Langfuse::Configuration) } # Use actual Configuration type
    attr_reader :config

    # Use the class directly, Sorbet should handle Concurrent::Array generics
    sig { returns(Concurrent::Array) }
    attr_reader :events

    sig { returns(T.nilable(Thread)) }
    attr_reader :flush_thread

    sig { void }
    def initialize
      @config = T.let(Langfuse.configuration, ::Langfuse::Configuration)
      # Let Sorbet infer the type for Concurrent::Array here
      @events = T.let(Concurrent::Array.new, Concurrent::Array)
      @mutex = T.let(Mutex.new, Mutex)
      @flush_thread = T.let(nil, T.nilable(Thread))

      schedule_periodic_flush

      # Register shutdown hook
      return if @config.disable_at_exit_hook

      Kernel.at_exit { shutdown }
    end

    # Creates a new trace
    sig { params(attributes: T::Hash[Symbol, T.untyped]).returns(T.untyped) }
    def trace(attributes = {})
      # Ideally Models::Trace.new would have its own signature
      trace = T.unsafe(Models::Trace).new(attributes)
      event = T.unsafe(Models::IngestionEvent).new(
        type: 'trace-create',
        body: trace
      )
      enqueue_event(event)
      trace
    end

    # Creates a new span within a trace
    sig { params(attributes: T::Hash[Symbol, T.untyped]).returns(T.untyped) }
    def span(attributes = {})
      raise ArgumentError, 'trace_id is required for creating a span' unless attributes[:trace_id]

      span = T.unsafe(Models::Span).new(attributes)
      event = T.unsafe(Models::IngestionEvent).new(
        type: 'span-create',
        body: span
      )
      enqueue_event(event)
      span
    end

    # Updates an existing span
    sig { params(span: T.untyped).returns(T.untyped) }
    def update_span(span)
      # Assuming span object has :id and :trace_id methods/attributes
      unless T.unsafe(span).id && T.unsafe(span).trace_id
        raise ArgumentError,
              'span.id and span.trace_id are required for updating a span'
      end

      event = T.unsafe(Models::IngestionEvent).new(
        type: 'span-update',
        body: span
      )
      enqueue_event(event)
      span
    end

    # Creates a new generation within a trace
    sig { params(attributes: T::Hash[Symbol, T.untyped]).returns(T.untyped) }
    def generation(attributes = {})
      raise ArgumentError, 'trace_id is required for creating a generation' unless attributes[:trace_id]

      generation = T.unsafe(Models::Generation).new(attributes)
      event = T.unsafe(Models::IngestionEvent).new(
        type: 'generation-create',
        body: generation
      )
      enqueue_event(event)
      generation
    end

    # Updates an existing generation
    sig { params(generation: T.untyped).returns(T.untyped) }
    def update_generation(generation)
      unless T.unsafe(generation).id && T.unsafe(generation).trace_id
        raise ArgumentError, 'generation.id and generation.trace_id are required for updating a generation'
      end

      event = T.unsafe(Models::IngestionEvent).new(
        type: 'generation-update',
        body: generation
      )
      enqueue_event(event)
      generation
    end

    # Creates a new event within a trace
    sig { params(attributes: T::Hash[Symbol, T.untyped]).returns(T.untyped) }
    def event(attributes = {})
      raise ArgumentError, 'trace_id is required for creating an event' unless attributes[:trace_id]

      event_obj = T.unsafe(Models::Event).new(attributes)
      event = T.unsafe(Models::IngestionEvent).new(
        type: 'event-create',
        body: event_obj
      )
      enqueue_event(event)
      event_obj
    end

    # Creates a new score
    sig { params(attributes: T::Hash[Symbol, T.untyped]).returns(T.untyped) }
    def score(attributes = {})
      raise ArgumentError, 'trace_id is required for creating a score' unless attributes[:trace_id]

      score = T.unsafe(Models::Score).new(attributes)
      event = T.unsafe(Models::IngestionEvent).new(
        type: 'score-create',
        body: score
      )
      enqueue_event(event)
      score
    end

    # Flushes all pending events to the API
    sig { void }
    def flush
      events_to_process = T.let([], T::Array[T.untyped])

      # Atomically swap the events array to avoid race conditions
      @mutex.synchronize do
        events_to_process = @events.dup
        @events.clear
      end

      return if events_to_process.empty?

      # Convert objects to hashes for serialization
      # Assuming `to_h` exists on Models::IngestionEvent and returns T::Hash[T.untyped, T.untyped]
      event_hashes = events_to_process.map(&:to_h)

      log("Flushing #{event_hashes.size} events")

      # Send to background worker
      T.unsafe(BatchWorker).perform_async(event_hashes)
    end

    # Gracefully shuts down the client, ensuring all events are flushed
    sig { void }
    def shutdown
      log('Shutting down Langfuse client...')

      # Cancel the flush timer if it's running
      @flush_thread&.exit

      # Flush any remaining events
      flush

      log('Langfuse client shut down.')
    end

    private

    sig { params(event: T.untyped).void }
    def enqueue_event(event)
      @events << event

      # Trigger immediate flush if batch size reached
      # Assuming @config.batch_size is an Integer
      flush if @events.size >= @config.batch_size
    end

    sig { returns(Thread) }
    def schedule_periodic_flush
      log("Starting periodic flush thread (interval: #{@config.flush_interval}s)")

      @flush_thread = Thread.new do
        loop do
          # Assuming @config.flush_interval is Numeric
          sleep @config.flush_interval
          flush
        rescue StandardError => e
          log("Error in Langfuse flush thread: #{e.message}", :error)
          sleep 1 # Avoid tight loop on persistent errors
        end
      end
    end

    sig { params(message: String, level: Symbol).returns(T.untyped) }
    def log(message, level = :debug)
      # Assuming @config.debug is Boolean
      return unless @config.debug

      T.unsafe(@config.logger).send(level, "[Langfuse] #{message}")
    end
  end
end
