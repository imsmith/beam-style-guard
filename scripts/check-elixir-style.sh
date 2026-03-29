#!/usr/bin/env bash
# beam-style-guard: PostToolUse hook for .ex/.exs files
# Reads hook JSON from stdin, checks the edited file against BEAM style rules.
# Exit 0 = no issues or not an Elixir file
# Exit 2 + JSON on stderr = violations found (fed back to Claude)

set -euo pipefail

# Read hook payload from stdin
PAYLOAD=$(cat)

# Extract file path from tool_input (works for both Write and Edit)
FILE_PATH=$(echo "$PAYLOAD" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Only check .ex and .exs files
case "$FILE_PATH" in
  *.ex|*.exs) ;;
  *) exit 0 ;;
esac

# Skip if file doesn't exist (edge case)
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

VIOLATIONS=""
VIOLATION_COUNT=0

add_violation() {
  local severity="$1"
  local message="$2"
  if [ -n "$VIOLATIONS" ]; then
    VIOLATIONS="${VIOLATIONS}, "
  fi
  VIOLATIONS="${VIOLATIONS}{\"severity\": \"${severity}\", \"message\": \"${message}\"}"
  VIOLATION_COUNT=$((VIOLATION_COUNT + 1))
}

# --- CRITICAL CHECKS ---

# Check: defmodule without @moduledoc
if grep -q 'defmodule ' "$FILE_PATH"; then
  MODULE_COUNT=$(grep -c 'defmodule ' "$FILE_PATH" || true)
  MODULEDOC_COUNT=$(grep -c '@moduledoc' "$FILE_PATH" || true)
  if [ "$MODULEDOC_COUNT" -lt "$MODULE_COUNT" ]; then
    add_violation "critical" "Missing @moduledoc: ${MODULE_COUNT} module(s) but only ${MODULEDOC_COUNT} @moduledoc(s). Every module needs @moduledoc."
  fi
fi

# --- WARNING CHECKS ---

# Check: defstruct without @enforce_keys
if grep -q 'defstruct' "$FILE_PATH"; then
  STRUCT_COUNT=$(grep -c 'defstruct' "$FILE_PATH" || true)
  ENFORCE_COUNT=$(grep -c '@enforce_keys' "$FILE_PATH" || true)
  if [ "$ENFORCE_COUNT" -lt "$STRUCT_COUNT" ]; then
    add_violation "warning" "Missing @enforce_keys: ${STRUCT_COUNT} defstruct(s) but only ${ENFORCE_COUNT} @enforce_keys. Structs should declare required fields."
  fi
fi

# Check: @callback without preceding @doc
if grep -q '@callback' "$FILE_PATH"; then
  CALLBACK_COUNT=$(grep -c '@callback' "$FILE_PATH" || true)
  # Count @doc tags that appear before @callback lines (rough heuristic)
  DOC_BEFORE_CALLBACK=0
  PREV_WAS_DOC=0
  while IFS= read -r line; do
    stripped=$(echo "$line" | sed 's/^[[:space:]]*//')
    if echo "$stripped" | grep -q '^@doc'; then
      PREV_WAS_DOC=1
    elif echo "$stripped" | grep -q '^@callback'; then
      if [ "$PREV_WAS_DOC" -eq 1 ]; then
        DOC_BEFORE_CALLBACK=$((DOC_BEFORE_CALLBACK + 1))
      fi
      PREV_WAS_DOC=0
    elif echo "$stripped" | grep -q '^@spec\|^@type\|^$'; then
      # @spec and @type between @doc and @callback are fine, blank lines too
      :
    else
      PREV_WAS_DOC=0
    fi
  done < "$FILE_PATH"
  if [ "$DOC_BEFORE_CALLBACK" -lt "$CALLBACK_COUNT" ]; then
    UNDOCUMENTED=$((CALLBACK_COUNT - DOC_BEFORE_CALLBACK))
    add_violation "warning" "Undocumented callbacks: ${UNDOCUMENTED} @callback(s) without preceding @doc. Callbacks should document semantics and error cases."
  fi
fi

# Check: bare rescue catch-all (rescue without specifying exception type)
if grep -qP 'rescue\s*$' "$FILE_PATH"; then
  # Look for patterns like "rescue\n  _ ->" or "rescue\n  e ->"
  if grep -qP '^\s+_\s*->' "$FILE_PATH" || grep -qP '^\s+\w+\s*->\s' "$FILE_PATH"; then
    # More precise: check if there's a rescue followed by a bare variable match
    BARE_RESCUE=$(awk '/^\s*rescue\s*$/{found=1; next} found && /^\s+[_a-z]\w*\s*(->|in)/{if($0 !~ /in [A-Z]/){print; found=0; next}} found && /^\s*[^ ]/{found=0}' "$FILE_PATH" | wc -l || true)
    if [ "$BARE_RESCUE" -gt 0 ]; then
      add_violation "warning" "Bare rescue catch-all detected. Specify exception types (e.g., rescue ArgumentError -> ...) or let unexpected errors crash per OTP philosophy."
    fi
  fi
fi

# Check: term() or any() in @callback definitions
if grep -q '@callback' "$FILE_PATH"; then
  GENERIC_CALLBACKS=$(grep '@callback' "$FILE_PATH" | grep -cP '\bterm\(\)|\bany\(\)' || true)
  if [ "$GENERIC_CALLBACKS" -gt 0 ]; then
    add_violation "warning" "Generic types in callbacks: ${GENERIC_CALLBACKS} @callback(s) use term() or any(). Use specific types for semantic clarity."
  fi
fi

# --- INFO CHECKS ---

# Check: Process.put / Process.get usage
PROC_DICT=$(grep -n 'Process\.put\|Process\.get' "$FILE_PATH" | head -5 || true)
if [ -n "$PROC_DICT" ]; then
  # Check if there's a comment on the same line or the line before
  UNCOMMENTED=0
  while IFS=: read -r linenum content; do
    PREV=$((linenum - 1))
    PREV_LINE=$(sed -n "${PREV}p" "$FILE_PATH" 2>/dev/null || true)
    if ! echo "$content" | grep -q '#' && ! echo "$PREV_LINE" | grep -q '#.*[Pp]rocess'; then
      UNCOMMENTED=$((UNCOMMENTED + 1))
    fi
  done <<< "$PROC_DICT"
  if [ "$UNCOMMENTED" -gt 0 ]; then
    add_violation "info" "Process dictionary usage detected without explanatory comment. Process dictionary is an anti-pattern; if intentional, add a comment explaining why."
  fi
fi

# --- OUTPUT ---

if [ "$VIOLATION_COUNT" -gt 0 ]; then
  BASENAME=$(basename "$FILE_PATH")
  SEVERITY_SUMMARY=""
  CRITICAL_COUNT=$(echo "[$VIOLATIONS]" | jq '[.[] | select(.severity == "critical")] | length' 2>/dev/null || echo 0)
  WARNING_COUNT_V=$(echo "[$VIOLATIONS]" | jq '[.[] | select(.severity == "warning")] | length' 2>/dev/null || echo 0)
  INFO_COUNT=$(echo "[$VIOLATIONS]" | jq '[.[] | select(.severity == "info")] | length' 2>/dev/null || echo 0)

  MSG="BEAM Style Guide violations in ${BASENAME}:\\n"
  if [ "$CRITICAL_COUNT" -gt 0 ]; then
    MSG="${MSG}\\n[CRITICAL] (${CRITICAL_COUNT}):"
  fi
  if [ "$WARNING_COUNT_V" -gt 0 ]; then
    MSG="${MSG}\\n[WARNING] (${WARNING_COUNT_V}):"
  fi
  if [ "$INFO_COUNT" -gt 0 ]; then
    MSG="${MSG}\\n[INFO] (${INFO_COUNT}):"
  fi

  # Build detailed message
  DETAIL=""
  for row in $(echo "[$VIOLATIONS]" | jq -r '.[] | @base64'); do
    decoded=$(echo "$row" | base64 -d)
    sev=$(echo "$decoded" | jq -r '.severity')
    msg=$(echo "$decoded" | jq -r '.message')
    DETAIL="${DETAIL}\\n- [${sev^^}] ${msg}"
  done

  SYSTEM_MSG="BEAM Style Guide violations in ${BASENAME}:${DETAIL}\\n\\nFix these before proceeding. Refer to the beam-style-rules skill for correct patterns."

  echo "{\"systemMessage\": \"${SYSTEM_MSG}\"}" >&2
  exit 2
fi

exit 0
