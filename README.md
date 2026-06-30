# 🚀 Flash the Mellow LLL Plus over USB — no DFU, no reset button

![MCU](https://img.shields.io/badge/MCU-STM32F072CB-green)
![Bootloader](https://img.shields.io/badge/bootloader-Katapult-blue)
![Flashing](https://img.shields.io/badge/flashing-no--DFU%20over%20USB-brightgreen)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

**Flash your Mellow FLY *LLL Buffer Plus* over a plain USB cable.**
Install [Katapult](https://github.com/Arksine/katapult) *once* (a single DFU), and every future Klipper update is one command over the USB cable that's already plugged in — no case opening, no jumper, no reset dance.

This guide is **board-specific and tested on real hardware**, and it fixes the two things that actually trip people up on the LLL Plus:

> **Gotcha #1 — the reset trick doesn't work here.** The popular LLL Plus guides tell you to *"double-tap the reset button to enter Katapult."* The LLL Plus has **no usable reset button**, so there's nothing to double-tap and that option does nothing useful here. You don't need it: `flashtool.py` reboots the running firmware into the bootloader **over USB**, no button at all.
>
> **Gotcha #2 — "I still need DFU" is usually a missing `pyserial`.** When `flashtool.py` is run with the **system** Python (which has no `pyserial`), it errors out — and people wrongly conclude Katapult is useless and reach back for the DFU jumper. Run it with **Klipper's own Python** (`~/klippy-env/bin/python`, which already ships `pyserial`) and it just works. *(This is exactly what Mellow's own docs do for non-Fly hosts; the tool itself also tells you to `apt install python3-serial`.)*

---

## What you actually get

```
 STM32F072CB flash (128 KiB)
 ┌───────────────────────────────────────────────────────────┐
 │ 0x08000000  Katapult bootloader  (first 8 KiB)             │
 │ 0x08002000  Klipper application  (the rest)               │
 └───────────────────────────────────────────────────────────┘
        ▲                         ▲
   installed once            re-flashed forever, over USB, no jumper
   (one DFU)                 (flashtool.py  -r  →  -f)
```

Katapult sits in the first 8 KiB and is *never* overwritten. Klipper lives just above it at `0x08002000`. To re-flash Klipper you ask the running firmware to reboot into the bootloader over USB, then upload the new binary — no physical access to the board needed. Perfect for a buffer that's buried in your setup.

### The exact values for *this* board

Read live from a working LLL Plus (`~/klipper/.config`, `~/katapult/.config`) — not guesses:

| Setting | Value (Mellow LLL Plus) |
|---|---|
| MCU | `STM32F072CB` |
| Clock reference | **8 MHz crystal** (HSE on PF0/PF1) |
| Comms interface | **USB** (PA11 / PA12) |
| Katapult base address | `0x08000000` |
| Klipper application start | `0x08002000` (**8 KiB** offset) |
| Klipper USB ID (running) | `1d50:614e` → `/dev/serial/by-id/usb-Klipper_stm32f072xb_<UID>-if00` |
| Katapult USB ID (in bootloader) | `1d50:6177` → `/dev/serial/by-id/usb-katapult_stm32f072xb_<UID>-if00` |
| STM32 ROM-DFU USB ID (first install only) | `0483:df11` |

---

## ⚠️ Disclaimer — use at your own risk

Flashing firmware and replacing a bootloader is inherently risky. A wrong step, address, or build option for *your* board can erase its firmware or leave it temporarily or permanently unusable.

Everything in this repository — the guide, the commands, and the script — is provided **"as is", without any warranty of any kind**. By using it you accept **full responsibility for the result**. The author(s), contributor(s), and maintainer(s) **accept no liability whatsoever** for any hardware damage, data loss, downtime, or other problem arising from the use or misuse of anything provided here.

Before you flash anything: **back up your existing firmware** (the guide shows how), check every value against **your own** hardware, and proceed only if you understand each step. If in doubt, stop.

This is an independent, community-made guide. It is **not affiliated with, authorised by, or endorsed by** Mellow, Arksine (Katapult), or the Klipper project. All trademarks belong to their respective owners. See the [MIT License](LICENSE) for the formal warranty and liability disclaimer.

---

## Prerequisites

- A Klipper host (Raspberry Pi, etc.) with the `~/klipper` tree and the `~/klippy-env` virtualenv (a standard Klipper install).
- `dfu-util` **for the one-time install only**: `sudo apt install dfu-util`.
- Physical access to the board's **BOOT0** pads/button **once** (to install Katapult). After that, never again.

---

## Part 1 — Install Katapult (one time)

> You only do this **once per board.** It's the only step that needs the BOOT0 jumper.

### 1.1 Build Katapult

```bash
cd ~ && git clone https://github.com/Arksine/katapult
cd katapult
make menuconfig
```

Set it up for the LLL Plus:

```
Micro-controller Architecture ............ STMicroelectronics STM32
Processor model .......................... STM32F072
[*] Enable extra low-level configuration options      # reveals "Clock Reference"
Clock Reference .......................... 8 MHz crystal
Application start offset ................. 8KiB offset          # -> app lands at 0x08002000
Communication interface .................. USB (on PA11/PA12)
[ ] Support bootloader entry on rapid double click of reset    # LEAVE OFF (see below)
```

> ⚠️ **Leave "double click of reset" OFF on the LLL Plus.** The board has no usable reset button, so double-reset detection can never trigger and adds nothing here — the tested configuration leaves it off. You'll enter the bootloader over USB instead (Part 3), which needs no button.

```bash
make clean && make
# -> out/katapult.bin
```

### 1.2 Back up the current firmware, then flash Katapult via DFU

Put the board in the STM32 ROM bootloader: **hold BOOT0** (jumper/button) and re-plug the USB cable (this board has no reset button). Confirm it:

```bash
lsusb | grep 0483:df11        # "STMicroelectronics STM Device in DFU Mode"
```

**Back up what's already on the chip first** (so you can roll back):

```bash
sudo dfu-util -a 0 -d 0483:df11 -U ~/lll_factory_backup.bin -s 0x08000000:0x20000:force
```

Now write Katapult to the flash base, with a full erase so the chip boots cleanly into the bootloader:

```bash
sudo dfu-util -a 0 -d 0483:df11 -D ~/katapult/out/katapult.bin -s 0x08000000:force:mass-erase:leave
```

Re-plug USB and confirm Katapult enumerates:

```bash
ls /dev/serial/by-id/ | grep usb-katapult_stm32f072xb
# -> usb-katapult_stm32f072xb_<UID>-if00
```

That was the last time you'll touch the jumper.

---

## Part 2 — Build Klipper to run under Katapult

Klipper must start at `0x08002000` so Katapult can hand off to it.

```bash
cd ~/klipper
make menuconfig
```

```
Micro-controller Architecture ............ STMicroelectronics STM32
Processor model .......................... STM32F072
Bootloader offset ........................ 8KiB bootloader        # MUST match Katapult's app offset
Clock Reference .......................... 8 MHz crystal          # enable low-level options if hidden
Communication interface .................. USB (on PA11/PA12)
```

```bash
make clean && make
# -> out/klipper.bin
```

> **No "bootloader request" checkbox to find.** Klipper auto-enables it for every STM32 build (it's a hidden symbol), which is exactly what lets `flashtool.py -r` reboot the board into Katapult over USB. Nothing to toggle.

---

## Part 3 — Flash with **no DFU**, every time from now on

This is the part you repeat forever. No jumper, no button, just USB.

Stop Klipper so it releases the serial port:

```bash
sudo systemctl stop klipper
```

Find the board's current (Klipper) serial path:

```bash
ls /dev/serial/by-id/ | grep usb-Klipper_stm32f072xb
# e.g. usb-Klipper_stm32f072xb_3C003A000957465331323720-if00
```

### The one command that matters

Use **Klipper's Python**, not the system one — it already has `pyserial`:

```bash
~/klippy-env/bin/python ~/katapult/scripts/flashtool.py \
    -d /dev/serial/by-id/usb-Klipper_stm32f072xb_<UID>-if00 \
    -f ~/klipper/out/klipper.bin
```

That single command does the whole dance: it detects the running Klipper, **requests the bootloader over USB**, waits a few seconds for the board to re-enumerate as Katapult (`1d50:6177`), and uploads `klipper.bin` — **no reset button involved**. Then:

```bash
sudo systemctl start klipper
```

Done. The board is running your new firmware and never left its socket.

<details>
<summary>Prefer the explicit two-step version?</summary>

```bash
# 1) ask the running Klipper to reboot into Katapult, then exit
~/klippy-env/bin/python ~/katapult/scripts/flashtool.py \
    -d /dev/serial/by-id/usb-Klipper_stm32f072xb_<UID>-if00 -r

# 2) the serial path changes to usb-katapult_... — grab it and flash
ls /dev/serial/by-id/ | grep usb-katapult_stm32f072xb
~/klippy-env/bin/python ~/katapult/scripts/flashtool.py \
    -d /dev/serial/by-id/usb-katapult_stm32f072xb_<UID>-if00 \
    -f ~/klipper/out/klipper.bin
```
The `/dev/serial/by-id/` name **changes** between the steps: `usb-Klipper_…` while Klipper runs, `usb-katapult_…` once it's in the bootloader. The one-shot form above hides this for you.
</details>

There's a convenience wrapper in this repo: [`flash-lll.sh`](flash-lll.sh) — `./flash-lll.sh /dev/serial/by-id/usb-Klipper_stm32f072xb_<UID>-if00`.

---

## Why `klippy-env`?

If you run `flashtool.py` with the **system** Python you typically get:

```
FlashError: The pyserial python package was not found.  To install run the following
command in a terminal:

   sudo apt install python3-serial
```

USB/serial flashing needs `pyserial`; a stock Klipper host's *system* Python doesn't have it. Two fixes:

1. **Recommended — use Klipper's own Python.** `~/klippy-env` was created by Klipper's installer and already contains `pyserial`. Just call `~/klippy-env/bin/python …` as shown above — nothing to install. *(Mellow's own USB-flashing docs use this exact `~/klippy-env/bin/python` form for non-Fly hosts.)*
2. Or install it system-wide: `sudo apt install python3-serial`.

This is the wall that makes people wrongly conclude "Katapult still needs DFU." It doesn't — it needs `pyserial`.

---

## Verify it worked

```bash
ls /dev/serial/by-id/ | grep usb-Klipper_stm32f072xb   # back as Klipper (1d50:614e)
```
In Klipper, `FIRMWARE_RESTART`, then check `klippy.log` — you'll see your build, e.g.
`Loaded MCU 'LLL_PLUS' … (v0.13.0-… )`.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `FlashError: The pyserial python package was not found` | system Python has no `pyserial` | run flashtool with `~/klippy-env/bin/python` (or `sudo apt install python3-serial`) |
| "Just double-tap reset" does nothing | LLL Plus has **no usable reset button**; double-reset is the wrong path here | don't use double-reset — flash with `flashtool.py -r` over USB (Part 3) |
| `flashtool.py -r` does nothing / "timed out" | Klipper not built with the 8 KiB offset, **or** the host still owns the port | confirm the Klipper build is the 8 KiB-offset one; `sudo systemctl stop klipper` first |
| "Device is not Katapult, exiting…" | board re-enumerated as something else | re-run the flash against the `usb-katapult_…` path once it appears |
| Board dead after first install | Klipper flashed to the wrong base | rebuild Klipper with **8KiB bootloader** offset and re-flash |
| Last-resort recovery | bootloader unreachable over USB | re-enter ROM DFU (hold BOOT0) and restore `~/lll_factory_backup.bin` to `0x08000000`, or re-flash Katapult |

> Over native USB the `-b/--baud` flag is ignored (that's for UART). `-q/-u/-i` are CAN-only — not used here.

---

## Credits & prior work

This guide was researched, written, and tested with **Claude** (Anthropic's Claude Code). **None of the techniques here are original to this guide** — the over-USB (no-DFU) Katapult flash and the `pyserial`/`klippy-env` tip are already documented in Katapult's own README, Mellow's docs, the community notes below, and in the companion firmware repo. This guide's only contribution is **consolidating them into one tested, LLL-Plus-specific walkthrough** that skips the double-reset path (which doesn't work on this board) and explains the `pyserial` gotcha plainly.

- **Katapult** & `flashtool.py` — [Arksine/katapult](https://github.com/Arksine/katapult)
- **Klipper** — [Klipper3d](https://www.klipper3d.org/)
- **Mellow's official docs** — the `~/klippy-env/bin/python` flash form for non-Fly hosts
- Earlier LLL Plus + Katapult notes — [river29/Mellow-LLLBufferPLUS-klipper](https://github.com/river29/Mellow-LLLBufferPLUS-klipper), [ss1gohan13/BufferPLUS-klipper](https://github.com/ss1gohan13/BufferPLUS-klipper)
- Companion firmware for this board — which **also documents the over-USB Katapult flash** — [Nitrooxyde/Mellow-LLL-Plus-Klipper-Firmware](https://github.com/Nitrooxyde/Mellow-LLL-Plus-Klipper-Firmware)

Maintained and hardware-tested by **Nitrooxyde**.

## License

MIT — see [LICENSE](LICENSE). Do whatever you like; attribution appreciated.

## References

- Katapult — <https://github.com/Arksine/katapult>
- Klipper bootloaders — <https://www.klipper3d.org/Bootloaders.html>
- Mellow LLL Plus custom Klipper firmware — <https://github.com/Nitrooxyde/Mellow-LLL-Plus-Klipper-Firmware>
