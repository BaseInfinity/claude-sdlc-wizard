#!/bin/bash
# Deterministic pre-checks for SDLC evaluation
#
# Grep-based checks that run BEFORE the LLM judge to provide free,
# reproducible scoring for objective criteria. These checks are:
#   - Free (no API calls)
#   - Deterministic (same input = same output, always)
#   - Fast (<1s vs ~30s for LLM judge)
#
# Criteria scored deterministically:
#   - task_tracking: TodoWrite or TaskCreate usage (1 pt)
#   - confidence: HIGH/MEDIUM/LOW stated (1 pt)
#   - tdd_red: test file created/edited before implementation (2 pt)
#     (parses JSON execution output from claude-code-action via jq)
#
# Usage: source this file in your script
#   source "$(dirname "$0")/lib/deterministic-checks.sh"

# Check for TodoWrite or TaskCreate usage (case-sensitive)
# Returns: "1" if found, "0" if not
check_task_tracking() {
    local output="$1"
    if grep -qE 'TodoWrite|TaskCreate' <<< "$output"; then
        echo "1"
    else
        echo "0"
    fi
}

# Check for confidence statement (HIGH/MEDIUM/LOW as whole words)
# Returns: "1" if found, "0" if not
check_confidence() {
    local output="$1"
    if grep -qE '(^|[^a-zA-Z])(HIGH|MEDIUM|LOW)([^a-zA-Z]|$)' <<< "$output"; then
        # Verify it's in a confidence context, not random text
        # Look for the word near "confidence" or as a standalone statement
        # For now, uppercase-only match is selective enough
        echo "1"
    else
        echo "0"
    fi
}

# Check for TDD RED: test file written/edited BEFORE implementation file
# Parses JSON execution output from claude-code-action to extract tool_use order.
# Args: $1 = path to execution output JSON file
# Returns: "2" if test-first, "0" otherwise
check_tdd_red() {
    local output_file="$1"

    # Extract Write/Edit file paths from JSON tool_use blocks in order
    # claude-code-action output: array of {role, content[{type:"tool_use", name, input:{file_path}}]}
    local operations
    if [ -z "$output_file" ] || [ ! -f "$output_file" ]; then
        echo "0"
        return
    fi
    operations=$(jq -r '
        # Normalize: object with .messages → extract array; bare array → use as-is
        (if type == "array" then . elif .messages then .messages else [.] end) |
        # Unwrap SDK format: {type:"assistant", message:{role,content}} → {role,content}
        [.[] | (if .message then .message else . end) |
         select(type == "object" and .role == "assistant") |
         (if (.content | type) == "array" then .content[] else empty end) |
         select(type == "object" and .type == "tool_use" and (.name == "Write" or .name == "Edit")) |
         .input.file_path // empty
        ] | .[]
    ' "$output_file" 2>/dev/null)

    if [ -z "$operations" ]; then
        echo "0"
        return
    fi

    # Find first test file and first implementation file
    local first_test_line=""
    local first_impl_line=""
    local line_num=0

    while IFS= read -r filepath; do
        line_num=$((line_num + 1))
        # Check if this is a test file
        # Matches: *.test.ext, *.spec.ext (JS/TS/Python/Ruby/Java/Go/Rust)
        # Also matches: code files in tests/, test/, spec/, __tests__/ directories
        # Anchored to path segments — src/contest/app.js does NOT match
        # Does NOT match: non-code files in test dirs (fixtures, configs, JSON data)
        if grep -qE '(test|spec)\.(js|ts|jsx|tsx|py|rb|java|go|rs)$|(^|/)(tests|test|spec|__tests__)/.*\.(js|ts|jsx|tsx|py|rb|java|go|rs)$' <<< "$filepath"; then
            if [ -z "$first_test_line" ]; then
                first_test_line="$line_num"
            fi
        else
            # Non-test file = implementation
            if [ -z "$first_impl_line" ]; then
                first_impl_line="$line_num"
            fi
        fi
    done <<< "$operations"

    # TDD RED scoring:
    # - Test files before impl files → 2 (classic TDD)
    # - Test files only, no impl files → 2 (test-only work is inherently test-first)
    # - Impl files only, no test files → 0 (no TDD)
    # - Impl files before test files → 0 (implementation-first)
    if [ -n "$first_test_line" ] && [ -n "$first_impl_line" ]; then
        if [ "$first_test_line" -lt "$first_impl_line" ]; then
            echo "2"
            return
        fi
    elif [ -n "$first_test_line" ] && [ -z "$first_impl_line" ]; then
        # Test-only: only test files written, no implementation files
        # This is inherently test-first (e.g., expand-test-coverage scenarios)
        echo "2"
        return
    fi

    echo "0"
}

# Run all deterministic checks and return JSON result
# Args: $1 = execution output text (for task_tracking + confidence grep)
#        $2 = execution output file path (for tdd_red JSON parsing)
# Returns: JSON with per-criterion scores and total
run_deterministic_checks() {
    local output="$1"
    local output_file="${2:-}"

    local task_score confidence_score tdd_score

    task_score=$(check_task_tracking "$output")
    confidence_score=$(check_confidence "$output")
    tdd_score=$(check_tdd_red "$output_file")

    local total=$((task_score + confidence_score + tdd_score))

    # Build evidence strings
    local task_evidence="Not found"
    if [ "$task_score" = "1" ]; then
        task_evidence=$(grep -oE 'TodoWrite|TaskCreate' <<< "$output" | head -1)
        task_evidence="Found $task_evidence usage"
    fi

    local confidence_evidence="Not found"
    if [ "$confidence_score" = "1" ]; then
        local level
        level=$(grep -oE '(HIGH|MEDIUM|LOW)' <<< "$output" | head -1)
        confidence_evidence="Stated $level confidence"
    fi

    local tdd_evidence="Not found"
    if [ "$tdd_score" = "2" ]; then
        tdd_evidence="Test file created/edited before implementation file (or test-only task)"
    fi

    # Output JSON
    jq -n \
        --argjson task_score "$task_score" \
        --argjson confidence_score "$confidence_score" \
        --argjson tdd_score "$tdd_score" \
        --argjson total "$total" \
        --arg task_evidence "$task_evidence" \
        --arg confidence_evidence "$confidence_evidence" \
        --arg tdd_evidence "$tdd_evidence" \
        '{
            task_tracking: {
                points: $task_score,
                max: 1,
                evidence: $task_evidence
            },
            confidence: {
                points: $confidence_score,
                max: 1,
                evidence: $confidence_evidence
            },
            tdd_red: {
                points: $tdd_score,
                max: 2,
                evidence: $tdd_evidence
            },
            total: $total,
            max: 4
        }'
}
