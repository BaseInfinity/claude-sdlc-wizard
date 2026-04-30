#!/bin/bash
# Wizard installer library — ROADMAP #96 Phase 3 PR 1.
#
# Lays the wizard's hooks/skills/settings.json onto a target fixture's
# .claude/ directory. This is the "install the wizard into the project"
# semantic that closed-loop benchmarks need: it lets us measure
# wizard-installed Claude vs bare Claude on the same scenario.
#
# Source this file from orchestrators (local-shepherd.sh, lift-proof.sh)
# and call install_wizard_into_fixture() — single source of truth for what
# "the wizard installed into a project" means.
#
# Usage (sourced):
#   source "$REPO_ROOT/tests/e2e/lib/wizard-installer.sh"
#   install_wizard_into_fixture "$REPO_ROOT" "$target_fixture_dir"
#
# Args:
#   $1 source_dir    — repo root that has the canonical .claude/ tree
#   $2 target_dir    — directory that will receive .claude/ (must exist)
#
# Exit codes:
#   0 success
#   1 invalid args, missing source, or missing target
#
# Mirrors the behavior of the legacy local-shepherd `_build_strip_dir`
# helper that pre-Phase-3 inlined the cp commands.

install_wizard_into_fixture() {
    local source_dir="$1"
    local target_dir="$2"

    if [ -z "$source_dir" ] || [ -z "$target_dir" ]; then
        echo "Error: install_wizard_into_fixture requires <source_dir> <target_dir>" >&2
        return 1
    fi

    if [ ! -d "$source_dir" ]; then
        echo "Error: source_dir not found: $source_dir" >&2
        return 1
    fi
    if [ ! -d "$source_dir/.claude" ]; then
        echo "Error: source_dir lacks .claude/: $source_dir" >&2
        return 1
    fi

    if [ ! -d "$target_dir" ]; then
        echo "Error: target_dir not found: $target_dir" >&2
        return 1
    fi

    local target_claude="$target_dir/.claude"
    mkdir -p "$target_claude"

    # Copy hooks dir (executable shell scripts that wire the SDLC loop).
    if [ -d "$source_dir/.claude/hooks" ]; then
        cp -R "$source_dir/.claude/hooks" "$target_claude/"
    fi

    # Copy skills dir (markdown skill defs — sdlc, setup, update, feedback).
    # NOTE: the canonical .claude/skills entries are symlinks to ../../skills/.
    # cp -R follows symlinks by default on macOS bash, so this lands real files.
    if [ -d "$source_dir/.claude/skills" ]; then
        cp -RL "$source_dir/.claude/skills" "$target_claude/" 2>/dev/null \
            || cp -R "$source_dir/.claude/skills" "$target_claude/"
    fi

    # Copy settings.json (hook registration + permissions).
    if [ -f "$source_dir/.claude/settings.json" ]; then
        cp "$source_dir/.claude/settings.json" "$target_claude/"
    fi

    return 0
}
