# Langfuse Go Client Implementation Details

This document provides a technical deep dive into the internals of the langfuse-go client, explaining how it implements the Langfuse API to collect metrics from Go applications. This can serve as a reference for implementing similar functionality in other languages like Ruby.

## 1. Repository Structure

The repository is organized into the following key components:

```
langfuse-go/
├── langfuse.go         # Main client implementation
├── model/              # Data models (structs) for the API
│   └── model.go        # Contains all API data structures
├── internal/           # Internal implementation details
│   └── pkg/
│       ├── api/        # HTTP client for API communication
│       │   ├── client.go   # API client implementation
│       │   ├── request.go  # Request data structures
│       │   └── response.go # Response data structures
│       └── observer/    # Background event processing
│           ├── handler.go  # Processes events in the background
│           ├── observer.go # Coordinates event collection and processing
│           └── queue.go    # Thread-safe queue for events
└── examples/           # Usage examples
```

## 2. Core Architecture

The client follows a clean architecture with several key components:

1. **Main Client (`Langfuse`)**: The entry point for applications using the library
2. **Data Models**: Go structs that map to the Langfuse API data structures
3. **Observer Pattern**: Asynchronous event collection and batch processing
4. **HTTP Client**: Handles API communication with the Langfuse backend

### 2.1 Event Dispatching Flow

```
Application -> Langfuse Client -> Observer -> Queue -> Handler -> API Client -> Langfuse API
```

1. Your application creates traces, spans, generations, etc. using the client
2. The client dispatches these as events to an observer
3. The observer queues these events
4. A background handler periodically flushes events in batches
5. The API client sends HTTP requests to the Langfuse API

## 3. Client Initialization

The client can be initialized in two ways:

### 3.1 Using Environment Variables

```go
l := langfuse.New(context.Background())
```

This reads configuration from environment variables:
- `LANGFUSE_HOST`: Langfuse API endpoint (defaults to "https://cloud.langfuse.com")
- `LANGFUSE_PUBLIC_KEY`: Public API key
- `LANGFUSE_SECRET_KEY`: Secret API key

### 3.2 Using Explicit Configuration

```go
l := langfuse.NewFromConfig(api.Config{
    Host:      "https://cloud.langfuse.com",
    PublicKey: "your-public-key",
    SecretKey: "your-secret-key",
}, context.Background())
```

## 4. Data Models

The client defines several key data structures that map to the Langfuse API schema:

### 4.1 IngestionEvent

```go
type IngestionEvent struct {
    Type      IngestionEventType `json:"type"`
    ID        string             `json:"id"`
    Timestamp time.Time          `json:"timestamp"`
    Metadata  any
    Body      any                `json:"body"`
}
```

This is the envelope structure that wraps all events sent to the API. The `type` field is a discriminator that identifies the kind of event.

### 4.2 Trace

```go
type Trace struct {
    ID        string     `json:"id,omitempty"`
    Timestamp *time.Time `json:"timestamp,omitempty"`
    Name      string     `json:"name,omitempty"`
    UserID    string     `json:"userId,omitempty"`
    Input     any        `json:"input,omitempty"`
    Output    any        `json:"output,omitempty"`
    SessionID string     `json:"sessionId,omitempty"`
    Release   string     `json:"release,omitempty"`
    Version   string     `json:"version,omitempty"`
    Metadata  any        `json:"metadata,omitempty"`
    Tags      []string   `json:"tags,omitempty"`
    Public    bool       `json:"public,omitempty"`
}
```

A trace represents a full execution of your application or a significant portion of it.

### 4.3 Span

```go
type Span struct {
    TraceID             string           `json:"traceId,omitempty"`
    Name                string           `json:"name,omitempty"`
    StartTime           *time.Time       `json:"startTime,omitempty"`
    Metadata            any              `json:"metadata,omitempty"`
    Input               any              `json:"input,omitempty"`
    Output              any              `json:"output,omitempty"`
    Level               ObservationLevel `json:"level,omitempty"`
    StatusMessage       string           `json:"statusMessage,omitempty"`
    ParentObservationID string           `json:"parentObservationId,omitempty"`
    Version             string           `json:"version,omitempty"`
    ID                  string           `json:"id,omitempty"`
    EndTime             *time.Time       `json:"endTime,omitempty"`
}
```

A span represents a specific operation within your application. It can have a start and end time.

### 4.4 Generation

```go
type Generation struct {
    TraceID             string           `json:"traceId,omitempty"`
    Name                string           `json:"name,omitempty"`
    StartTime           *time.Time       `json:"startTime,omitempty"`
    Metadata            any              `json:"metadata,omitempty"`
    Input               any              `json:"input,omitempty"`
    Output              any              `json:"output,omitempty"`
    Level               ObservationLevel `json:"level,omitempty"`
    StatusMessage       string           `json:"statusMessage,omitempty"`
    ParentObservationID string           `json:"parentObservationId,omitempty"`
    Version             string           `json:"version,omitempty"`
    ID                  string           `json:"id,omitempty"`
    EndTime             *time.Time       `json:"endTime,omitempty"`
    CompletionStartTime *time.Time       `json:"completionStartTime,omitempty"`
    Model               string           `json:"model,omitempty"`
    ModelParameters     any              `json:"modelParameters,omitempty"`
    Usage               Usage            `json:"usage,omitempty"`
    PromptName          string           `json:"promptName,omitempty"`
    PromptVersion       int              `json:"promptVersion,omitempty"`
}
```

A generation represents an LLM generation, including model information and token usage.

### 4.5 Score

```go
type Score struct {
    ID            string  `json:"id,omitempty"`
    TraceID       string  `json:"traceId,omitempty"`
    Name          string  `json:"name,omitempty"`
    Value         float64 `json:"value,omitempty"`
    ObservationID string  `json:"observationId,omitempty"`
    Comment       string  `json:"comment,omitempty"`
}
```

A score represents a quality score you can assign to a trace or observation.

### 4.6 Event

```go
type Event struct {
    TraceID             string           `json:"traceId,omitempty"`
    Name                string           `json:"name,omitempty"`
    StartTime           *time.Time       `json:"startTime,omitempty"`
    Metadata            any              `json:"metadata,omitempty"`
    Input               any              `json:"input,omitempty"`
    Output              any              `json:"output,omitempty"`
    Level               ObservationLevel `json:"level,omitempty"`
    StatusMessage       string           `json:"statusMessage,omitempty"`
    ParentObservationID string           `json:"parentObservationId,omitempty"`
    Version             string           `json:"version,omitempty"`
    ID                  string           `json:"id,omitempty"`
}
```

An event represents a point-in-time event in your application.

## 5. Observer Pattern Implementation

The observer pattern is used for asynchronous event collection and batch processing, which improves performance by reducing API calls.

### 5.1 Components

1. **Observer**: Coordinates event collection and processing
2. **Queue**: Thread-safe storage for events
3. **Handler**: Processes events in the background

### 5.2 Flow

1. When you call methods like `Trace()`, `Span()`, etc., the client creates an `IngestionEvent` and dispatches it to the observer.
2. The observer enqueues the event in a thread-safe queue.
3. A background handler periodically (default: 1 second) processes events in batches.
4. When events are processed, they are sent to the Langfuse API in a single batch request.

### 5.3 Dispatching Events

```go
func (l *Langfuse) Trace(t *model.Trace) (*model.Trace, error) {
    t.ID = buildID(&t.ID)
    l.observer.Dispatch(
        model.IngestionEvent{
            ID:        buildID(nil),
            Type:      model.IngestionEventTypeTraceCreate,
            Timestamp: time.Now().UTC(),
            Body:      t,
        },
    )
    return t, nil
}
```

### 5.4 Queue Implementation

The queue is a simple thread-safe data structure:

```go
type queue[T any] struct {
    sync.Mutex
    items []T
}

func (q *queue[T]) Enqueue(item T) {
    q.Lock()
    defer q.Unlock()
    q.items = append(q.items, item)
}

func (q *queue[T]) All() []T {
    q.Lock()
    defer q.Unlock()
    items := q.items
    q.items = []T{}
    return items
}
```

### 5.5 Event Handler

The handler processes events on a timer:

```go
func (h *handler[T]) listen(ctx context.Context) {
    ticker := time.NewTicker(h.tickerPeriod)

    for {
        select {
        case <-ticker.C:
            go h.handle(ctx)
        case cmd, ok := <-h.commandCh:
            if !ok {
                return
            }

            h.handle(ctx)
            if cmd == commandFlushAndWait {
                ticker.Stop()
                close(h.commandCh)
            }
        }
    }
}
```

## 6. API Client Implementation

The API client handles communication with the Langfuse API:

### 6.1 Client Configuration

```go
func NewFromConfig(cfg Config) *Client {
    restClient := restclientgo.New(cfg.Host)
    restClient.SetRequestModifier(func(req *http.Request) *http.Request {
        req.Header.Set("Authorization", basicAuth(cfg.PublicKey, cfg.SecretKey))
        return req
    })

    return &Client{
        restClient: restClient,
    }
}

func basicAuth(publicKey, secretKey string) string {
    auth := publicKey + ":" + secretKey
    return "Basic " + base64.StdEncoding.EncodeToString([]byte(auth))
}
```

### 6.2 Ingestion Endpoint

```go
func (c *Client) Ingestion(ctx context.Context, req *Ingestion, res *IngestionResponse) error {
    return c.restClient.Post(ctx, req, res)
}
```

The client sends a POST request to the `/api/public/ingestion` endpoint with the batch of events.

### 6.3 Request Structure

```go
type Ingestion struct {
    Batch []model.IngestionEvent `json:"batch"`
}

func (t *Ingestion) Path() (string, error) {
    return "/api/public/ingestion", nil
}
```

This matches the structure specified in the Langfuse API specification.

## 7. Usage Examples

Here's a complete example that demonstrates how to use the client:

```go
// Initialize the client
l := langfuse.New(context.Background())

// Create a trace
trace, err := l.Trace(&model.Trace{Name: "test-trace"})
if err != nil {
    panic(err)
}

// Create a span within the trace
span, err := l.Span(&model.Span{Name: "test-span", TraceID: trace.ID}, nil)
if err != nil {
    panic(err)
}

// Create a generation
generation, err := l.Generation(
    &model.Generation{
        TraceID: trace.ID,
        Name:    "test-generation",
        Model:   "gpt-3.5-turbo",
        ModelParameters: model.M{
            "maxTokens":   "1000",
            "temperature": "0.9",
        },
        Input: []model.M{
            {
                "role":    "system",
                "content": "You are a helpful assistant.",
            },
            {
                "role":    "user",
                "content": "Please generate a summary...",
            },
        },
    },
    &span.ID, // Link to the parent span
)
if err != nil {
    panic(err)
}

// Update the generation with output
generation.Output = model.M{
    "completion": "Generated text...",
}
_, err = l.GenerationEnd(generation)
if err != nil {
    panic(err)
}

// Add a score
_, err = l.Score(
    &model.Score{
        TraceID: trace.ID,
        Name:    "quality",
        Value:   0.9,
    },
)
if err != nil {
    panic(err)
}

// End the span
_, err = l.SpanEnd(span)
if err != nil {
    panic(err)
}

// Ensure all events are sent
l.Flush(context.Background())
```

## 8. Implementing a Ruby Client

When implementing a Ruby client, you should consider the following design patterns:

1. **Event Buffering**: Implement a similar event buffering system to reduce API calls.
2. **Background Processing**: Use Ruby threads or background workers to process events.
3. **API Compatibility**: Ensure your data structures map correctly to the Langfuse API schema.
4. **Configuration**: Support both environment variables and explicit configuration.
5. **Fluent API**: Make the API easy to use with a fluent interface.

Here's a sketch of what the API might look like in Ruby:

```ruby
# Initialize client
langfuse = Langfuse.new(
  host: "https://cloud.langfuse.com",
  public_key: "your-public-key",
  secret_key: "your-secret-key"
)

# Create a trace
trace = langfuse.trace(name: "test-trace")

# Create a span
span = langfuse.span(
  name: "test-span",
  trace_id: trace.id,
  parent_id: nil
)

# Create a generation
generation = langfuse.generation(
  name: "test-generation",
  trace_id: trace.id,
  parent_id: span.id,
  model: "gpt-3.5-turbo",
  model_parameters: {
    max_tokens: 1000,
    temperature: 0.9
  },
  input: [
    {role: "system", content: "You are a helpful assistant."},
    {role: "user", content: "Please generate a summary..."}
  ]
)

# Update generation with output
generation.output = {completion: "Generated text..."}
generation.end

# Add a score
langfuse.score(
  trace_id: trace.id,
  name: "quality",
  value: 0.9
)

# End the span
span.end

# Ensure all events are sent
langfuse.flush
```

## 9. Summary

The langfuse-go client provides a clean, efficient implementation of the Langfuse API for Go applications. It uses:

1. A simple, intuitive API for creating traces, spans, generations, etc.
2. An asynchronous event processing system for efficient batching
3. Thread-safe queuing for event collection
4. Automatic ID generation for new entities
5. Support for hierarchical relationships between entities
6. Flexible configuration options

This architecture can be adapted to other languages like Ruby by implementing similar components with language-appropriate idioms. 