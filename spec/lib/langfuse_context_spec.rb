require 'spec_helper'

RSpec.describe LangfuseContext do
  describe '.current' do
    it 'returns an empty hash when no context is set' do
      expect(described_class.current).to eq({})
    end

    it 'maintains separate contexts for different threads' do
      thread_contexts = []

      threads = 3.times.map do |i|
        Thread.new do
          described_class.with_trace(double('trace', id: "trace-#{i}")) do
            thread_contexts << described_class.current_trace_id
            sleep(0.1) # Simulate some work
          end
        end
      end

      threads.each(&:join)
      expect(thread_contexts).to match_array(%w[trace-0 trace-1 trace-2])
    end
  end

  describe '.with_trace' do
    it 'sets and clears trace context' do
      trace = double('trace', id: 'trace-123')

      described_class.with_trace(trace) do
        expect(described_class.current_trace_id).to eq('trace-123')
      end

      expect(described_class.current_trace_id).to be_nil
    end

    it 'restores previous context after nested calls' do
      trace1 = double('trace1', id: 'trace-1')
      trace2 = double('trace2', id: 'trace-2')

      described_class.with_trace(trace1) do
        expect(described_class.current_trace_id).to eq('trace-1')

        described_class.with_trace(trace2) do
          expect(described_class.current_trace_id).to eq('trace-2')
        end

        expect(described_class.current_trace_id).to eq('trace-1')
      end
    end

    it 'restores context even when an error occurs' do
      trace = double('trace', id: 'trace-123')

      expect do
        described_class.with_trace(trace) do
          raise 'test error'
        end
      end.to raise_error('test error')

      expect(described_class.current_trace_id).to be_nil
    end
  end

  describe '.with_span' do
    it 'sets and clears span context' do
      span = double('span', id: 'span-123')

      described_class.with_span(span) do
        expect(described_class.current_span_id).to eq('span-123')
      end

      expect(described_class.current_span_id).to be_nil
    end

    it 'maintains trace context while setting span context' do
      trace = double('trace', id: 'trace-123')
      span = double('span', id: 'span-123')

      described_class.with_trace(trace) do
        described_class.with_span(span) do
          expect(described_class.current_trace_id).to eq('trace-123')
          expect(described_class.current_span_id).to eq('span-123')
        end

        expect(described_class.current_trace_id).to eq('trace-123')
        expect(described_class.current_span_id).to be_nil
      end
    end
  end
end
