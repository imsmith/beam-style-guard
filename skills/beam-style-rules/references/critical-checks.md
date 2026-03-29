# Critical Checks — Must Fix

These violations indicate missing foundational elements that every Elixir module should have.

## Missing `@moduledoc`

**Principle**: 10 (Documentation)
**Detection**: `defmodule` present but no `@moduledoc` in the same module block.

### Violation

```elixir
defmodule Comn.Events.NATS do
  use GenServer

  def start_link(opts) do
    # ...
  end
end
```

### Fix

```elixir
defmodule Comn.Events.NATS do
  @moduledoc """
  NATS messaging adapter for the Comn event system.

  Connects to a NATS server and provides publish/subscribe operations.
  Started under `Comn.Events.Supervisor` — do not start manually.
  """

  use GenServer

  def start_link(opts) do
    # ...
  end
end
```

### Notes

- Every module needs `@moduledoc`. No exceptions for "simple" modules.
- Use `@moduledoc false` only for private implementation modules that are never called directly.
- The moduledoc should answer: What does this module do? When would you use it? How is it started/configured?

## Missing `@spec` on Public Functions

**Principle**: 10 (Documentation)
**Detection**: `def` (not `defp`) without preceding `@spec`.

### Violation

```elixir
def broadcast(topic, payload, opts \\ []) do
  GenServer.call(__MODULE__, {:broadcast, topic, payload, opts})
end
```

### Fix

```elixir
@spec broadcast(String.t(), term(), keyword()) :: :ok | {:error, :not_connected | :timeout}
def broadcast(topic, payload, opts \\ []) do
  GenServer.call(__MODULE__, {:broadcast, topic, payload, opts})
end
```

### Notes

- Specs serve as machine-checkable documentation.
- Dialyzer catches type mismatches only when specs exist.
- Use specific return types, not just `term()`.

## Missing `@doc` on Public Functions

**Principle**: 10 (Documentation)
**Detection**: `def` without preceding `@doc`.

### Violation

```elixir
def new(type, payload) do
  %__MODULE__{type: type, payload: payload, id: generate_id()}
end
```

### Fix

```elixir
@doc """
Creates a new event with an auto-generated ID and current timestamp.

## Examples

    iex> event = Comn.EventStruct.new(:user_created, %{user_id: 1})
    iex> event.type
    :user_created
"""
def new(type, payload) do
  %__MODULE__{type: type, payload: payload, id: generate_id()}
end
```
