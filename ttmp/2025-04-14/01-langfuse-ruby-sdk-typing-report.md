# Langfuse Ruby SDK: Component and Typing Analysis Report

## Overview

This document provides a detailed mapping of the components in the `langfuse-ruby-sdk` and analyzes the type information for each class, method, and function. The analysis is based on the current codebase as of 2025-04-14.

---

## 1. Main Components

### 1.1. Entry Point: `lib/langfuse.rb`

- **Purpose:** Loads all core classes, models, and exposes the main API via the `Langfuse` module.
- **Key Methods:**
  - `Langfuse.configure { ... }` — yields a `Configuration` object.
  - Delegates: `trace`, `span`, `update_span`, `generation`, `update_generation`, `event`, `score`, `flush`, `shutdown` — all delegate to `Langfuse::Client.instance`.
- **Type Info:**
  - No explicit Sorbet or RBS types. All methods accept Ruby hashes or model objects.

### 1.2. Configuration: `lib/langfuse/configuration.rb`

- **Class:** `Langfuse::Configuration`
- **Attributes:**
  - `public_key: String?`
  - `secret_key: String?`
  - `host: String`
  - `batch_size: Integer`
  - `flush_interval: Integer`
  - `debug: Boolean`
  - `disable_at_exit_hook: Boolean`
  - `shutdown_timeout: Integer`
  - `logger: Logger`
- **Type Info:**
  - All attributes are set via environment variables or defaults. No explicit type annotations.

### 1.3. Client: `lib/langfuse/client.rb`

- **Class:** `Langfuse::Client` (Singleton)
- **Key Methods:**
  - `trace(attributes = {})` → `Models::Trace`
  - `span(attributes = {})` → `Models::Span`
  - `update_span(span)` → `Models::Span`
  - `generation(attributes = {})` → `Models::Generation`
  - `update_generation(generation)` → `Models::Generation`
  - `event(attributes = {})` → `Models::Event`
  - `score(attributes = {})` → `Models::Score`
  - `flush` → `nil`
  - `shutdown` → `nil`
- **Type Info:**
  - Accepts and returns model objects. Uses Ruby hashes for attributes. No static typing.
  - Thread safety via `Concurrent::Array` and `Mutex`.

### 1.4. API Client: `lib/langfuse/api_client.rb`

- **Class:** `Langfuse::ApiClient`
- **Key Methods:**
  - `initialize(config: Configuration)`
  - `ingest(events: Array<Hash>)` → `Hash` (parsed JSON response)
- **Type Info:**
  - Expects config object and array of event hashes. No static typing.

### 1.5. Batch Worker: `lib/langfuse/batch_worker.rb`

- **Class:** `Langfuse::BatchWorker`
- **Key Methods:**
  - `self.perform_async(events: Array<Hash>)`
  - `perform(events: Array<Hash>)`
- **Type Info:**
  - Synchronous fallback if Sidekiq is not present. If Sidekiq is present, includes `Sidekiq::Worker` and adds retry logic.

### 1.6. Context Helper: `lib/langfuse_context.rb`

- **Class:** `LangfuseContext`
- **Key Methods:**
  - `self.current` → `Hash`
  - `self.current_trace_id` → `String?`
  - `self.current_span_id` → `String?`
  - `self.with_trace(trace)`/`self.with_span(span)` — context management using thread-local storage.
- **Type Info:**
  - No explicit types. Context is a thread-local hash.

### 1.7. Helper Methods: `lib/langfuse_helper.rb`

- **Module:** `LangfuseHelper`
- **Key Methods:**
  - `with_span`, `with_generation`, `with_trace`, `with_context_trace`, `with_context_span`, `score_trace`
- **Type Info:**
  - All methods use keyword arguments and yield blocks. No static typing.

---

## 2. Model Classes (`lib/langfuse/models/`)

All models use `attr_accessor` for fields and accept a hash of attributes in their initializer. No static typing is present.

### 2.1. IngestionEvent

- **Fields:** `id: String`, `type: String`, `timestamp: String`, `body: Object`, `metadata: Hash?`
- **Type Info:**
  - `id` is a UUID string.
  - `timestamp` is an ISO8601 string.
  - `body` is a model object or hash.

### 2.2. Trace

- **Fields:** `id: String`, `name: String?`, `user_id: String?`, `input: Object?`, `output: Object?`, `session_id: String?`, `metadata: Hash?`, `tags: Array<String>?`, `public: Boolean?`, `release: String?`, `version: String?`, `timestamp: Time`, `environment: String?`
- **Type Info:**
  - `id` is a UUID string.
  - `timestamp` is a `Time` object, serialized as ISO8601.

### 2.3. Span

- **Fields:** `id: String`, `trace_id: String`, `name: String?`, `start_time: Time`, `end_time: Time?`, `metadata: Hash?`, `input: Object?`, `output: Object?`, `level: String?`, `status_message: String?`, `parent_observation_id: String?`, `version: String?`, `environment: String?`
- **Type Info:**
  - `id` and `trace_id` are UUID strings.
  - `start_time`/`end_time` are `Time` objects, serialized as ISO8601.

### 2.4. Generation

- **Fields:** `id: String`, `trace_id: String`, `name: String?`, `start_time: Time`, `end_time: Time?`, `metadata: Hash?`, `input: Object?`, `output: Object?`, `level: String?`, `status_message: String?`, `parent_observation_id: String?`, `version: String?`, `environment: String?`, `completion_start_time: Time?`, `model: String?`, `model_parameters: Hash?`, `usage: Usage?`, `prompt_name: String?`, `prompt_version: String?`
- **Type Info:**
  - `usage` is a `Usage` model or hash.

### 2.5. Event

- **Fields:** `id: String`, `trace_id: String`, `name: String?`, `start_time: Time`, `metadata: Hash?`, `input: Object?`, `output: Object?`, `level: String?`, `status_message: String?`, `parent_observation_id: String?`, `version: String?`, `environment: String?`

### 2.6. Score

- **Fields:** `id: String`, `trace_id: String`, `name: String?`, `value: Numeric?`, `observation_id: String?`, `comment: String?`, `data_type: String?`, `config_id: String?`, `environment: String?`

### 2.7. Usage

- **Fields:** `input: Numeric?`, `output: Numeric?`, `total: Numeric?`, `unit: String?`, `input_cost: Numeric?`, `output_cost: Numeric?`, `total_cost: Numeric?`, `prompt_tokens: Integer?`, `completion_tokens: Integer?`, `total_tokens: Integer?`

---

## 3. Typing Summary

- **No static typing** (Sorbet, RBS, etc.) is present in the SDK.
- **All type information is implicit** and based on Ruby conventions, docstrings, and field names.
- **Model fields** are dynamically assigned and can be `nil` unless otherwise required by logic.
- **API and client methods** accept and return Ruby hashes or model objects.

---

## 4. Recommendations

- For stricter type safety, consider adding Sorbet or RBS signatures.
- Document expected types in YARD docstrings for better developer experience.

---

## 5. Key Files

- `lib/langfuse.rb` — Entry point
- `lib/langfuse/client.rb` — Main client logic
- `lib/langfuse/api_client.rb` — API communication
- `lib/langfuse/batch_worker.rb` — Background processing
- `lib/langfuse/models/` — Data models
- `lib/langfuse_helper.rb` — Helper methods
- `lib/langfuse_context.rb` — Context management

---

_Generated on 2025-04-14. For updates, re-run this analysis._
