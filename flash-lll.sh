#!/usr/bin/env bash
# Flash a Mellow LLL Plus (Katapult, NO DFU) over USB.
#
# Usage:
#   ./flash-lll.sh <usb-Klipper_stm32f072xb_<UID>-if00 path> [path/to/klipper.bin]
#
# Example:
#   ./flash-lll.sh /dev/serial/by-id/usb-Klipper_stm32f072xb_3C003A000957465331323720-if00
#
# It uses Klipper's own Python (~/klippy-env) on purpose: that virtualenv already
# ships pyserial, so flashtool.py works without "pyserial not found" and without
# touching your system packages. The one-shot flashtool form auto-requests the
# bootloader from the running Klipper, waits for it to re-enumerate as Katapult,
# then uploads the firmware. No jumper, no DFU.
set -euo pipefail

DEV="${1:?Usage: flash-lll.sh <usb-Klipper_...-if00 path> [klipper.bin]}"
BIN="${2:-$HOME/klipper/out/klipper.bin}"
PY="$HOME/klippy-env/bin/python"
FLASHTOOL="$HOME/katapult/scripts/flashtool.py"

[ -e "$DEV" ]       || { echo "!! device not found: $DEV"; echo "   ls /dev/serial/by-id/ | grep usb-Klipper_stm32f072xb"; exit 1; }
[ -f "$BIN" ]       || { echo "!! firmware not found: $BIN"; exit 1; }
[ -x "$PY" ]        || { echo "!! klippy-env python not found: $PY"; exit 1; }
[ -f "$FLASHTOOL" ] || { echo "!! flashtool not found: $FLASHTOOL (git clone https://github.com/Arksine/katapult)"; exit 1; }

echo ">> stopping klipper (frees the USB serial port)"
sudo systemctl stop klipper
# Always bring Klipper back, even if the flash fails — never leave the printer offline.
trap 'echo ">> restarting klipper"; sudo systemctl start klipper' EXIT

echo ">> flashing $BIN"
echo "   via $DEV (auto reboot into Katapult, then upload)"
"$PY" "$FLASHTOOL" -d "$DEV" -f "$BIN"

echo ">> flash OK. Check klippy.log for the new 'Loaded MCU' version."
