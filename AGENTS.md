# Framework QMK Firmware

## Build
- `nix-shell -p qmk "(python3.withPackages (ps: with ps; [ appdirs argcomplete colorama dotty-dict hid hjson jsonschema milc pygments pyserial pyusb pillow ]))" gcc-arm-embedded --run "make framework/ansi:adamlindsay"`
- Output: `framework_ansi_adamlindsay.uf2` in repo root
- Custom keymap: `keyboards/framework/ansi/keymaps/adamlindsay/keymap.c`

## Keymap Conventions
- Bottom row order: FN, Ctrl, Alt, GUI (swapped from default)
- QK_BOOT on FN+Backspace; FN+Delete remains Insert
- FN_LOCK on FN+ESC toggles F-row between media and F-keys
- RGB indicator overrides in `rgb_matrix_indicators_advanced_user` for function row groups
- LED colors: cyan=volume, green=media, amber=brightness

## Flash
- `./flash.sh` sends 0x0B/0xFE HID command via hidraw, then copies .uf2 to RPI-RP2 mount
- Use direct `os.write` to `/dev/hidraw*`, not Python `hidapi` (fails despite correct permissions)
- Interface 1 = raw HID / VIA; auto-detected via sysfs in flash.sh

## Raw HID
- VIA enabled; raw HID hooks in `factory.c` via `via_command_kb` / `handle_hid`
- Command 0x0B intercepted for factory commands (sub-command 0xFE = bootloader jump)
- Custom host-to-keyboard commands can be added to `handle_factory_command`
