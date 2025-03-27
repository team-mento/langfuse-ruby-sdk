require 'singleton'
require 'concurrent'
require 'logger'

module Langfuse
  class Client
    include Singleton

    def initialize
      @config = Langfuse.configuration
      @events = Concurrent::Array.new # Thread-safe array
      @mutex = Mutex.new # For operations that need additional thread safety

      # Start periodic flusher only in server context
      schedule_periodic_flush if defined?(Rails) && Rails.server?

      # Register shutdown hook
      return if @config.disable_at_exit_hook

      at_exit { shutdown }
    end

    # Creates a new trace
    def trace(attributes = {})
      trace = Models::Trace.new(attributes)
      event = Models::IngestionEvent.new(
        type: 'trace-create',
        body: trace
      )
      enqueue_event(event)
      trace
    end

    # Creates a new span within a trace
    def span(attributes = {})
      raise ArgumentError, 'trace_id is required for creating a span' unless attributes[:trace_id]

      span = Models::Span.new(attributes)
      event = Models::IngestionEvent.new(
        type: 'span-create',
        body: span
      )
      enqueue_event(event)
      span
    end

    # Updates an existing span
    def update_span(span)
      raise ArgumentError, 'span.id and span.trace_id are required for updating a span' unless span.id && span.trace_id

      event = Models::IngestionEvent.new(
        type: 'span-update',
        body: span
      )
      enqueue_event(event)
      span
    end

    # Creates a new generation within a trace
    def generation(attributes = {})
      raise ArgumentError, 'trace_id is required for creating a generation' unless attributes[:trace_id]

      generation = Models::Generation.new(attributes)
      event = Models::IngestionEvent.new(
        type: 'generation-create',
        body: generation
      )
      enqueue_event(event)
      generation
    end

    # Updates an existing generation
    def update_generation(generation)
      unless generation.id && generation.trace_id
        raise ArgumentError, 'generation.id and generation.trace_id are required for updating a generation'
      end

      event = Models::IngestionEvent.new(
        type: 'generation-update',
        body: generation
      )
      enqueue_event(event)
      generation
    end

    # Creates a new event within a trace
    def event(attributes = {})
      raise ArgumentError, 'trace_id is required for creating an event' unless attributes[:trace_id]

      event_obj = Models::Event.new(attributes)
      event = Models::IngestionEvent.new(
        type: 'event-create',
        body: event_obj
      )
      enqueue_event(event)
      event_obj
    end

    # Creates a new score
    def score(attributes = {})
      raise ArgumentError, 'trace_id is required for creating a score' unless attributes[:trace_id]

      score = Models::Score.new(attributes)
      event = Models::IngestionEvent.new(
        type: 'score-create',
        body: score
      )
      enqueue_event(event)
      score
    end

    # Flushes all pending events to the API
    def flush
      events_to_process = nil

      # Atomically swap the events array to avoid race conditions
      @mutex.synchronize do
        events_to_process = @events.dup
        @events.clear
      end

      return if events_to_process.empty?

      # Convert objects to hashes for serialization
      event_hashes = events_to_process.map(&:to_h)

      log("Flushing #{event_hashes.size} events")

      # Send to background worker
      BatchWorker.perform_async(event_hashes)
    end

    # Gracefully shuts down the client, ensuring all events are flushed
    def shutdown
      log('Shutting down Langfuse client...')

      # Cancel the flush timer if it's running
      @flush_thread&.exit

      # Flush any remaining events
      flush

      log('Langfuse client shut down.')
    end

    private

    def enqueue_event(event)
      @events << event

      # Trigger immediate flush if batch size reached
      flush if @events.size >= @config.batch_size
    end

    def schedule_periodic_flush
      log("Starting periodic flush thread (interval: #{@config.flush_interval}s)")

      @flush_thread = Thread.new do
        loop do
          sleep @config.flush_interval
          flush
        rescue StandardError => e
          log("Error in Langfuse flush thread: #{e.message}", :error)
          sleep 1 # Avoid tight loop on persistent errors
        end
      end
    end

    def log(message, level = :debug)
      return unless @config.debug

      logger = defined?(Rails) ? Rails.logger : Logger.new($stdout)
      logger.send(level, "[Langfuse] #{message}")
    end
  end
end
