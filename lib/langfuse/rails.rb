require 'active_support/notifications'

module Langfuse
  module Rails
    class << self
      def setup_notifications
        ActiveSupport::Notifications.subscribe(/langfuse/) do |name, start, finish, _id, payload|
          case name
          when 'langfuse.trace'
            Langfuse.trace(payload)
          when 'langfuse.span'
            # Set end_time based on notification timing if not provided
            payload[:end_time] ||= finish
            payload[:start_time] ||= start
            Langfuse.span(payload)
          when 'langfuse.generation'
            # Set end_time based on notification timing if not provided
            payload[:end_time] ||= finish
            payload[:start_time] ||= start
            Langfuse.generation(payload)
          when 'langfuse.score'
            Langfuse.score(payload)
          end
        end
      end
    end
  end
end

# Set up notifications if we're in a Rails environment
Langfuse::Rails.setup_notifications if defined?(::Rails)
