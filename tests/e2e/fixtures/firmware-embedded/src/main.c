/* Firmware entry point — SD card overlay manager */
#include <stdio.h>
#include <stdlib.h>

#ifndef DEVICE_CONFIG
#error "DEVICE_CONFIG must be defined at compile time"
#endif

int parse_config(const char *path);
int apply_overlay(const char *config_path, const char *mount_point);

int main(int argc, char *argv[]) {
    if (parse_config(DEVICE_CONFIG) != 0) {
        fprintf(stderr, "Failed to parse config: %s\n", DEVICE_CONFIG);
        return 1;
    }
    return apply_overlay(DEVICE_CONFIG, "/mnt/sdcard");
}
