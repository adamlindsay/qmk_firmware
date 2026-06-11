// Copyright 2024 Adam Lindsay
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

// Home-row mods tap-hold tuning. Achordion (see keymap.c) makes the hold-vs-tap
// decision itself based on which hand the next key is on.
//
// Do NOT enable PERMISSIVE_HOLD or HOLD_ON_OTHER_KEY_PRESS: Achordion already
// settles a mod as held the instant an opposite-hand key is pressed, and it
// re-plumbs that key. PERMISSIVE_HOLD makes QMK *also* flush the interrupting
// key's tap, double-emitting the first key after a hold (observed: "hold J, tap
// X" yielded "XX" then "X"). Let QMK's default tap-hold sit under Achordion.
#define TAPPING_TERM 175        // ms a key must be held to register as a mod
#define QUICK_TAP_TERM 120      // double-tap-then-hold still auto-repeats the letter
