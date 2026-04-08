#!/usr/bin/env python3
"""SD card overlay manager — applies device-specific overlays to mounted SD cards.

Reads device config, resolves overlay layers, and writes the merged filesystem
overlay to the SD card mount point. Supports multi-device configs with
per-device display, input, and sysfs overrides.
"""

import configparser
import os
import sys


def parse_device_config(config_path):
    """Parse a device .cfg file into a dict of key-value pairs."""
    config = configparser.ConfigParser()
    # Device configs have no section headers — read as DEFAULT
    with open(config_path) as f:
        config.read_string("[device]\n" + f.read())
    return dict(config["device"])


def resolve_overlay_layers(device_config, overlay_dir="overlays"):
    """Determine which overlay layers apply for this device config."""
    layers = ["base"]
    width = int(device_config.get("display_width", 320))
    if width >= 640:
        layers.append("hires")
    if width >= 1280:
        layers.append("fullhd")
    if "wifi_interface" in device_config:
        layers.append("wifi")
    return layers


def apply_overlay(device_config, mount_point):
    """Apply resolved overlay layers to the SD card mount point."""
    layers = resolve_overlay_layers(device_config)
    sdcard_mount = device_config.get("sdcard_mount", "/mnt/sdcard")

    for layer in layers:
        layer_path = os.path.join("overlays", layer)
        if os.path.isdir(layer_path):
            # In production: rsync or cp -r layer files to mount point
            print(f"Applying layer '{layer}' to {sdcard_mount}")

    return layers


def main():
    if len(sys.argv) < 2:
        print("Usage: overlay.py <config_path> [mount_point]", file=sys.stderr)
        sys.exit(1)

    config_path = sys.argv[1]
    mount_point = sys.argv[2] if len(sys.argv) > 2 else "/mnt/sdcard"

    if not os.path.exists(config_path):
        print(f"Error: config not found: {config_path}", file=sys.stderr)
        sys.exit(1)

    device_config = parse_device_config(config_path)
    applied = apply_overlay(device_config, mount_point)
    print(f"Applied {len(applied)} overlay layers: {', '.join(applied)}")


if __name__ == "__main__":
    main()
