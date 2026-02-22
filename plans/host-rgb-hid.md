# Host-Controlled RGB LED System via Raw HID

## Context

The Framework 16 ANSI keyboard (RP2040, IS31FL3743A, 97 LEDs) already has a raw HID protocol for factory commands (command 0x0B in `factory.c`). This plan extends that protocol with new sub-commands to let a host Python script set individual LED colors in real time, enabling system status indicators, audio-reactive visualizations, and other effects. When the host script stops, the keyboard reverts to its normal RGB animation via a watchdog timeout.

## HID Protocol

All commands use byte 0 = `0x0B` (existing factory prefix), byte 1 = sub-command.

Inside `handle_factory_command`, the usable payload (`command_data`) is original bytes 2-31 = 30 bytes. With chunk_index consuming 1 byte, 29 bytes remain = 9 LEDs per chunk (27 bytes RGB + 2 spare).

### Sub-command 0x10: RGB_SET_CHUNK

```
Byte 0:  0x0B           (command ID)
Byte 1:  0x10           (sub-command)
Byte 2:  chunk_index    (0-10, which group of 9 LEDs)
Byte 3+: R,G,B triplets (up to 9 LEDs = 27 bytes)
```

- `start_led = chunk_index * 9`
- `count = min(9, 97 - start_led)`
- Chunks 0-9 have 9 LEDs each; chunk 10 has 7 LEDs (indices 90-96)
- 11 chunks for a full 97-LED update
- Each chunk resets the watchdog timer
- Auto-enters host mode on first chunk if not already active

### Sub-command 0x11: RGB_MODE_SET

```
Byte 2:  0x00 = exit host mode (revert to saved animation)
         0x01 = enter host mode
```

Optional -- sending any RGB_SET_CHUNK also auto-enters. Useful for graceful cleanup.

### Sub-command 0x12: RGB_STATUS (query/response)

```
Request:  byte 2 = 0x00
Response: byte 2 = host_mode_active (0/1)
          byte 3 = current rgb_matrix mode
          byte 4 = saved mode (to revert to)
          byte 5 = LED_COUNT (97)
          byte 6 = timeout_seconds (3)
```

## Firmware Changes

### 1. `keyboards/framework/factory.c` -- state + handlers

Add global state (guarded by `RGB_MATRIX_ENABLE`):

```c
bool     host_rgb_active = false;
uint8_t  host_rgb_saved_mode = 0;
uint32_t host_rgb_last_update = 0;
uint8_t  host_rgb_buffer[RGB_MATRIX_LED_COUNT][3] = {{0}};
#define HOST_RGB_TIMEOUT_MS 3000
```

Add `host_rgb_enter()` / `host_rgb_exit()` functions:
- `enter`: save current mode, switch to `RGB_MATRIX_CUSTOM_HOST_RGB`, reset timer
- `exit`: restore saved mode, clear active flag

Add enum values `f_rgb_set_chunk = 0x10`, `f_rgb_mode_set = 0x11`, `f_rgb_status = 0x12`.

Add three `case` blocks to `handle_factory_command` switch.

For the status response, modify `handle_factory_command` signature to also receive the original 32-byte buffer pointer and length (currently it only gets `command_data`). Minimally: pass an extra parameter for the raw buffer.

### 2. `keyboards/framework/factory.h` -- extern declarations

Add externs for `host_rgb_active`, `host_rgb_buffer`, `host_rgb_last_update`, `host_rgb_saved_mode`, plus `host_rgb_enter`/`host_rgb_exit` prototypes.

### 3. `keyboards/framework/ansi/keymaps/adamlindsay/rgb_matrix_user.inc` -- new file

Custom RGB matrix effect `HOST_RGB` that:
- Checks watchdog: if `timer_elapsed32(host_rgb_last_update) > HOST_RGB_TIMEOUT_MS`, calls `host_rgb_exit()` and returns
- Otherwise renders from `host_rgb_buffer` into `rgb_matrix_set_color` for each LED

Pattern follows existing examples (e.g., `keyboards/horrortroll/handwired_k552/keymaps/default/rgb_matrix_user.inc`).

### 4. `keyboards/framework/ansi/keymaps/adamlindsay/rules.mk` -- new file

```makefile
RGB_MATRIX_CUSTOM_USER = yes
```

### 5. `keyboards/framework/ansi/keymaps/adamlindsay/keymap.c` -- guard indicators

Add to `rgb_matrix_indicators_advanced_user`:
```c
extern bool host_rgb_active;
if (host_rgb_active) return false;
```

Host gets full pixel control; indicator overrides only apply during normal animation.

## Host-Side Python Script

### `host_rgb.py` (new file in repo root)

**Device detection**: Reuse the sysfs pattern from `flash.sh` -- scan `/sys/class/hidraw/*/device/uevent` for VID:PID `000032AC:00000012` with `input1` in phys path.

**FrameworkRGB class**:
- `__init__`: find and open hidraw device via `os.open(path, os.O_RDWR)`
- `set_led(index, r, g, b)`: write to local 97x3 framebuffer
- `set_all(r, g, b)`: fill framebuffer
- `flush()`: send 11 chunk packets to keyboard
- `send_mode(enable)`: explicit mode enter/exit
- `close()`: send mode exit, close fd

**Demos** (selectable via CLI args):
- `solid <r> <g> <b>` -- solid color with keepalive
- `rainbow` -- hue sweep across keys
- `cpu` -- CPU temperature on F-row (green-to-red gradient)

**Cleanup**: signal handlers for SIGINT/SIGTERM call `send_mode(False)` then close, so keyboard reverts immediately rather than waiting for timeout.

## Performance

- 11 chunks/frame x 32 bytes = 352 bytes/frame
- At 30 fps: 330 packets/sec (USB full-speed HID polls at 1000 Hz = 33% utilization)
- Watchdog check runs at ~60 Hz inside `rgb_matrix_task`, detection latency < 17ms

## File Summary

Create:
- `keyboards/framework/ansi/keymaps/adamlindsay/rules.mk`
- `keyboards/framework/ansi/keymaps/adamlindsay/rgb_matrix_user.inc`
- `host_rgb.py`

Modify:
- `keyboards/framework/factory.c`
- `keyboards/framework/factory.h`
- `keyboards/framework/ansi/keymaps/adamlindsay/keymap.c`

No changes to: `framework.c`, `ansi/config.h`, `rules.mk`, `flash.sh`

## Verification

1. Build: `nix-shell -p qmk "(python3.withPackages ...)" gcc-arm-embedded --run "make framework/ansi:adamlindsay"`
2. Flash: `./flash.sh`
3. Confirm normal LED animations still work (unchanged behavior when no host script running)
4. Run `python3 host_rgb.py rainbow` -- LEDs should show host-controlled rainbow
5. Ctrl+C the script -- LEDs should revert to animation within 3 seconds
6. Run `python3 host_rgb.py solid 255 0 0` -- all LEDs red, volume/media/brightness keys also red (no indicator override in host mode)
7. Kill -9 the script (no graceful cleanup) -- LEDs should revert after 3 seconds via watchdog
