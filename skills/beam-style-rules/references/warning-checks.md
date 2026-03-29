# Warning Checks — Should Fix

These violations indicate patterns that deviate from BEAM idioms. Code works but isn't idiomatic.

## Missing `@enforce_keys` on Structs

**Principle**: 4 (Data Models)
**Detection**: `defstruct` without preceding `@enforce_keys`.

### Violation

```elixir
defmodule Comn.EventStruct do
  defstruct [:id, :type, :timestamp, :payload, :metadata]
end
```

### Fix

```elixir
defmodule Comn.EventStruct do
  @enforce_keys [:id, :type, :timestamp]
  defstruct [:id, :type, :timestamp, :payload, :metadata]
end
```

### Notes

- `@enforce_keys` catches missing required fields at compile time.
- Only enforce truly required fields — optional fields stay unenforced.
- This prevents silent bugs from `%EventStruct{}` with nil required fields.

## Undocumented `@callback`

**Principle**: 1 (Behaviours as Contracts)
**Detection**: `@callback` without preceding `@doc`.

### Violation

```elixir
@callback publish_event(event :: Event.t(), opts :: keyword()) ::
  :ok | {:error, term()}
```

### Fix

```elixir
@doc """
Publishes an event to the backend.

Called by `Comn.Events.broadcast/2` for each registered adapter.
The implementation should handle connection failures gracefully
and return a specific error atom.

## Returns
  - `:ok` — event successfully published
  - `{:error, :not_connected}` — backend is disconnected
  - `{:error, :invalid_event}` — event failed validation
"""
@callback publish_event(event :: Event.t(), opts :: keyword()) ::
  :ok | {:error, :not_connected | :invalid_event}
```

### Notes

- Callbacks define a contract. The `@doc` is the prose description of that contract.
- Document all possible error returns explicitly.
- Without docs, implementors have to guess what the callback expects.

## Generic Types in Callbacks (`term()`, `any()`)

**Principle**: 1 (Behaviours as Contracts)
**Detection**: `@callback` line containing `term()` or `any()`.

### Violation

```elixir
@callback handle(data :: any()) :: any()
@callback process(input :: term()) :: term()
```

### Fix

```elixir
@callback handle(data :: EventStruct.t()) :: :ok | {:error, :invalid_data | :processing_failed}
@callback process(input :: String.t()) :: {:ok, map()} | {:error, :parse_error}
```

### Notes

- `term()` and `any()` provide zero information to implementors.
- Use domain-specific types: `Event.t()`, `String.t()`, `map()`, etc.
- If the type truly is polymorphic, define a union type and document it.

## Bare Rescue Catch-All

**Principle**: 5 (Let It Crash)
**Detection**: `rescue` block with `_ ->` or bare variable match without specifying exception type.

### Violation

```elixir
def parse(input) do
  try do
    Jason.decode!(input)
  rescue
    _ -> {:error, :parse_failed}
  end
end
```

### Fix

```elixir
def parse(input) do
  case Jason.decode(input) do
    {:ok, decoded} -> {:ok, decoded}
    {:error, %Jason.DecodeError{}} -> {:error, :invalid_json}
  end
end
```

### Notes

- Bare rescue hides real bugs — a typo in `Jason.deocde!` would be silently caught.
- Prefer using the non-bang version and pattern matching on error tuples.
- If you must rescue, specify the exception: `rescue Jason.DecodeError -> ...`.
- Let unexpected errors crash — the supervisor handles restart.
