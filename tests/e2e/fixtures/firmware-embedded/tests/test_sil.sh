#!/bin/bash
# SIL (Software-in-the-Loop) tests — emulated hardware validation
# ~60% of firmware test suite per wizard guidance
set -e

echo "=== SIL Tests ==="

# Test overlay resolution without real hardware
test_overlay_base_layer() {
    local result
    result=$(python3 overlay.py configs/device-a.cfg 2>&1)
    if echo "$result" | grep -q "base"; then
        echo "PASS: device-a gets base overlay layer"
    else
        echo "FAIL: device-a should get base overlay layer"
        exit 1
    fi
}

# Test hires layer triggers at 640+ width
test_overlay_hires_layer() {
    local result
    result=$(python3 overlay.py configs/device-b.cfg 2>&1)
    if echo "$result" | grep -q "hires"; then
        echo "PASS: device-b (640px) gets hires overlay layer"
    else
        echo "FAIL: device-b should get hires overlay layer"
        exit 1
    fi
}

# Test wifi layer triggers when wifi_interface present
test_overlay_wifi_layer() {
    local result
    result=$(python3 overlay.py configs/device-c.cfg 2>&1)
    if echo "$result" | grep -q "wifi"; then
        echo "PASS: device-c (wifi) gets wifi overlay layer"
    else
        echo "FAIL: device-c should get wifi overlay layer"
        exit 1
    fi
}

test_overlay_base_layer
test_overlay_hires_layer
test_overlay_wifi_layer

echo "=== SIL Tests: All passed ==="
