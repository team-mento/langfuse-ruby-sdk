require 'securerandom'

module Langfuse
  module Models
    class Generation
      attr_accessor :id, :trace_id, :name, :start_time, :end_time,
                    :metadata, :input, :output, :level, :status_message,
                    :parent_observation_id, :version, :environment,
                    :completion_start_time, :model, :model_parameters,
                    :usage, :prompt_name, :prompt_version

      def initialize(attributes = {})
        attributes.each do |key, value|
          send("#{key}=", value) if respond_to?("#{key}=")
        end
        @id ||= SecureRandom.uuid
        @start_time ||= Time.now.utc
      end

      def to_h
        {
          id: @id,
          traceId: @trace_id,
          name: @name,
          startTime: @start_time&.iso8601(3),
          endTime: @end_time&.iso8601(3),
          metadata: @metadata,
          input: @input,
          output: @output,
          level: @level,
          statusMessage: @status_message,
          parentObservationId: @parent_observation_id,
          version: @version,
          environment: @environment,
          completionStartTime: @completion_start_time&.iso8601(3),
          model: @model,
          modelParameters: @model_parameters,
          usage: @usage.respond_to?(:to_h) ? @usage.to_h : @usage,
          promptName: @prompt_name,
          promptVersion: @prompt_version
        }.compact
      end
    end
  end
end 