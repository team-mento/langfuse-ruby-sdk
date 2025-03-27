module Langfuse
  class Configuration
    attr_accessor :public_key, :secret_key, :host,
                  :batch_size, :flush_interval, :debug,
                  :disable_at_exit_hook, :shutdown_timeout

    def initialize
      # Default configuration with environment variable fallbacks
      @public_key = ENV['LANGFUSE_PUBLIC_KEY']
      @secret_key = ENV['LANGFUSE_SECRET_KEY']
      @host = ENV.fetch('LANGFUSE_HOST', 'https://cloud.langfuse.com')
      @batch_size = ENV.fetch('LANGFUSE_BATCH_SIZE', '10').to_i
      @flush_interval = ENV.fetch('LANGFUSE_FLUSH_INTERVAL', '60').to_i
      @debug = ENV.fetch('LANGFUSE_DEBUG', 'false') == 'true'
      @disable_at_exit_hook = false
      @shutdown_timeout = ENV.fetch('LANGFUSE_SHUTDOWN_TIMEOUT', '5').to_i
    end
  end
end
