# typed: strict

require 'net/http'
require 'uri'
require 'json'
require 'base64'
require 'sorbet-runtime'

module Langfuse
  class ApiClient
    extend T::Sig

    sig { returns(T.untyped) }
    attr_reader :config

    sig { params(config: T.untyped).void }
    def initialize(config)
      @config = config
    end

    sig { params(events: T::Array[T::Hash[T.untyped, T.untyped]]).returns(T::Hash[String, T.untyped]) }
    def ingest(events)
      uri = URI.parse("#{@config.host}/api/public/ingestion")

      # Build the request
      request = Net::HTTP::Post.new(uri.path)
      request.content_type = 'application/json'

      # Set authorization header using base64 encoded credentials
      auth = Base64.strict_encode64("#{@config.public_key}:#{@config.secret_key}")
      # Log the encoded auth header for debugging
      if @config.debug
        log("Using auth header: Basic #{auth} (public_key: #{@config.public_key}, secret_key: #{@config.secret_key})")
      end
      request['Authorization'] = "Basic #{auth}"

      # Set the payload
      request.body = {
        batch: events
      }.to_json

      # Send the request
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.read_timeout = 10 # 10 seconds

      if @config.debug
        log("Sending #{events.size} events to Langfuse API at #{@config.host}")
        log("Events: #{events.inspect}")
        # log("Using auth header: Basic #{auth.gsub(/.(?=.{4})/, '*')}") # Mask most of the auth token
        log("Using auth header: Basic #{auth}") # Mask most of the auth token
        log("Request url: #{uri}")
      end

      log('---') # Moved log statement before response handling to avoid affecting return value

      response = http.request(request)

      result = T.let(nil, T.nilable(T::Hash[String, T.untyped]))

      if response.code.to_i == 207 # Partial success
        log('Received 207 partial success response') if @config.debug
        result = JSON.parse(response.body)
      elsif response.code.to_i >= 200 && response.code.to_i < 300
        log("Received successful response: #{response.code}") if @config.debug
        result = JSON.parse(response.body)
      else
        error_msg = "API error: #{response.code} #{response.message}"
        if @config.debug
          log("Response body: #{response.body}", :error)
          log("Request URL: #{uri}", :error)
        end
        log(error_msg, :error)
        raise error_msg
      end

      result
    rescue StandardError => e
      log("Error during API request: #{e.message}", :error)
      raise
    end

    private

    sig { params(message: String, level: Symbol).returns(T.untyped) }
    def log(message, level = :debug)
      return unless @config.debug

      T.unsafe(@config.logger).send(level, "[Langfuse] #{message}")
    end
  end
end
