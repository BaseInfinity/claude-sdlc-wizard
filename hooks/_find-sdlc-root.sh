#!/bin/bash
# Shared helper: walk up from CWD to find nearest SDLC.md + TESTING.md pair
# Sourced by sdlc-prompt-check.sh and instructions-loaded-check.sh
# Fixes #171: false-positive "SETUP NOT COMPLETE" in monorepos / nested projects

# find_sdlc_root — walks up from pwd, stops at $HOME (exclusive)
# Sets SDLC_ROOT to the found directory, or empty string if not found
find_sdlc_root() {
    local check_dir
    check_dir="$(pwd)"
    SDLC_ROOT=""
    while [ "$check_dir" != "/" ] && [ "$check_dir" != "$HOME" ] && [ -n "$check_dir" ]; do
        if [ -f "$check_dir/SDLC.md" ] && [ -f "$check_dir/TESTING.md" ]; then
            SDLC_ROOT="$check_dir"
            return 0
        fi
        check_dir="$(dirname "$check_dir")"
    done
    return 1
}

# find_partial_sdlc_root — walks up looking for EITHER SDLC.md OR TESTING.md
# Used to detect partial setup (one file exists but not both) vs not-an-SDLC-project
find_partial_sdlc_root() {
    local check_dir
    check_dir="$(pwd)"
    SDLC_ROOT=""
    while [ "$check_dir" != "/" ] && [ "$check_dir" != "$HOME" ] && [ -n "$check_dir" ]; do
        if [ -f "$check_dir/SDLC.md" ] || [ -f "$check_dir/TESTING.md" ]; then
            SDLC_ROOT="$check_dir"
            return 0
        fi
        check_dir="$(dirname "$check_dir")"
    done
    return 1
}

# dedupe_plugin_or_project — token-bloat fix.
# When a hook is registered via BOTH the project's `.claude/settings.json` AND
# a locally-installed wizard plugin (e.g., maintainer dogfooding the wizard
# while also having `~/.claude/plugins-local/sdlc-wizard-wrap/`), the same
# script fires twice per event = 2× tokens per prompt, 2× hook output noise.
#
# Resolution: plugin invocation yields if the project also registers the
# same hook by name. Project registration always wins (user-explicit).
# Consumer plugin-only installs (no project settings.json) still fire normally.
#
# Plugin path heuristic: $0 contains "/plugins-local/" or "/plugins/cache/".
#
# Usage:
#   source _find-sdlc-root.sh
#   dedupe_plugin_or_project || exit 0   # plugin yields when project registered
#
# Args (optional, for tests): $1 script_path, $2 project_dir
# Returns: 0 = proceed, 1 = yield (caller should exit 0).
#
# Codex review hardening (DEDUPE-001/002):
# - Uses parameter expansion (${path##*/}) instead of `basename` — survives
#   PATH-restricted environments. Falsely emitting `basename: command not found`
#   would corrupt the rc=1 (yield) signal.
# - Matches the script name only inside a `"command"` JSON field, not anywhere
#   in the settings file. Otherwise a basename mentioned in `permissions.allow`
#   or a comment would falsely trigger yield (plugin would skip when project
#   never actually registers the hook).
dedupe_plugin_or_project() {
    local script_path="${1:-${BASH_SOURCE[1]:-$0}}"
    local project_dir="${2:-${CLAUDE_PROJECT_DIR:-.}}"

    case "$script_path" in
        */plugins-local/*|*/plugins/cache/*)
            local proj_settings="$project_dir/.claude/settings.json"
            [ -f "$proj_settings" ] || return 0

            # Parameter-expansion basename: ${path##*/} strips up to last /.
            # If no / in path, returns path itself (defensive — caller passed
            # bare filename).
            local script_name="${script_path##*/}"
            [ -n "$script_name" ] || return 0

            # Match only inside a "command" JSON registration so a basename
            # appearing in permissions.allow / comments / unrelated sections
            # doesn't falsely yield. Pattern: `"command"` followed by colon,
            # any whitespace, optional quotes, anything, then the basename.
            # Example matches:
            #   "command": "$CLAUDE_PROJECT_DIR/hooks/sdlc-prompt-check.sh"
            #   "command":"hooks/sdlc-prompt-check.sh"
            # Does NOT match:
            #   "Bash(./hooks/sdlc-prompt-check.sh *)"  (in permissions.allow)
            if grep -qE '"command"[[:space:]]*:[[:space:]]*"[^"]*'"$script_name"'"' "$proj_settings" 2>/dev/null; then
                return 1  # yield — project will fire its own copy
            fi
            ;;
    esac
    return 0  # proceed
}
