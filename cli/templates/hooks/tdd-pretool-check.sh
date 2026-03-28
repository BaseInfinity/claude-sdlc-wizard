#!/bin/bash
# PreToolUse hook - TDD enforcement before editing source files
# Fires before Write/Edit/MultiEdit tools

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
