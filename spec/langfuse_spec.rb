require 'spec_helper'

RSpec.describe Langfuse do
  let(:dummy_class) { Class.new { include LangfuseHelper } }
  let(:helper) { dummy_class.new }

  before do
    Langfuse.configure do |config|
      config.debug = true
      config.batch_size = 10
    end

    # Reset the events queue
    client = Langfuse::Client.instance
    client.instance_variable_set(:@events, Concurrent::Array.new)
  end

  describe '.trace' do
    it 'creates a trace' do
      # trace = Langfuse.trace(name: 'fungi-test-trace-2')
      expect(Langfuse).to receive(:flush)

      trace = Langfuse.trace(name: 'fungi-test-trace')

      expect(trace).to be_a(Langfuse::Models::Trace)
      expect(trace.name).to eq('fungi-test-trace')
      expect(trace.id).not_to be_nil

      events = Langfuse::Client.instance.instance_variable_get(:@events)
      expect(events.size).to eq(1)
      expect(events.first).to be_a(Langfuse::Models::IngestionEvent)
      expect(events.first.type).to eq('trace-create')
    end
  end

  describe '.span' do
    it 'creates a span' do
      trace = Langfuse.trace(name: 'test-trace')
      span = Langfuse.span(
        name: 'test-span',
        trace_id: trace.id
      )

      expect(span).to be_a(Langfuse::Models::Span)
      expect(span.name).to eq('test-span')
      expect(span.trace_id).to eq(trace.id)

      events = Langfuse::Client.instance.instance_variable_get(:@events)
      expect(events.size).to eq(2)
      expect(events.last.type).to eq('span-create')
    end

    it 'requires a trace_id' do
      expect do
        Langfuse.span(name: 'test-span')
      end.to raise_error(ArgumentError, /trace_id is required/)
    end
  end

  describe '.generation' do
    it 'creates a generation' do
      trace = Langfuse.trace(name: 'test-trace')
      generation = Langfuse.generation(
        name: 'test-generation',
        trace_id: trace.id,
        model: 'gpt-3.5-turbo'
      )

      expect(generation).to be_a(Langfuse::Models::Generation)
      expect(generation.name).to eq('test-generation')
      expect(generation.model).to eq('gpt-3.5-turbo')

      events = Langfuse::Client.instance.instance_variable_get(:@events)
      expect(events.size).to eq(2)
      expect(events.last.type).to eq('generation-create')
    end
  end

  describe '.score' do
    it 'creates a score' do
      trace = Langfuse.trace(name: 'test-trace')
      score = Langfuse.score(
        name: 'accuracy',
        trace_id: trace.id,
        value: 0.9
      )

      expect(score).to be_a(Langfuse::Models::Score)
      expect(score.name).to eq('accuracy')
      expect(score.value).to eq(0.9)

      events = Langfuse::Client.instance.instance_variable_get(:@events)
      expect(events.size).to eq(2)
      expect(events.last.type).to eq('score-create')
    end
  end

  describe '.flush' do
    it 'flushes the event queue' do
      # Mock the BatchWorker to avoid actual API calls
      allow(Langfuse::BatchWorker).to receive(:perform_async)

      Langfuse.trace(name: 'test-trace')

      events = Langfuse::Client.instance.instance_variable_get(:@events)
      expect(events.size).to eq(1)

      Langfuse.flush

      events = Langfuse::Client.instance.instance_variable_get(:@events)
      expect(events.size).to eq(0)
      expect(Langfuse::BatchWorker).to have_received(:perform_async).once
    end
  end
end
