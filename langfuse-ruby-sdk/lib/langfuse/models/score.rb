require 'securerandom'

module Langfuse
  module Models
    class Score
      attr_accessor :id, :trace_id, :name, :value, :observation_id,
                    :comment, :data_type, :config_id, :environment

      def initialize(attributes = {})
        attributes.each do |key, value|
          send("#{key}=", value) if respond_to?("#{key}=")
        end
        @id ||= SecureRandom.uuid
      end

      def to_h
        {
          id: @id,
          traceId: @trace_id,
          name: @name,
          value: @value,
          observationId: @observation_id,
          comment: @comment,
          dataType: @data_type,
          configId: @config_id,
          environment: @environment
        }.compact
      end
    end
  end
end
