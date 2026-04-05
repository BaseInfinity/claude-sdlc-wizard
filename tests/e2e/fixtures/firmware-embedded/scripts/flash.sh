#!/bin/bash
# Flash firmware to device via serial
set -e

SERIAL_PORT="${1:-/dev/ttyUSB0}"
FIRMWARE="$2"
CONFIG="$3"

if [ ! -c "$SERIAL_PORT" ]; then
    echo "Error: Serial port $SERIAL_PORT not found"
    exit 1
fi

echo "Flashing $FIRMWARE to $SERIAL_PORT with config $CONFIG..."
# Device-specific flash protocol would go here
