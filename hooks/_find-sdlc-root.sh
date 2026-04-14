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
