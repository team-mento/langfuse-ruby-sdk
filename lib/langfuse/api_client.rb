require 'net/http'
require 'uri'
require 'json'
require 'base64'

module Langfuse
  class ApiClient
    attr_reader :config

    def initialize(config)
      @config = config
    end

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

      response = http.request(request)

      if response.code.to_i == 207 # Partial success
        log('Received 207 partial success response') if @config.debug
        JSON.parse(response.body)
      elsif response.code.to_i >= 200 && response.code.to_i < 300
        log("Received successful response: #{response.code}") if @config.debug
        JSON.parse(response.body)
      else
        error_msg = "API error: #{response.code} #{response.message}"
        if @config.debug
          log("Response body: #{response.body}", :error)
          log("Request URL: #{uri}", :error)
        end
        log(error_msg, :error)
        raise error_msg
      end

      log('---')
    rescue StandardError => e
      log("Error during API request: #{e.message}", :error)
      raise
    end

    private

    def log(message, level = :debug)
      return unless @config.debug

      logger = defined?(Rails) ? Rails.logger : Logger.new($stdout)
      logger.send(level, "[Langfuse] #{message}")
    end
  end
end
