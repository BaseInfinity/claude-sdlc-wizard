#!/bin/bash
# PreToolUse hook - TDD enforcement before editing source files
# Fires before Write/Edit/MultiEdit tools

# Token-bloat fix: when both project + plugin register this hook, plugin yields.
# Parameter-expansion-safe (no `dirname` dep): `%/*` strips trailing `/file`.
# Fallback `.` when BASH_SOURCE has no slash (direct invocation `bash hook.sh`).
HOOK_DIR="${BASH_SOURCE[0]%/*}"
[ "$HOOK_DIR" = "${BASH_SOURCE[0]}" ] && HOOK_DIR="."
# shellcheck disable=SC1091
source "$HOOK_DIR/_find-sdlc-root.sh"
dedupe_plugin_or_project "${BASH_SOURCE[0]}" || exit 0

# Read the tool input (JSON with file_path, content, etc.)
TOOL_INPUT=$(cat)

# Extract the file path being edited (requires jq)
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.tool_input.file_path // empty')

# CUSTOMIZE: Change this pattern to match YOUR source directory
# Examples: "/src/", "/app/", "/lib/", "/packages/", "/server/"
if [[ "$FILE_PATH" == *"/src/"* ]]; then
  # Output additionalContext that Claude will read
  cat << 'EOF'
{"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": "TDD CHECK: Are you writing IMPLEMENTATION before a FAILING TEST? If yes, STOP. Write the test first (TDD RED), then implement (TDD GREEN)."}}
EOF
fi

# No output = allow the tool to proceed
