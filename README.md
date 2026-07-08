# LOR Touch Player — System Customization Environment

This repository contains the system configurations, user-space utilities, and modified open-source files used to build the operating system environment for the **Light-O-Rama Touch Player**.

The base platform is **Raspberry Pi OS Lite (Bookworm)** running **KDE Plasma Mobile 5**, under a dedicated user account (`lor`).

## Project Purpose

In compliance with open-source licensing requirements (GPL/LGPL), this repository is a transparent record of the changes we made to GPL/LGPL-licensed components of the stock Linux system.

Our core application interacts with these system components via standard user-space APIs and OS IPC mechanisms (named pipes). The Light-O-Rama Touch Player application itself remains entirely proprietary, is hosted on our private APT infrastructure, and is not included in this repository.

---

## 🚫 What This Repository Does Not Include

This repository covers files that are modifications of, or replacements for, GPL/LGPL-licensed components. It deliberately excludes:

* The autostart `.desktop` entry that launches the proprietary Touch Player application.
* Our power-management shell scripts.
* The `dsi1-early-scale.service` unit and script (see *KDE Session Configuration* below).

These are original works authored by Light-O-Rama. They run alongside the GPL/LGPL components covered here, but they are not modifications of them and do not link against them — so they fall outside GPL's source-disclosure requirement.

---

## 🛠️ System Overview & Dependencies

To reproduce the base environment on a target device, start with a stock installation of Raspberry Pi OS Lite (Bookworm), create a default user named `lor`, and install:

```bash
sudo apt update
sudo apt install plasma-mobile mpv ftdi-eeprom
```

One component — `libmobileshellplugin.so` — is not used as shipped by `apt`. We carry source patches against it (see below) and rebuild it ourselves, which requires the Plasma Mobile build toolchain. See [`build-libmobileshellplugin.md`](build-libmobileshellplugin.md) for the full dependency list and build/install procedure.

---

## 📂 Repository Structure

Files mirror their destination paths on the target device:

* `boot/firmware/cmdline.txt` — Kernel command line; adds the DSI-1 display mode override. The `PARTUUID` and Wi-Fi regdomain in this copy have been genericized — do not deploy this file verbatim (see below).
* `etc/apt/sources.list.d/lor.list` — Private APT repository definition for our application packages.
* `etc/systemd/system.conf` — Enables the hardware watchdog (`RuntimeWatchdogSec`).
* `home/lor/.local/bin/maliit-dsi-fix.sh` — Forces the on-screen keyboard onto the DSI-1 panel instead of the HDMI output.
* `home/lor/.local/bin/kscreen-fix-priority.sh` — Enforces DSI-1 display settings (rotation=right, scale=1.35, position=0,0, priority=1) and HDMI-A-1 position (948,0) in kscreen config files on every write (via `inotifywait`) and live via `kscreen-doctor`. The live apply includes HDMI-A-1 only when that output is currently connected, and verifies the scale took effect by reading the output state back, retrying if it didn't stick (see *Boot-time DSI-1 rotation and scale* below for why). On DRM hotplug and on every kscreen config rewrite (including the portrait↔landscape rotation triggered by the orientation sensor) it also sweeps all non-mpv windows back to DSI-1 by output name.
* `home/lor/.config/kwinrulesrc` — Window placement rules. Deliberately contains only a generic "maximize all windows" rule; do **not** add rules that pin a window to a numeric `screen=` index — KWin's screen index-to-output mapping (which of DSI-1/HDMI-A-1 is "screen 0") is not stable across kscreen reconfigurations, and hardcoded-index rules previously caused Touch Player to strand on HDMI-A-1 after a rotation. Non-mpv window placement is instead handled dynamically, by output name, in `kscreen-fix-priority.sh` and `osk-to-dsi1`; mpv places itself on HDMI-A-1 by output name via its own `mpv.conf` (`screen-name`/`fs-screen-name`), which is unaffected by this file.
* `home/lor/.local/share/kwin/scripts/keep-mpv-visible/` — KWin script preventing the video player window from being minimized.
* `home/lor/.local/share/kwin/scripts/osk-to-dsi1/` — KWin script that keeps all non-mpv windows on DSI-1 (including the on-screen keyboard and Touch Player UI).
* `home/lor/.local/share/plasma/look-and-feel/org.kde.breezedark.desktop/contents/logout/` — Modified logout screen (overrides the stock Breeze Dark theme's logout dialog).
* `home/lor/.local/share/plasma/plasmoids/org.kde.phone.homescreen.halcyon/` — Modified Halcyon homescreen plasmoid.
* `home/lor/src/plasma-mobile/components/mobileshell/` — Source patches against plasma-mobile (tag v5.27.2). Not deployed directly; built into `libmobileshellplugin.so`. See [`build-libmobileshellplugin.md`](build-libmobileshellplugin.md).
* `home/lor/src/rpi-kernel-patches/dwc-build/dwc-i2s.c` — Patched DWC I2S kernel driver. Not deployed directly; built into `designware_i2s.ko`. See [`build-designware-i2s.md`](build-designware-i2s.md).
* `home/lor/src/kscreen/kded/generator.cpp` — Patched kscreen kded plugin source. Not deployed directly; built into `kscreen.so`. See [`build-libkscreen.md`](build-libkscreen.md).

---

## 📝 Summary of Modifications

| File | Upstream License | Change |
|------|------|--------|
| `.../logout/Logout.qml` | GPL-2.0-or-later | Removes the Log Out button; background opacity 0.5 → 0.85 |
| `.../logout/LogoutButton.qml` | GPL-2.0-or-later | Unmodified; included because Logout.qml imports it and the look-and-feel package is deployed as a whole directory |
| `.../logout/timer.js` | GPL-2.0-or-later | Unmodified; included for the same reason as LogoutButton.qml |
| `.../homescreen.halcyon/contents/ui/main.qml` | GPLv2+ | Replaced with a blank `Item {}` (blanks the homescreen) |
| `.../homescreen.halcyon/metadata.json` | GPLv2+ | Unmodified upstream plasmoid metadata; included so the override package is self-contained |
| `keep-mpv-visible/contents/code/main.js` | N/A — original LOR script | Custom KWin script, self-licensed GPL (see `metadata.desktop`) |
| `keep-mpv-visible/metadata.desktop` | N/A — original LOR script | Script metadata |
| `osk-to-dsi1/contents/code/main.js` | N/A — original LOR script | Custom KWin script, self-licensed GPL (see `metadata.desktop`) |
| `osk-to-dsi1/metadata.desktop` | N/A — original LOR script | Script metadata |
| `.local/bin/maliit-dsi-fix.sh` | N/A — original LOR script | Briefly disables the HDMI-A-1 output at session start so `maliit-keyboard` picks DSI-1 as Qt's primary screen |
| `.local/bin/kscreen-fix-priority.sh` | N/A — original LOR script | Enforces DSI-1 rotation=right, scale=1.35, position=0,0, and priority=1, and HDMI-A-1 position=948,0 (only when HDMI is connected), in kscreen config files (via `inotifywait`) and live (via `kscreen-doctor`, verified by readback with retry); on DRM hotplug and on every kscreen config rewrite also sweeps all non-mpv windows back to DSI-1 (by output name) via a one-shot KWin script |
| `.config/kwinrulesrc` | N/A (config) | Generic "maximize all windows" rule only; hardcoded `screen=` index rules ("Force MPV to HDMI", "Force all windows to DSI-1") were removed because the screen index-to-output mapping isn't stable across kscreen reconfigurations and those rules stranded Touch Player on HDMI-A-1 after a rotation |
| `boot/firmware/cmdline.txt` | N/A (config) | Adds `video=DSI-1:720x1280@60` for display configuration (`PARTUUID` and regdomain genericized in this copy) |
| `etc/systemd/system.conf` | LGPL-2.1-or-later (systemd) | Sets `RuntimeWatchdogSec=10` for hardware watchdog support |
| `src/plasma-mobile/components/mobileshell/qml/statusbar/ClockText.qml` | GPL-2.0-or-later | Clock format `h:mm` → `h:mm:ss` to prevent DSI-1 flicker; 24h branch `h:mm:ss` → `H:mm:ss` so Qt formats in 24-hour |
| `src/plasma-mobile/components/mobileshell/qml/statusbar/StatusBar.qml` | LGPL-2.0-or-later | DataSource interval `60000` + `AlignToMinute` → `1000` to prevent DSI-1 flicker |
| `src/plasma-mobile/components/mobileshell/shellutil.cpp` | GPL-2.0-or-later | `isSystem24HourFormat()`: (1) exact-match `"HH:mm:ss"` → `contains('H')` so any 24-hour `TimeFormat` in kdeglobals is recognised; (2) when `TimeFormat` is absent from kdeglobals, falls back to `QLocale::system().timeFormat()` (honours `LC_TIME`) instead of a hardcoded 24h default |
| `src/plasma-mobile/components/mobileshell/qml/actiondrawer/LandscapeContentContainer.qml` | LGPL-2.0-or-later | Action drawer clock 24h branch `"h:mm"` → `"H:mm"` so Qt formats in 24-hour |
| `etc/apt/sources.list.d/lor.list` | N/A (config) | Private APT repository for application packages; contains no credentials |
| `src/rpi-kernel-patches/dwc-build/dwc-i2s.c` | GPL-2.0-or-later | `dw_i2s_startup()`: adds `SNDRV_PCM_INFO_INTERLEAVED` to `runtime->hw.info` so the PCM access constraint mask is non-zero; fixes `Playback open error: Invalid argument` on HiFiBerry DAC (PCM5102A) via RP1 I2S |
| `src/kscreen/kded/generator.cpp` | GPL-2.0-or-later | `Generator::idealConfig()`: added an `embeddedOutput(connectedOutputs)` check (true when a `Panel`-type output like DSI-1 is connected) that routes to the `laptop(config)` placement path instead of `extendToRight()`; makes the built-in DSI-1 panel the default primary display on first boot instead of whichever output has the highest resolution |

The four `plasma-mobile` source files exist to fix a DSI-1 screen flicker (the upstream clock redraws once a minute, leaving the compositor idle long enough to produce a visible artifact) and to make the 24-hour clock setting honour the system locale. See [`build-libmobileshellplugin.md`](build-libmobileshellplugin.md) for the rebuild procedure.

---

## KDE Session Configuration

One KDE daemon setting must be applied to the user session. It does not correspond to a file in this repository but is required for correct operation.

### kded kscreen module disabled

Plasma's `kded5` daemon includes a `kscreen` module that watches for display hotplug events. When an HDMI display connects that has no saved kscreen configuration, the module presents a "Switch to external screen" dialog offering layout choices. On this device that dialog is unwanted: the display geometry is fixed by design (DSI-1 always primary at position 0,0; any HDMI display always secondary at 948,0), and `kscreen-fix-priority.sh` already handles all display configuration changes automatically via udev.

The kscreen kded module is therefore disabled so it neither interferes with our udev-driven display management nor triggers the OSD prompt:

```bash
kwriteconfig5 --file kded5rc --group "Module-kscreen" --key autoload false
qdbus org.kde.kded5 /kded unloadModule kscreen   # takes effect immediately in running session
```

This writes `[Module-kscreen] autoload=false` to `~/.config/kded5rc` and persists across reboots. Everything the kscreen kded module would have done — applying saved display configs and placing new HDMI outputs — is handled by `kscreen-fix-priority.sh` instead.

### Boot-time DSI-1 rotation and scale

With the kscreen kded module disabled and no saved profiles under `~/.local/share/kscreen/`, nothing in stock Plasma applies the DSI-1 rotation or scale at session start — KWin brings the panel up unrotated at scale 1. A user systemd service, `dsi1-early-scale.service` (an original LOR script, not included in this repository for the same reason as the power-management scripts), runs after KWin starts but before `plasmashell` draws, and applies rotation=right, scale=1.35, the DSI-1 position, and — only when an HDMI display is connected — the HDMI-A-1 position. It then verifies the scale actually took effect by reading the output state back, retrying the apply a few times if needed. Applying these before the first shell paint eliminates the visible resize/tearing that occurred when the settings were applied a few seconds into the session.

Rules to follow when maintaining this setup (`dsi1-early-scale.sh` and `kscreen-fix-priority.sh` both follow all of them):

* This service is the **only** place the boot-time DSI-1 rotation/scale values live. Any change to the display layout (different scale, new panel geometry) must be made in `~/.local/bin/dsi1-early-scale.sh` — there is no kscreen profile to fall back on.
* All output settings must be batched into a **single** `kscreen-doctor` invocation (one config apply, one modeset). Multiple back-to-back `kscreen-doctor` calls have crashed (core-dumped) on this hardware.
* **Never name an output that isn't currently connected.** If any argument references a missing output (e.g. `output.HDMI-A-1.position.948,0` with no HDMI display attached), `kscreen-doctor` turns the **entire** apply into a silent no-op — it still exits 0 and echoes the requested config as if applied. This is why the scripts build the argument list dynamically from the currently listed outputs; a hardcoded list that included HDMI-A-1 used to leave the panel unscaled on every boot without a monitor attached.
* **Never trust `kscreen-doctor` exit codes.** Beyond the false 0 above, a genuinely applied change can exit 134 (`kscreen-doctor` has a heap-corruption bug and frequently SIGABRTs *after* doing its work, including on plain `-o` queries). The only reliable check is reading the output state back — parse `kscreen-doctor -o` stdout (ignoring its exit code) and confirm the expected `Scale:` value, retrying the apply if it didn't stick.

---

## 🚀 Replicating the Setup Manually

### 1. Clone this repository

```bash
git clone https://github.com/Lightorama/LOR-Touch-Player
cd LOR-Touch-Player
```

### 2. Deploy system-level files

```bash
# Kernel command line: add the DSI-1 override to your EXISTING /boot/firmware/cmdline.txt.
# Do not overwrite the file outright — your real cmdline.txt has a device-specific
# PARTUUID and regdomain that this repo's copy has had genericized.
#   add: video=DSI-1:720x1280@60

# Private APT repository definition (no credentials included)
sudo cp etc/apt/sources.list.d/lor.list /etc/apt/sources.list.d/

# Hardware watchdog
sudo cp etc/systemd/system.conf /etc/systemd/system.conf
```

### 3. Deploy user-space files (as the `lor` user)

```bash
mkdir -p ~/.local/bin ~/.local/share/kwin/scripts \
         ~/.local/share/plasma/look-and-feel ~/.local/share/plasma/plasmoids

cp home/lor/.local/bin/maliit-dsi-fix.sh ~/.local/bin/
chmod +x ~/.local/bin/maliit-dsi-fix.sh

cp home/lor/.local/bin/kscreen-fix-priority.sh ~/.local/bin/
chmod +x ~/.local/bin/kscreen-fix-priority.sh
# Both scripts need to run once per session at login. The autostart entries that
# trigger them are part of our application packaging and aren't included here.

cp -r home/lor/.local/share/kwin/scripts/keep-mpv-visible ~/.local/share/kwin/scripts/
cp -r home/lor/.local/share/kwin/scripts/osk-to-dsi1 ~/.local/share/kwin/scripts/
# Enable both scripts via System Settings > Window Management > KWin Scripts.

cp -r home/lor/.local/share/plasma/look-and-feel/org.kde.breezedark.desktop \
      ~/.local/share/plasma/look-and-feel/

cp -r home/lor/.local/share/plasma/plasmoids/org.kde.phone.homescreen.halcyon \
      ~/.local/share/plasma/plasmoids/

cp home/lor/.config/kwinrulesrc ~/.config/kwinrulesrc
# Do not add rules with a numeric `screen=` index to this file — see the
# repository structure notes above for why.
```

### 4. Disable the kded kscreen module

```bash
kwriteconfig5 --file kded5rc --group "Module-kscreen" --key autoload false
```

If KDE is already running, also unload it from the live session:

```bash
qdbus org.kde.kded5 /kded unloadModule kscreen
```

### 5. Rebuild the patched Plasma Mobile shell plugin

The files under `home/lor/src/plasma-mobile/` are source patches, not deployable files as-is. Build and install `libmobileshellplugin.so` per [`build-libmobileshellplugin.md`](build-libmobileshellplugin.md).

### 6. Rebuild the patched DWC I2S kernel module

The file under `home/lor/src/rpi-kernel-patches/dwc-build/` is a source patch, not a deployable file as-is. Build and install `designware_i2s.ko` per [`build-designware-i2s.md`](build-designware-i2s.md).

### 7. Rebuild the patched kscreen kded plugin

The file under `home/lor/src/kscreen/kded/` is a source patch, not a deployable file as-is. Build and install `kscreen.so` per [`build-libkscreen.md`](build-libkscreen.md).

---

## Execution Infrastructure & Communication Pipeline

The system uses a named pipe for IPC to control media playback. Unlike a persistent background service, the application manages the lifecycle of the media player per track:

1. At the start of a song, the application creates a named pipe at `/tmp/LORMPV`.
2. It spawns `mpv` with `--input-ipc-server=/tmp/LORMPV`.
3. Commands are streamed through the pipe to control playback.
4. On song completion, the `mpv` instance terminates and the pipe is torn down.

To exercise this cycle manually for testing:

```bash
mkfifo /tmp/LORMPV
mpv --idle --input-ipc-server=/tmp/LORMPV &
echo '{ "command": ["get_property", "volume"] }' > /tmp/LORMPV
```

---

## ⚖️ Open Source Notices & Licensing

1. **Stock open-source components.** The OS, media player, toolsets, and desktop environment are used in unmodified, stock form except where noted above. Source for these upstream components:
   * **Raspberry Pi OS (Linux Kernel):** [Official Raspberry Pi Linux Kernel Repository](https://github.com/raspberrypi/linux)
   * **Raspberry Pi OS (Debian package sources):** [Debian Sources](https://sources.debian.org/), or via the device's `/etc/apt/sources.list`
   * **KDE Plasma Mobile:** [invent.kde.org/plasma/plasma-mobile](https://invent.kde.org/plasma/plasma-mobile) — our patches are based on tag `v5.27.2`
   * **KDE kscreen:** [invent.kde.org/plasma/kscreen](https://invent.kde.org/plasma/kscreen) — our patch is based on the Debian `kscreen` source package version `4:5.27.5-2` (bookworm)
   * **mpv Media Player:** [mpv-player/mpv on GitHub](https://github.com/mpv-player/mpv)
   * **FTDI EEPROM Utility (libftdi):** [Intra2net libftdi](https://www.intra2net.com/en/developer/libftdi/)

2. **Our modifications.** Files in this repository are distributed under the GPL or LGPL license of the upstream file they modify; each modified file retains its original upstream SPDX license header. The repository-level [`LICENSE`](LICENSE) file contains the GPL-2.0-or-later text, which is the predominant license here; for the smaller set of files under LGPL, the per-file SPDX header governs (see the "Summary of Modifications" table above).

3. **Proprietary application.** The commercial Light-O-Rama Touch Player application is a standalone user-space program developed independently by Light-O-Rama. It communicates with `mpv` and the OS via standard interfaces (such as `/tmp/LORMPV`) and does not link against any copyleft-covered code. It remains proprietary, is distributed via our private APT infrastructure, and is not included in this repository.
