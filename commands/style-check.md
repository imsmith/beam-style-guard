---
name: style-check
description: Full BEAM/Elixir style guide audit — scores project against all 12 principles
allowed-tools:
  - Glob
  - Grep
  - Read
  - Task
---

You are performing a comprehensive BEAM/Elixir Style Guide audit on this project. Score the project against all 12 principles from the BEAM Style Guide.

## Procedure

1. **Find all Elixir source files**: Glob for `**/*.ex` and `**/*.exs` (excluding `deps/`, `_build/`, `.elixir_ls/`).

2. **For each principle, check every relevant file and score 1-10**:

### Principles to Audit

| # | Principle | What to Check |
|---|-----------|---------------|
| 1 | Behaviours as Contracts | Every `@callback` has `@doc` with error semantics. No `term()` or `any()` in callbacks. Return types are specific tagged tuples. |
| 2 | Protocols for Polymorphism | Protocol modules have `@moduledoc`, `@spec` on functions, `{:ok, _} \| {:error, _}` returns, doc examples. |
| 3 | Supervision Trees | GenServers are under supervisors. Named processes (`name: __MODULE__`). No manual `GenServer.start_link` outside supervision. |
| 4 | Data Models | Structs use `@enforce_keys`. Constructor functions exist (`new/1`, `new/2`). `valid?/1` present. `@type t` defined. |
| 5 | Let It Crash | Error tuples for expected failures. No bare `rescue` catch-alls. Unexpected errors allowed to crash. |
| 6 | Message Passing | Stateless where possible. No unbounded state accumulation in GenServers. Process-per-entity patterns used. |
| 7 | Registry | `Registry` used for process discovery. No raw PID passing between modules. |
| 8 | Public API | Facade modules hide GenServer.call/cast from callers. Clean separation between API and implementation. |
| 9 | Testing | `async: true` on test cases. `start_supervised!` used. `assert_receive`/`refute_receive` for messages. |
| 10 | Documentation | `@moduledoc` on every module. `@doc` with examples on public functions. `@spec` on public functions. |
| 11 | Organization | One module per file. File path matches module name. Structs in own files. |
| 12 | Anti-Patterns | No process dictionary (except documented). No catch-all rescue. No unbounded GenServer state. |

3. **Output format**:

```
# BEAM Style Guide Audit

**Project**: [project name]
**Date**: [today]
**Files scanned**: [count]

## Scores

| Principle | Score | Notes |
|-----------|-------|-------|
| 1. Behaviours | X/10 | ... |
| ... | ... | ... |

**Overall Score**: X.X/10

## Violations

### Critical (must fix)
- `file.ex:line` — Description of violation

### Warning (should fix)
- `file.ex:line` — Description of violation

### Info (consider fixing)
- `file.ex:line` — Description of violation

## Priority Fix List
1. [Most impactful fix first]
2. ...
```

4. **Be specific**: Always include `file:line` references. Don't just say "missing @moduledoc" — say which module in which file.

5. **Score honestly**: A score of 10 means perfect adherence. Most real codebases score 4-6 on first audit. Don't inflate scores.
