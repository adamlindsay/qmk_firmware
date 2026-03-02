#!/usr/bin/env bash
set -euo pipefail

# Flash Framework 16 ANSI keyboard firmware via USB HID bootloader command.
# Sends the same HID command the web configurator uses to enter bootloader,
# then copies the .uf2 file to the mass storage device that appears.

FIRMWARE="${1:-framework_ansi_adamlindsay.uf2}"
VID="0x32AC"
PID="0x0012"
MOUNT_TIMEOUT=10

if [ ! -f "$FIRMWARE" ]; then
    echo "Firmware file not found: $FIRMWARE"
    exit 1
fi

echo "Sending bootloader command to Framework keyboard ($VID:$PID)..."

# Find the raw HID interface (interface 1) via sysfs
HIDRAW=""
for dev in /sys/class/hidraw/hidraw*/device/uevent; do
    if grep -q "000032AC:00000012" "$dev" 2>/dev/null; then
        devdir="$(dirname "$dev")"
        phys=$(cat "$devdir/uevent" 2>/dev/null | grep HID_PHYS || true)
        # Interface 1 has input1 in the phys path
        if echo "$phys" | grep -q "input1"; then
            HIDRAW="/dev/$(basename "$(dirname "$devdir")")"
            break
        fi
    fi
done

if [ -z "$HIDRAW" ]; then
    echo "ERROR: Framework keyboard raw HID interface not found"
    exit 1
fi

echo "Using $HIDRAW"

# Send HID command via raw hidraw write (no external dependencies needed):
# byte 0 = 0x0B (VIA bootloader command ID),
# byte 1 = 0xFE (factory bootloader sub-command)
python3 -c "
import os, sys
data = bytearray(32)
data[0] = 0x0B
data[1] = 0xFE
fd = os.open('$HIDRAW', os.O_RDWR)
os.write(fd, bytes(data))
os.close(fd)
print('Bootloader command sent.')
"

echo "Waiting for RP2040 mass storage device..."
MOUNT_PATH=""
for i in $(seq 1 $MOUNT_TIMEOUT); do
    # RP2040 bootloader mounts as RPI-RP2; use findmnt to only match when actually mounted
    MOUNT_PATH=$(findmnt -rno TARGET -S LABEL=RPI-RP2 2>/dev/null || true)
    if [ -n "$MOUNT_PATH" ]; then
        break
    fi
    sleep 1
done

if [ -z "$MOUNT_PATH" ]; then
    echo "ERROR: RP2040 mass storage device did not appear within ${MOUNT_TIMEOUT}s."
    echo "Check lsblk and mount manually, then copy: $FIRMWARE"
    exit 1
fi

echo "Found RP2040 at $MOUNT_PATH"
echo "Copying $FIRMWARE..."
cp "$FIRMWARE" "$MOUNT_PATH/"
echo "Flash complete. Keyboard will reboot automatically."
