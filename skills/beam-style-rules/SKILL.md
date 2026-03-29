---
name: beam-style-rules
description: >
  BEAM/Elixir style guide rules for writing idiomatic OTP code.
  Triggers when writing or editing Elixir (.ex/.exs) files.
  Covers behaviours, protocols, supervision, data models, error handling,
  message passing, Registry, API design, testing, documentation, organization,
  and anti-patterns.
globs:
  - "**/*.ex"
  - "**/*.exs"
---

# BEAM/Elixir Style Rules

When writing or editing Elixir code, follow these 12 principles. They are ordered by importance.

## 1. Behaviours as Contracts

- Every `@callback` MUST have a `@doc` describing semantics, expected inputs, and all possible return values including error cases.
- Use specific types in callbacks, never `term()` or `any()` — use domain types like `Event.t()`, `String.t()`, etc.
- Return tagged tuples: `:ok | {:ok, result} | {:error, :specific_atom}`.
- Document error atoms explicitly.

## 2. Protocols

- Protocol modules MUST have `@moduledoc` explaining purpose and when to implement.
- Every protocol function needs `@spec` and `@doc` with examples.
- Implementations should return `{:ok, _} | {:error, _}` consistently.

## 3. Supervision Trees

- Every GenServer MUST be started under a supervisor, never standalone.
- Use `name: __MODULE__` for named processes — never pass PIDs to callers.
- Define a `start_link/1` that accepts keyword opts.
- Group related processes under a dedicated Supervisor module.

## 4. Data Models (Structs)

- Every `defstruct` MUST have a preceding `@enforce_keys` with required fields.
- Define `@type t :: %__MODULE__{}` with all field types.
- Provide constructor functions: `new/1` or `new/2`.
- Include `valid?/1` for runtime validation.
- Structs belong in their own files, named after the struct.

## 5. Let It Crash

- Return error tuples (`{:error, :reason}`) for **expected** failures (network, user input, not found).
- Let **unexpected** errors crash — the supervisor restarts the process.
- NEVER use bare `rescue` that catches all exceptions. If you must rescue, specify the exception type:
  ```elixir
  # Bad
  rescue _ -> :error

  # Good
  rescue ArgumentError -> {:error, :invalid_argument}
  ```

## 6. Message Passing Over Shared State

- Keep GenServer state minimal and bounded.
- Prefer process-per-entity over one process managing a large map.
- Use `DynamicSupervisor` for spawning entity processes.
- Never accumulate unbounded lists or maps in GenServer state.

## 7. Registry for Process Discovery

- Use `Registry` (`:unique` or `:duplicate` keys) instead of passing PIDs.
- Register processes by name or role during `init/1`.
- Look up processes via `Registry.lookup/2`, never store PIDs in module attributes or config.

## 8. Public API Design

- Create a facade module (e.g., `Comn.Events`) that exposes the public API.
- Never expose `GenServer.call/2` or `GenServer.cast/2` to callers — wrap in named functions.
- Keep implementation modules (GenServers, workers) internal.

## 9. Testing

- Use `async: true` in `ExUnit.Case` unless tests share state.
- Start processes with `start_supervised!/1`, not manual `start_link`.
- Use `assert_receive/2` and `refute_receive/2` for message assertions.
- Test expected error returns, not just happy paths.

## 10. Documentation

- Every module MUST have `@moduledoc` (use `@moduledoc false` only for private implementation modules).
- Every public function MUST have `@doc` with at least one example.
- Every public function MUST have `@spec`.
- Callback modules need `@doc` on each `@callback`.

## 11. Code Organization

- One module per file.
- File path must match module name: `Comn.Events.NATS` → `lib/comn/events/nats.ex`.
- Struct modules go in their own files (e.g., `event_struct.ex` for `Comn.EventStruct`).
- Group related modules under a common directory.

## 12. Anti-Patterns to Avoid

- **No process dictionary**: Never use `Process.put/2` or `Process.get/1` unless you document exactly why (e.g., Logger metadata).
- **No catch-all rescue**: Never `rescue _ ->` or `rescue e ->` without specifying types.
- **No unbounded state**: GenServer state must not grow without bound.
- **No synchronous chains**: Don't chain multiple `GenServer.call` in a single `handle_call`.
- **No PID leaking**: Don't return or accept raw PIDs in public APIs.

---

For detailed check descriptions, examples of violations, and fix patterns, see:
- `references/critical-checks.md` — Must-fix violations
- `references/warning-checks.md` — Should-fix violations
- `references/info-checks.md` — Consider-fixing violations
