#!/bin/bash
# At session startup, maliit-keyboard picks its Qt primary screen from the first
# wl_output KWin announces — which is HDMI-A-1 on this RPi (GPU enumerates HDMI
# before DSI). This makes the OSK appear on HDMI-A-1 regardless of window focus.
#
# Fix: briefly disable HDMI-A-1, then let KWin restart maliit-keyboard. It starts
# with only DSI-1 visible, making DSI-1 Qt's primaryScreen(). Qt does not
# reassign primaryScreen when HDMI-A-1 is later re-enabled, so the fix holds
# for the entire session.

# Wait for the Plasma session to be fully up (KWin, maliit-keyboard, etc.)
sleep 10

# Disable HDMI-A-1 output
kscreen-doctor output.HDMI-A-1.disable
sleep 1

# Kill maliit-keyboard — KWin restarts it automatically while HDMI-A-1 is gone
pkill maliit-keyboard
sleep 4

# Re-enable HDMI-A-1
kscreen-doctor output.HDMI-A-1.enable
