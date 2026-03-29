#!/bin/bash
# Scenario selection for multi-scenario CI rotation
#
# Provides deterministic round-robin selection of scenarios
# based on PR number. Same PR always gets the same scenario,
# different PRs rotate through the pool.
#
# Usage: source this file in your script
#   source "$(dirname "$0")/lib/scenario-selector.sh"

# List all available scenario files (sorted for determinism)
# Args: $1 = scenarios directory
# Returns: one scenario path per line
list_scenarios() {
    local scenarios_dir="$1"
    ls "$scenarios_dir"/*.md 2>/dev/null | sort
}

# Extract fixture name from scenario's ## Fixture header
# Args: $1 = path to scenario .md file
# Returns: fixture name (defaults to "test-repo" if no header found)
get_fixture_for_scenario() {
    local scenario_file="$1"
    local fixture
    fixture=$(grep -m1 '^## Fixture' "$scenario_file" 2>/dev/null | sed 's/^## Fixture[: ]*//' | tr -d '[:space:]')
    if [ -z "$fixture" ]; then
        echo "test-repo"
    else
        echo "$fixture"
    fi
}

# Select a scenario based on PR number (deterministic round-robin)
# Args:
#   $1 = scenarios directory
#   $2 = PR number (or empty for push events)
# Returns: full path to selected scenario file
select_scenario() {
    local scenarios_dir="$1"
    local pr_number="$2"

    # Get sorted list of scenarios into array (portable, no mapfile)
    local scenarios=()
    while IFS= read -r line; do
        scenarios+=("$line")
    done < <(list_scenarios "$scenarios_dir")
    local count=${#scenarios[@]}

    if [ "$count" -eq 0 ]; then
        echo "Error: No scenarios found in $scenarios_dir" >&2
        return 1
    fi

    # For empty PR number (push events), use day-of-year for rotation
    # Force base-10 interpretation to avoid octal issues (e.g., day 008/009)
    if [ -z "$pr_number" ]; then
        pr_number=$((10#$(date +%j)))
    fi

    # Round-robin: PR number mod scenario count
    local index=$((pr_number % count))
    echo "${scenarios[$index]}"
}
