require 'securerandom'

module Langfuse
  module Models
    class IngestionEvent
      attr_accessor :id, :type, :timestamp, :body, :metadata

      def initialize(type:, body:, metadata: nil)
        @id = SecureRandom.uuid
        @type = type
        @timestamp = Time.now.utc.iso8601(3) # Millisecond precision
        @body = body
        @metadata = metadata
      end

      def to_h
        {
          id: @id,
          type: @type,
          timestamp: @timestamp,
          body: @body.respond_to?(:to_h) ? @body.to_h : @body,
          metadata: @metadata
        }.compact
      end
    end
  end
end
