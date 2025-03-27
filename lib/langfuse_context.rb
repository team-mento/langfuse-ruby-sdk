class LangfuseContext
  def self.current
    Thread.current[:langfuse_context] ||= {}
  end

  def self.current_trace_id
    current[:trace_id]
  end

  def self.current_span_id
    current[:span_id]
  end

  def self.with_trace(trace)
    old_context = current.dup
    begin
      Thread.current[:langfuse_context] = { trace_id: trace.id }
      yield
    ensure
      Thread.current[:langfuse_context] = old_context
    end
  end

  def self.with_span(span)
    old_context = current.dup
    begin
      Thread.current[:langfuse_context] = current.merge({ span_id: span.id })
      yield
    ensure
      Thread.current[:langfuse_context] = old_context
    end
  end
end
