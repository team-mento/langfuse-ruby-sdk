# typed: true

require_relative 'langfuse_context'
require 'sorbet-runtime' # Ensure Sorbet is required

module LangfuseHelper
  extend T::Sig # Add this to enable sig blocks in the module

  # Execute a block within the context of a span
  sig do
    params(
      name: String,
      trace_id: String,
      parent_id: T.nilable(String),
      input: T.untyped,
      attributes: T::Hash[Symbol, T.untyped],
      block: T.proc.params(span: ::Langfuse::Models::Span).returns(T.untyped)
    ).returns(T.untyped)
  end
  def with_span(name:, trace_id:, parent_id: nil, input: nil, **attributes, &block)
    # Create the span
    span = T.unsafe(Langfuse).span(
      name: name,
      trace_id: trace_id,
      parent_observation_id: parent_id,
      input: input,
      **attributes
    )

    # Pass the block to the implementation
    with_span_implementation(span, &block)
  end

  # Execute a block within the context of an LLM generation
  sig do
    params(
      name: String,
      trace_id: String,
      model: String,
      input: T.untyped,
      parent_id: T.nilable(String),
      model_parameters: T::Hash[T.untyped, T.untyped],
      attributes: T::Hash[Symbol, T.untyped],
      block: T.proc.params(generation: ::Langfuse::Models::Generation).returns(T.untyped)
    ).returns(T.untyped)
  end
  def with_generation(name:, trace_id:, model:, input:, parent_id: nil, model_parameters: {}, **attributes, &block)
    # Create the generation
    generation = T.unsafe(Langfuse).generation(
      name: name,
      trace_id: trace_id,
      parent_observation_id: parent_id,
      model: model,
      input: input,
      model_parameters: model_parameters,
      **attributes
    )

    T.let(Time.now, Time)
    result = T.let(nil, T.untyped)
    error = T.let(nil, T.nilable(StandardError))

    begin
      # Execute the block with the generation passed as argument
      result = block.call(generation)
      result
    rescue StandardError => e
      # Capture any error
      error = e
      Kernel.raise # Use Kernel.raise
    ensure
      # Always update the generation with results
      generation.end_time = Time.now.utc
      # generation.start_time = start_time.utc # start_time is already UTC if using Time.now.utc

      # Add output if there was a result and it wasn't already set
      generation.output = result if result && generation.output.nil?

      # Add error information if there was an error
      if error
        generation.level = 'ERROR'
        generation.status_message = error.message
        generation.metadata ||= {}
        backtrace = error.backtrace
        generation.metadata[:error_backtrace] = backtrace.first(10) if backtrace # Check if backtrace is nil
      end

      # Update the generation
      T.unsafe(Langfuse).update_generation(generation)
    end
  end

  # Execute a block within the context of a trace
  sig do
    params(
      name: String,
      user_id: T.nilable(String),
      attributes: T::Hash[Symbol, T.untyped],
      _block: T.proc.params(trace: ::Langfuse::Models::Trace).returns(T.untyped)
    ).returns(T.untyped)
  end
  def with_trace(name:, user_id: nil, **attributes, &_block)
    # Create the trace
    trace = T.unsafe(Langfuse).trace(
      name: name,
      user_id: user_id,
      **attributes
    )

    result = T.let(nil, T.untyped)
    error = T.let(nil, T.nilable(StandardError))

    begin
      # Execute the block with the trace passed as argument
      result = yield(trace)
      result
    rescue StandardError => e
      # Capture any error
      error = e
      Kernel.raise # Use Kernel.raise
    ensure
      # Update trace output if available
      if result && trace.output.nil?
        # Assuming trace.output is writable and can be inferred or is T.untyped
        T.unsafe(trace).output = result # Use T.unsafe if Trace model type isn't fully defined

        # Create a new trace event to update the trace - Reuse trace object
        # This seems incorrect, updating should likely use an update method or modify the object
        # directly if it's mutable and the original trace object is used later.
        # Re-creating a trace event just to update seems wrong. Commenting out for now.
        # Langfuse.trace(
        #   id: trace.id,
        #   output: trace.output
        # )
      end

      # Ensure all events are sent (only in case of error, otherwise let the automatic flushing handle it)
      T.unsafe(Langfuse).flush if error
    end
  end

  # Create a trace and set it as the current context
  sig do
    params(
      name: String,
      user_id: T.nilable(String),
      attributes: T::Hash[Symbol, T.untyped],
      block: T.proc.params(trace: ::Langfuse::Models::Trace).void
    ).void
  end
  def with_context_trace(name:, user_id: nil, **attributes, &block)
    trace = T.unsafe(Langfuse).trace(
      name: name,
      user_id: user_id,
      **attributes
    )

    LangfuseContext.with_trace(trace) do
      block.call(trace)
    end
  end

  # Create a span using the current trace context
  sig do
    params(
      name: String,
      input: T.untyped,
      attributes: T::Hash[Symbol, T.untyped],
      block: T.proc.params(span: ::Langfuse::Models::Span).returns(T.untyped)
    ).returns(T.untyped)
  end
  def with_context_span(name:, input: nil, **attributes, &block)
    # Get trace_id from context
    trace_id = LangfuseContext.current_trace_id
    parent_id = LangfuseContext.current_span_id

    # Use Kernel.raise
    Kernel.raise 'No trace context found. Make sure to call within with_context_trace' if trace_id.nil?

    span = T.unsafe(Langfuse).span(
      name: name,
      trace_id: T.must(trace_id), # Must be present due to check above
      parent_observation_id: parent_id,
      input: input,
      **attributes
    )

    LangfuseContext.with_span(span) do
      # Pass the block to the implementation
      with_span_implementation(span, &block)
    end
  end

  # Add a score to a trace
  sig do
    params(
      trace_id: String,
      name: String,
      value: T.any(Integer, Float), # Assuming score value is numeric
      comment: T.nilable(String)
    ).void
  end
  def score_trace(trace_id:, name:, value:, comment: nil)
    T.unsafe(Langfuse).score(
      trace_id: trace_id,
      name: name,
      value: value,
      comment: comment
    )
  end

  private

  # Type the private helper method
  sig do
    params(
      span: ::Langfuse::Models::Span,
      block: T.proc.params(span: ::Langfuse::Models::Span).returns(T.untyped)
    ).returns(T.untyped)
  end
  def with_span_implementation(span, &block)
    T.let(Time.now, Time) # Use start_time
    result = T.let(nil, T.untyped)
    error = T.let(nil, T.nilable(StandardError))

    begin
      # Execute the block with the span passed as argument
      result = block.call(span) # Pass span to block
      result
    rescue StandardError => e
      # Capture any error
      error = e
      Kernel.raise # Use Kernel.raise
    ensure
      # Update span
      span.end_time = Time.now.utc
      # span.start_time = start_time.utc # Add start time if needed by update_span

      span.output = result if result && span.output.nil?

      if error
        span.level = 'ERROR'
        span.status_message = error.message
        span.metadata ||= {}
        backtrace = error.backtrace
        span.metadata[:error_backtrace] = backtrace.first(10) if backtrace # Check if backtrace is nil
      end

      T.unsafe(Langfuse).update_span(span)
    end
  end
end
