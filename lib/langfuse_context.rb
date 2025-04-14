# typed: true

require 'sorbet-runtime' # Ensure Sorbet is required

class LangfuseContext
  extend T::Sig # Add this to enable sig blocks on class methods

  # Define the type for the context hash
  ContextHash = T.type_alias { T::Hash[Symbol, T.nilable(String)] }

  # Gets the current context hash for the thread
  sig { returns(ContextHash) }
  def self.current
    # T.let is used for type assertion
    context = T.let(Thread.current[:langfuse_context], T.nilable(ContextHash))
    # Initialize if nil
    context ||= T.let({}, ContextHash)
    Thread.current[:langfuse_context] = context
    context
  end

  # Gets the current trace ID from the context
  sig { returns(T.nilable(String)) }
  def self.current_trace_id
    current[:trace_id]
  end

  # Gets the current span ID from the context
  sig { returns(T.nilable(String)) }
  def self.current_span_id
    current[:span_id]
  end

  # Executes a block with a specific trace context
  sig do
    params(
      trace: T.untyped, # Use T.untyped until Models::Trace is fully typed
      _block: T.proc.void
    ).void
  end
  def self.with_trace(trace, &_block)
    old_context = current.dup
    begin
      # Assuming trace.id returns a String
      trace_id = T.let(T.unsafe(trace).id, T.nilable(String))
      Thread.current[:langfuse_context] = { trace_id: trace_id } if trace_id
      yield
    ensure
      Thread.current[:langfuse_context] = old_context
    end
  end

  # Executes a block with a specific span context (merging with existing context)
  sig do
    params(
      span: T.untyped, # Use T.untyped until Models::Span is fully typed
      _block: T.proc.void
    ).void
  end
  def self.with_span(span, &_block)
    old_context = current.dup
    begin
      # Assuming span.id returns a String
      span_id = T.let(T.unsafe(span).id, T.nilable(String))
      # Merge span_id into the current context
      new_context = current.merge({ span_id: span_id })
      Thread.current[:langfuse_context] = new_context if span_id
      yield
    ensure
      Thread.current[:langfuse_context] = old_context
    end
  end
end
