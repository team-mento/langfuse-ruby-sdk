require_relative 'langfuse_context'

module LangfuseHelper
  # Execute a block within the context of a span
  def with_span(name:, trace_id:, parent_id: nil, input: nil, **attributes)
    # Create the span
    span = Langfuse.span(
      name: name,
      trace_id: trace_id,
      parent_observation_id: parent_id,
      input: input,
      **attributes
    )

    with_span_implementation(span) { yield(span) }
  end

  # Execute a block within the context of an LLM generation
  def with_generation(name:, trace_id:, model:, input:, parent_id: nil, model_parameters: {}, **attributes)
    # Create the generation
    generation = Langfuse.generation(
      name: name,
      trace_id: trace_id,
      parent_observation_id: parent_id,
      model: model,
      input: input,
      model_parameters: model_parameters,
      **attributes
    )

    Time.now
    result = nil
    error = nil

    begin
      # Execute the block with the generation passed as argument
      result = yield(generation)
      result
    rescue StandardError => e
      # Capture any error
      error = e
      raise
    ensure
      # Always update the generation with results
      generation.end_time = Time.now.utc

      # Add output if there was a result and it wasn't already set
      generation.output = result if result && !generation.output

      # Add error information if there was an error
      if error
        generation.level = 'ERROR'
        generation.status_message = error.message
        generation.metadata ||= {}
        generation.metadata[:error_backtrace] = error.backtrace.first(10) if error.backtrace
      end

      # Update the generation
      Langfuse.update_generation(generation)
    end
  end

  # Execute a block within the context of a trace
  def with_trace(name:, user_id: nil, **attributes)
    # Create the trace
    trace = Langfuse.trace(
      name: name,
      user_id: user_id,
      **attributes
    )

    result = nil
    error = nil

    begin
      # Execute the block with the trace passed as argument
      result = yield(trace)
      result
    rescue StandardError => e
      # Capture any error
      error = e
      raise
    ensure
      # Update trace output if available
      if result && !trace.output
        trace.output = result.is_a?(String) ? result : { result: result.to_s }

        # Create a new trace event to update the trace
        Langfuse.trace(
          id: trace.id,
          output: trace.output
        )
      end

      # Ensure all events are sent (only in case of error, otherwise let the automatic flushing handle it)
      Langfuse.flush if error
    end
  end

  # Create a trace and set it as the current context
  def with_context_trace(name:, user_id: nil, **attributes)
    trace = Langfuse.trace(
      name: name,
      user_id: user_id,
      **attributes
    )

    LangfuseContext.with_trace(trace) do
      yield(trace)
    end
  end

  # Create a span using the current trace context
  def with_context_span(name:, input: nil, **attributes)
    # Get trace_id from context
    trace_id = LangfuseContext.current_trace_id
    parent_id = LangfuseContext.current_span_id

    raise 'No trace context found. Make sure to call within with_context_trace' if trace_id.nil?

    span = Langfuse.span(
      name: name,
      trace_id: trace_id,
      parent_observation_id: parent_id,
      input: input,
      **attributes
    )

    LangfuseContext.with_span(span) do
      # Execute the block with the span
      with_span_implementation(span) { yield(span) }
    end
  end

  # Add a score to a trace
  def score_trace(trace_id:, name:, value:, comment: nil)
    Langfuse.score(
      trace_id: trace_id,
      name: name,
      value: value,
      comment: comment
    )
  end

  private

  def with_span_implementation(span)
    Time.now
    result = nil
    error = nil

    begin
      # Execute the block with the span passed as argument
      result = yield
      result
    rescue StandardError => e
      # Capture any error
      error = e
      raise
    ensure
      # Update span
      span.end_time = Time.now.utc
      span.output = result if result && !span.output

      if error
        span.level = 'ERROR'
        span.status_message = error.message
        span.metadata ||= {}
        span.metadata[:error_backtrace] = error.backtrace.first(10) if error.backtrace
      end

      Langfuse.update_span(span)
    end
  end
end
