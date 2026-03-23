#!/bin/bash
# "Prove It's Better" library
# Validates overlap paths and creates stripped fixture copies for A/B comparison.
#
# Usage:
#   source tests/e2e/lib/prove-it.sh
#   VALID=$(validate_removable_paths '["path1", "path2"]')
#   create_stripped_fixture /src /dst '["path1"]'

# Hardcoded allowlist of custom features that CAN be removed.
# Prevents LLM hallucination from deleting arbitrary files.
REMOVABLE_ALLOWLIST=(
    ".claude/hooks/sdlc-prompt-check.sh"
    ".claude/hooks/tdd-pretool-check.sh"
    ".claude/hooks/instructions-loaded-check.sh"
    ".claude/skills/sdlc/SKILL.md"
    ".claude/skills/testing/SKILL.md"
)

# Map hook files to their settings.json event key
hook_event_for_path() {
    case "$1" in
        ".claude/hooks/sdlc-prompt-check.sh") echo "UserPromptSubmit" ;;
        ".claude/hooks/tdd-pretool-check.sh") echo "PreToolUse" ;;
        ".claude/hooks/instructions-loaded-check.sh") echo "InstructionsLoaded" ;;
        *) echo "" ;;
    esac
}

# validate_removable_paths JSON_ARRAY
# Filters a JSON array of paths, returning only those in the allowlist.
# Output: one valid path per line (empty if none valid).
validate_removable_paths() {
    local INPUT="${1:-"[]"}"
    local PATHS
    PATHS=$(echo "$INPUT" | jq -r '.[]' 2>/dev/null) || return 0

    local VALID=""
    while IFS= read -r PATH_ENTRY; do
        [ -z "$PATH_ENTRY" ] && continue
        for ALLOWED in "${REMOVABLE_ALLOWLIST[@]}"; do
            if [ "$PATH_ENTRY" = "$ALLOWED" ]; then
                if [ -n "$VALID" ]; then
                    VALID="$VALID"$'\n'"$PATH_ENTRY"
                else
                    VALID="$PATH_ENTRY"
                fi
                break
            fi
        done
    done <<< "$PATHS"

    echo "$VALID"
}

# create_stripped_fixture SRC_DIR DST_DIR JSON_PATHS_ARRAY
# Copies SRC_DIR to DST_DIR, removes specified files, and updates settings.json.
create_stripped_fixture() {
    local SRC="$1"
    local DST="$2"
    local PATHS_JSON="${3:-"[]"}"

    # Copy entire fixture
    cp -R "$SRC/." "$DST/"

    # Get validated paths only
    local VALID_PATHS
    VALID_PATHS=$(validate_removable_paths "$PATHS_JSON")
    [ -z "$VALID_PATHS" ] && return 0

    # Remove each file and update settings.json for hooks
    local HOOKS_TO_REMOVE=()
    while IFS= read -r FILEPATH; do
        [ -z "$FILEPATH" ] && continue

        # Remove the file
        rm -f "$DST/$FILEPATH"

        # Track hook events to remove from settings.json
        local EVENT
        EVENT=$(hook_event_for_path "$FILEPATH")
        if [ -n "$EVENT" ]; then
            HOOKS_TO_REMOVE+=("$EVENT")
        fi
    done <<< "$VALID_PATHS"

    # Update settings.json if hooks were removed
    local SETTINGS="$DST/.claude/settings.json"
    if [ "${#HOOKS_TO_REMOVE[@]}" -gt 0 ] && [ -f "$SETTINGS" ]; then
        for EVENT in "${HOOKS_TO_REMOVE[@]}"; do
            local TMP
            TMP=$(mktemp)
            jq --arg event "$EVENT" 'del(.hooks[$event])' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
        done
    fi
}
