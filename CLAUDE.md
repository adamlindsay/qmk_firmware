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
