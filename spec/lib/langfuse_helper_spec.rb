require 'spec_helper'

RSpec.describe LangfuseHelper do
  let(:dummy_class) { Class.new { include LangfuseHelper } }
  let(:helper) { dummy_class.new }

  describe '#with_trace' do
    it 'creates and updates a trace', :vcr do
      result = helper.with_trace(name: 'test-trace') do |trace|
        expect(trace.id).not_to be_nil
        'test result'
      end

      expect(result).to eq('test result')
    end

    it 'createes and expects and updates a trace flushes' do
      expect(Langfuse).to receive(:flush)

      helper.with_trace(name: 'fungi-test-trace-4') do |trace|
        expect(trace.id).not_to be_nil
        expect(trace.name).to eq('fungi-test-trace-4')
        'test result'
      end
    end

    it 'handles errors and flushes' do
      expect(Langfuse).to receive(:flush).at_least(:once)

      expect do
        helper.with_trace(name: 'fungi-error-trace') do
          raise 'test error'
        end
      end.to raise_error('test error')
    end

    it 'sets trace output from result' do
      trace_id = nil

      helper.with_trace(name: 'output-trace') do |trace|
        trace_id = trace.id
        { status: 'success' }
      end

      # Verify that a new trace was created with the output
      expect(Langfuse).to have_received(:trace).with(
        hash_including(
          id: trace_id,
          output: { status: 'success' }
        )
      )
    end
  end

  describe '#with_generation' do
    it 'handles errors in generation' do
      expect do
        helper.with_generation(
          name: 'error-gen',
          trace_id: 'trace-123',
          model: 'gpt-3.5-turbo',
          input: { prompt: 'test' }
        ) do |_gen|
          raise 'generation error'
        end
      end.to raise_error('generation error')

      # Verify error was recorded
      expect(Langfuse).to have_received(:update_generation).with(
        satisfy do |generation|
          generation.level == 'ERROR' &&
          generation.status_message == 'generation error'
        end
      )
    end
  end

  describe '#with_context_trace' do
    it 'sets trace context for the duration of the block' do
      helper.with_context_trace(name: 'context-trace') do |trace|
        expect(LangfuseContext.current_trace_id).to eq(trace.id)

        helper.with_context_span(name: 'test-span') do |span|
          expect(LangfuseContext.current_trace_id).to eq(trace.id)
          expect(LangfuseContext.current_span_id).to eq(span.id)
        end
      end

      expect(LangfuseContext.current_trace_id).to be_nil
      expect(LangfuseContext.current_span_id).to be_nil
    end
  end

  describe '#with_context_span' do
    it 'requires trace context' do
      expect do
        helper.with_context_span(name: 'orphan-span') do
          'test'
        end
      end.to raise_error(/No trace context found/)
    end

    it 'creates nested spans correctly' do
      helper.with_context_trace(name: 'parent-trace') do |_trace|
        helper.with_context_span(name: 'parent-span') do |parent_span|
          helper.with_context_span(name: 'child-span') do |child_span|
            expect(child_span.parent_observation_id).to eq(parent_span.id)
          end
        end
      end
    end
  end

  describe '#score_trace' do
    it 'adds a score to the trace' do
      expect(Langfuse).to receive(:score).with(
        trace_id: 'trace-123',
        name: 'test-score',
        value: 0.95,
        comment: 'Great response'
      )

      helper.score_trace(
        trace_id: 'trace-123',
        name: 'test-score',
        value: 0.95,
        comment: 'Great response'
      )
    end
  end
end
