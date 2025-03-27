module Langfuse
  class BatchWorker
    # This is a placeholder class that will be defined with Sidekiq::Worker
    # when Sidekiq is available.
    #
    # If Sidekiq is available, this will be replaced with a real worker class
    # that includes Sidekiq::Worker

    def self.perform_async(events)
      # When Sidekiq is not available, process synchronously
      new.perform(events)
    end

    def perform(events)
      Langfuse::ApiClient.new(Langfuse.configuration).ingest(events)
    end
  end

  # Define the real Sidekiq worker if Sidekiq is available
  if defined?(Sidekiq)
    class BatchWorker
      include Sidekiq::Worker

      sidekiq_options queue: 'langfuse', retry: 5, backtrace: true

      # Custom retry delay logic (exponential backoff)
      sidekiq_retry_in do |count|
        10 * (count + 1) # 10s, 20s, 30s, 40s, 50s
      end

      def perform(event_hashes)
        api_client = ApiClient.new(Langfuse.configuration)

        begin
          response = api_client.ingest(event_hashes)

          # Check for partial failures
          if response && response['errors']&.any?
            response['errors'].each do |error|
              logger.error("Langfuse API error for event #{error['id']}: #{error['message']}")

              # Store permanently failed events if needed
              if non_retryable_error?(error['status'])
                store_failed_event(event_hashes.find { |e| e[:id] == error['id'] }, error['message'])
              end
            end
          end
        rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED => e
          # Network errors - Sidekiq will retry
          logger.error("Langfuse network error: #{e.message}")
          raise
        rescue StandardError => e
          # Other errors
          logger.error("Langfuse API error: #{e.message}")

          # Let Sidekiq retry
          raise
        end
      end

      private

      def non_retryable_error?(status)
        # 4xx errors except 429 (rate limit) are not retryable
        status.to_i >= 400 && status.to_i < 500 && status.to_i != 429
      end

      def store_failed_event(event, error)
        # Store in Redis for later inspection/retry
        Sidekiq.redis do |redis|
          redis.rpush('langfuse:failed_events', {
            event: event,
            error: error,
            timestamp: Time.now.utc.iso8601
          }.to_json)
        end
      end
    end
  end
end
