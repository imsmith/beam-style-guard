# Info Checks — Consider Fixing

These are softer violations — code smells that may be intentional but should be documented.

## Process Dictionary Usage

**Principle**: 12 (Anti-Patterns)
**Detection**: `Process.put` or `Process.get` without an explanatory comment.

### Violation

```elixir
def init(opts) do
  Process.put(:request_id, opts[:request_id])
  {:ok, %{}}
end
```

### Fix (Option A: Remove it)

```elixir
def init(opts) do
  {:ok, %{request_id: opts[:request_id]}}
end
```

### Fix (Option B: Document if intentional)

```elixir
def init(opts) do
  # Process dictionary used for Logger metadata propagation across
  # spawned tasks. This is the standard OTP pattern for request tracing.
  Process.put(:request_id, opts[:request_id])
  {:ok, %{}}
end
```

### Notes

- The process dictionary is a global mutable store scoped to a process — it breaks functional reasoning.
- Legitimate uses: Logger metadata, telemetry context, testing scaffolding.
- If you use it, document *why* so the next reader doesn't remove it.

## Synchronous GenServer Call Chains

**Principle**: 6 (Message Passing), 12 (Anti-Patterns)
**Detection**: Multiple `GenServer.call` invocations within a single `handle_call`.

### Violation

```elixir
def handle_call(:process_order, _from, state) do
  {:ok, user} = GenServer.call(UserService, :get_current)
  {:ok, inventory} = GenServer.call(InventoryService, :check_stock)
  {:ok, payment} = GenServer.call(PaymentService, :charge)
  {:reply, {:ok, %{user: user, inventory: inventory, payment: payment}}, state}
end
```

### Fix

```elixir
# Use Task.async for parallel calls, or restructure as a pipeline
def handle_call(:process_order, _from, state) do
  tasks = [
    Task.async(fn -> UserService.get_current() end),
    Task.async(fn -> InventoryService.check_stock() end)
  ]

  [user_result, inventory_result] = Task.await_many(tasks, 5000)

  with {:ok, user} <- user_result,
       {:ok, inventory} <- inventory_result,
       {:ok, payment} <- PaymentService.charge(user) do
    {:reply, {:ok, %{user: user, inventory: inventory, payment: payment}}, state}
  else
    {:error, _} = error -> {:reply, error, state}
  end
end
```

### Notes

- Synchronous chains create deadlock risk and increase latency.
- Each `GenServer.call` blocks until the target replies — if the target calls back, you deadlock.
- Use `Task.async` for independent operations, or redesign as event-driven.

## Large or Unbounded GenServer State

**Principle**: 6 (Message Passing), 12 (Anti-Patterns)
**Detection**: Manual review — look for maps/lists in GenServer state that grow without bounds.

### Signs of Unbounded State

- State contains a map keyed by user ID, session ID, or request ID that never gets cleaned up.
- State accumulates a list of events/messages without periodic pruning.
- State mirrors data that should live in ETS, DETS, or a database.

### Fix Pattern

```elixir
# Instead of accumulating in GenServer state:
# Bad: %{messages: [msg | state.messages]}  # grows forever

# Use ETS for large datasets:
def init(_) do
  table = :ets.new(:messages, [:set, :public])
  {:ok, %{table: table}}
end

# Or use a DynamicSupervisor with process-per-entity:
DynamicSupervisor.start_child(MySupervisor, {MessageHandler, msg})
```

### Notes

- GenServer state lives in process memory — large state means large heaps and slow GC.
- If state exceeds a few hundred entries, consider ETS.
- If entries are independent, consider process-per-entity under DynamicSupervisor.
