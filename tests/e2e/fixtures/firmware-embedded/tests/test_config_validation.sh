#!/bin/bash
# Config validation tests — device config parsing and constraint checks
# ~25% of firmware test suite per wizard guidance
set -e

echo "=== Config Validation Tests ==="

CONFIGS_DIR="configs"

# Validate all configs parse without errors
test_configs_parse() {
    for cfg in "$CONFIGS_DIR"/*.cfg; do
        local device
        device=$(basename "$cfg" .cfg)
        if python3 -c "
import configparser, sys
c = configparser.ConfigParser()
with open('$cfg') as f:
    c.read_string('[device]\n' + f.read())
print(dict(c['device']))
" > /dev/null 2>&1; then
            echo "PASS: $device config parses successfully"
        else
            echo "FAIL: $device config failed to parse"
            exit 1
        fi
    done
}

# Validate required fields present in all configs
test_required_fields() {
    local required="display_width display_height cpu_governor sdcard_mount"
    for cfg in "$CONFIGS_DIR"/*.cfg; do
        local device
        device=$(basename "$cfg" .cfg)
        for field in $required; do
            if grep -q "^${field}=" "$cfg"; then
                true
            else
                echo "FAIL: $device missing required field: $field"
                exit 1
            fi
        done
        echo "PASS: $device has all required fields"
    done
}

# Validate display dimensions are positive integers
test_display_dimensions() {
    for cfg in "$CONFIGS_DIR"/*.cfg; do
        local device width height
        device=$(basename "$cfg" .cfg)
        width=$(grep "^display_width=" "$cfg" | cut -d= -f2)
        height=$(grep "^display_height=" "$cfg" | cut -d= -f2)
        if [ "$width" -gt 0 ] 2>/dev/null && [ "$height" -gt 0 ] 2>/dev/null; then
            echo "PASS: $device has valid dimensions (${width}x${height})"
        else
            echo "FAIL: $device has invalid dimensions: ${width}x${height}"
            exit 1
        fi
    done
}

test_configs_parse
test_required_fields
test_display_dimensions

echo "=== Config Validation Tests: All passed ==="
