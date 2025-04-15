# Langfuse Ruby SDK: Type Verification Report - Client & Worker

## Overview

This document verifies and analyzes the control flow and return types for the `Langfuse::Client` and `Langfuse::BatchWorker` classes, extending the previous analysis of `Langfuse::ApiClient`.

---

## 1. `Langfuse::Client` Analysis (`lib/langfuse/client.rb`)

### 1.1. Method Signatures and Return Types

| Method                              | Parameters                                                             | Return Type (Inferred) | Notes                                                      |
| :---------------------------------- | :--------------------------------------------------------------------- | :--------------------- | :--------------------------------------------------------- |
| `initialize`                        | -                                                                      | `void`                 | Initializes state, schedules flush thread, sets exit hook. |
| `trace`                             | `attributes = {}` (`T::Hash[Symbol, T.untyped]`)                       | `Models::Trace`        | Creates and enqueues a trace event.                        |
| `span`                              | `attributes = {}` (`T::Hash[Symbol, T.untyped]`, requires `:trace_id`) | `Models::Span`         | Creates and enqueues a span event.                         |
| `update_span`                       | `span` (`Models::Span`)                                                | `Models::Span`         | Enqueues a span update event.                              |
| `generation`                        | `attributes = {}` (`T::Hash[Symbol, T.untyped]`, requires `:trace_id`) | `Models::Generation`   | Creates and enqueues a generation event.                   |
| `update_generation`                 | `generation` (`Models::Generation`)                                    | `Models::Generation`   | Enqueues a generation update event.                        |
| `event`                             | `attributes = {}` (`T::Hash[Symbol, T.untyped]`, requires `:trace_id`) | `Models::Event`        | Creates and enqueues an event event.                       |
| `score`                             | `attributes = {}` (`T::Hash[Symbol, T.untyped]`, requires `:trace_id`) | `Models::Score`        | Creates and enqueues a score event.                        |
| `flush`                             | -                                                                      | `void`                 | Sends batched events via `BatchWorker.perform_async`.      |
| `shutdown`                          | -                                                                      | `void`                 | Cancels timer, flushes remaining events.                   |
| `enqueue_event` (private)           | `event` (`Models::IngestionEvent`)                                     | `void`                 | Adds event to buffer, flushes if size limit reached.       |
| `schedule_periodic_flush` (private) | -                                                                      | `Thread`               | Returns the background flush thread.                       |
| `log` (private)                     | `message` (`String`), `level = :debug` (`Symbol`)                      | `T.nilable(T.untyped)` | Logs message if debug enabled.                             |

### 1.2. Key Findings

- The client uses a thread-safe `Concurrent::Array` for buffering events and a `Mutex` for atomic operations during flush.
- A background thread handles periodic flushing.
- An `at_exit` hook ensures remaining events are flushed on shutdown.
- All public event creation methods (`trace`, `span`, etc.) return the corresponding model object.
- Model types (`Models::Trace`, etc.) are assumed to be defined classes.

---

## 2. `Langfuse::BatchWorker` Analysis (`lib/langfuse/batch_worker.rb`)

This file conditionally defines the `BatchWorker` based on whether `Sidekiq` is loaded.

### 2.1. Base `BatchWorker` (No Sidekiq)

| Method               | Parameters                                           | Return Type (Inferred)       | Notes                          |
| :------------------- | :--------------------------------------------------- | :--------------------------- | :----------------------------- |
| `self.perform_async` | `events` (`T::Array[T::Hash[T.untyped, T.untyped]]`) | `T::Hash[String, T.untyped]` | Synchronously calls `perform`. |
| `perform`            | `events` (`T::Array[T::Hash[T.untyped, T.untyped]]`) | `T::Hash[String, T.untyped]` | Calls `ApiClient#ingest`.      |

### 2.2. Sidekiq `BatchWorker` (`defined?(Sidekiq)`)

| Method                           | Parameters                                                    | Return Type (Inferred) | Notes                                                         |
| :------------------------------- | :------------------------------------------------------------ | :--------------------- | :------------------------------------------------------------ |
| `perform`                        | `event_hashes` (`T::Array[T::Hash[T.untyped, T.untyped]]`)    | `void`                 | Calls `ApiClient#ingest`, handles errors, logs, may raise.    |
| `non_retryable_error?` (private) | `status` (`T.any(String, Integer)`)                           | `T::Boolean`           | Checks if HTTP status code indicates a non-retryable error.   |
| `store_failed_event` (private)   | `event` (`T::Hash[T.untyped, T.untyped]`), `error` (`String`) | `T.untyped`            | Stores failed event details in Redis, returns `rpush` result. |

### 2.3. Key Findings

- The worker acts as a synchronous pass-through to `ApiClient#ingest` if Sidekiq is not present.
- If Sidekiq is present, it becomes a proper `Sidekiq::Worker` with retry logic.
- The Sidekiq worker handles API responses, including partial failures (HTTP 207), logs errors, and stores permanently failed events (non-retryable 4xx errors) in Redis.
- It differentiates between network errors (retried by Sidekiq) and other potential API errors.

---

## 3. Conclusion

The analysis confirms the general structure and behavior of the `Client` and `BatchWorker`. Adding Sorbet types will involve:

- Defining types for the model objects (or using `T.untyped` initially).
- Typing the configuration object access (`@config`).
- Handling the conditional definition of `BatchWorker` for Sorbet.
- Using appropriate types for Hashes, Arrays, and basic types.

---

_Generated on 2025-04-14. Based on code analysis._
