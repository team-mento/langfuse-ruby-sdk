# typed: strict

require 'logger'
require 'sorbet-runtime'

module Langfuse
  class Configuration
    extend T::Sig

    sig { returns(T.nilable(String)) }
    attr_accessor :public_key, :secret_key

    sig { returns(String) }
    attr_accessor :host

    sig { returns(Integer) }
    attr_accessor :batch_size, :flush_interval, :shutdown_timeout

    sig { returns(T::Boolean) }
    attr_accessor :debug, :disable_at_exit_hook

    sig { returns(Logger) }
    attr_accessor :logger

    sig { void }
    def initialize
      # Default configuration with environment variable fallbacks
      @public_key = T.let(ENV['LANGFUSE_PUBLIC_KEY'], T.nilable(String))
      @secret_key = T.let(ENV['LANGFUSE_SECRET_KEY'], T.nilable(String))
      @host = T.let(ENV.fetch('LANGFUSE_HOST', 'https://us.cloud.langfuse.com'), String)
      @batch_size = T.let(ENV.fetch('LANGFUSE_BATCH_SIZE', '10').to_i, Integer)
      @flush_interval = T.let(ENV.fetch('LANGFUSE_FLUSH_INTERVAL', '60').to_i, Integer)
      @debug = T.let(ENV.fetch('LANGFUSE_DEBUG', 'false') == 'true', T::Boolean)
      @disable_at_exit_hook = T.let(false, T::Boolean)
      @shutdown_timeout = T.let(ENV.fetch('LANGFUSE_SHUTDOWN_TIMEOUT', '5').to_i, Integer)
      @logger = T.let(Logger.new($stdout), Logger)
    end
  end
end
