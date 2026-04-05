# Firmware build system for multi-device SD card overlay
DEVICE ?= device-a
CONFIG := configs/$(DEVICE).cfg

.PHONY: build flash clean

build:
	$(CC) -o build/firmware.bin src/main.c -DDEVICE_CONFIG=\"$(CONFIG)\"

flash: build
	scripts/flash.sh /dev/ttyUSB0 build/firmware.bin $(CONFIG)

clean:
	rm -rf build/
