#!/bin/bash
# Shared JSON utilities for E2E evaluation scripts
#
# Usage: source this file in your script
#   source "$(dirname "$0")/lib/json-utils.sh"

# Extract JSON object from Claude's response
# Handles: raw JSON, markdown code fences, preamble text, multiline
#
# Args:
#   $1 - Raw response text from Claude API
#
# Returns:
#   Extracted JSON object (or empty string if extraction fails)
#
# Example:
#   EVAL_RESULT=$(extract_json "$RAW_RESULT")
#
extract_json() {
    local raw="$1"

    # Strip markdown code fences if present
    local cleaned
    cleaned=$(echo "$raw" | sed 's/^```json//; s/^```//; s/```$//')

    # Extract JSON: find first { to last } using perl (handles multiline)
    echo "$cleaned" | perl -0777 -ne 'print $1 if /(\{.*\})/s'
}

# Validate that a string is valid JSON
#
# Args:
#   $1 - String to validate
#
# Returns:
#   0 if valid JSON, 1 if invalid
#
is_valid_json() {
    local json="$1"
    [ -n "$json" ] && echo "$json" | jq -e '.' > /dev/null 2>&1
}
