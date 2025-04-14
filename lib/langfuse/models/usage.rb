# typed: true
module Langfuse
  module Models
    class Usage
      attr_accessor :input, :output, :total, :unit,
                    :input_cost, :output_cost, :total_cost,
                    :prompt_tokens, :completion_tokens, :total_tokens

      def initialize(attributes = {})
        attributes.each do |key, value|
          send("#{key}=", value) if respond_to?("#{key}=")
        end
      end

      def to_h
        {
          input: @input,
          output: @output,
          total: @total,
          unit: @unit,
          inputCost: @input_cost,
          outputCost: @output_cost,
          totalCost: @total_cost,
          promptTokens: @prompt_tokens,
          completionTokens: @completion_tokens,
          totalTokens: @total_tokens
        }.compact
      end
    end
  end
end
