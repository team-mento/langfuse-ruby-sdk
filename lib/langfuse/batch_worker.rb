# typed: strict

require 'sorbet-runtime'

module Langfuse
  class BatchWorker
    extend T::Sig
    # This is a placeholder class that will be defined with Sidekiq::Worker
    # when Sidekiq is available.
    #
    # If Sidekiq is available, this will be replaced with a real worker class
    # that includes Sidekiq::Worker

    # Ensure return type matches the synchronous perform call
    sig { params(events: T::Array[T::Hash[T.untyped, T.untyped]]).void }
    def self.perform_async(events)
      # When Sidekiq is not available, process synchronously and return result
      new.perform(events)
    end

    sig { params(events: T::Array[T::Hash[T.untyped, T.untyped]]).returns(T::Hash[String, T.untyped]) }
    def perform(events)
      # Assuming Langfuse.configuration returns a valid config object for ApiClient
      T.unsafe(Langfuse::ApiClient).new(T.unsafe(Langfuse).configuration).ingest(events)
    end
  end

  # Define the real Sidekiq worker if Sidekiq is available
  if defined?(Sidekiq)
    class BatchWorker
      # Re-extend T::Sig within the conditional definition
      extend T::Sig
      # Include Sidekiq::Worker directly - rely on T.unsafe for its methods
      include Sidekiq::Worker

      # Using T.unsafe for sidekiq_options DSL
      T.unsafe(self).sidekiq_options queue: 'langfuse', retry: 5, backtrace: true

      # Custom retry delay logic (exponential backoff)
      # Using T.unsafe for sidekiq_retry_in DSL
      T.unsafe(self).sidekiq_retry_in do |count|
        10 * (count + 1) # 10s, 20s, 30s, 40s, 50s
      end

      sig { params(event_hashes: T::Array[T::Hash[T.untyped, T.untyped]]).void }
      def perform(event_hashes)
        # Assuming Langfuse.configuration returns a valid config object
        api_client = T.unsafe(ApiClient).new(T.unsafe(Langfuse).configuration)

        begin
          response = api_client.ingest(event_hashes)

          # Check for partial failures using standard hash access
          errors = T.let(response['errors'], T.nilable(T::Array[T::Hash[String, T.untyped]]))
          if errors && errors.any?
            errors.each do |error|
              # Use T.unsafe(self).logger provided by Sidekiq::Worker
              T.unsafe(self).logger.error("Langfuse API error for event #{error['id']}: #{error['message']}")

              # Store permanently failed events if needed
              # Assuming error['status'] exists and can be converted to integer
              status = T.let(error['status'], T.untyped)
              next unless non_retryable_error?(status)

              # Assuming event_hashes elements have :id key
              failed_event = event_hashes.find { |e| T.unsafe(e)[:id] == error['id'] }
              if failed_event
                # Remove redundant T.cast
                store_failed_event(failed_event, T.cast(error['message'], String))
              end
            end
          end
        rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED => e
          # Network errors - Sidekiq will retry
          T.unsafe(self).logger.error("Langfuse network error: #{e.full_message}")
          raise
        rescue StandardError => e
          # Other errors
          # Use T.unsafe(self).logger
          T.unsafe(self).logger.error("Langfuse API error: #{e.message}")

          # Let Sidekiq retry
          raise
        end
      end

      private

      sig { params(status: T.untyped).returns(T::Boolean) }
      def non_retryable_error?(status)
        # 4xx errors except 429 (rate limit) are not retryable
        status_int = T.let(status.to_i, Integer)
        status_int >= 400 && status_int < 500 && status_int != 429
      end

      sig { params(event: T::Hash[T.untyped, T.untyped], error_msg: String).returns(T.untyped) }
      def store_failed_event(event, error_msg)
        # Store in Redis for later inspection/retry
        # Using T.unsafe for Sidekiq.redis block and redis operations
        T.unsafe(Sidekiq).redis do |redis|
          T.unsafe(redis).rpush('langfuse:failed_events', {
            event: event,
            error: error_msg,
            timestamp: Time.now.utc.iso8601
          }.to_json)
        end
      end
    end
  end
end
