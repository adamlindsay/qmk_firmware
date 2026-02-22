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

# Send HID command: byte 0 = 0x0B (VIA bootloader command ID),
# byte 1 = 0xFE (factory bootloader sub-command)
# Interface 1 is the raw HID / VIA interface
nix-shell -p python3Packages.hidapi --run 'python3 -c "
import hid, sys

devs = [d for d in hid.enumerate() if d[\"vendor_id\"] == 0x32AC and d[\"product_id\"] == 0x0012 and d[\"interface_number\"] == 1]
if not devs:
    print(\"ERROR: Framework keyboard not found on USB\", file=sys.stderr)
    sys.exit(1)

h = hid.device()
h.open_path(devs[0][\"path\"])
# 32-byte report: command 0x0B, sub-command 0xFE
data = [0x00] * 32
data[0] = 0x0B
data[1] = 0xFE
h.write(data)
h.close()
print(\"Bootloader command sent.\")
"'

echo "Waiting for RP2040 mass storage device..."
MOUNT_PATH=""
for i in $(seq 1 $MOUNT_TIMEOUT); do
    # RP2040 bootloader mounts as RPI-RP2
    MOUNT_PATH=$(lsblk -o MOUNTPOINT,LABEL -nr 2>/dev/null | grep -i "RPI-RP2" | awk '{print $1}' || true)
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
