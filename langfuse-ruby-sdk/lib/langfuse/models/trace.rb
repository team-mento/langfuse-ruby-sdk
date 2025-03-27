require 'securerandom'

module Langfuse
  module Models
    class Trace
      attr_accessor :id, :name, :user_id, :input, :output,
                    :session_id, :metadata, :tags, :public,
                    :release, :version, :timestamp, :environment

      def initialize(attributes = {})
        attributes.each do |key, value|
          send("#{key}=", value) if respond_to?("#{key}=")
        end
        @id ||= SecureRandom.uuid
        @timestamp ||= Time.now.utc
      end

      def to_h
        {
          id: @id,
          name: @name,
          userId: @user_id,
          input: @input,
          output: @output,
          sessionId: @session_id,
          metadata: @metadata,
          tags: @tags,
          public: @public,
          release: @release,
          version: @version,
          timestamp: @timestamp&.iso8601(3),
          environment: @environment
        }.compact
      end
    end
  end
end
