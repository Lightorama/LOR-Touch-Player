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

Both are original works authored by Light-O-Rama. They run alongside the GPL/LGPL components covered here, but they are not modifications of them and do not link against them — so they fall outside GPL's source-disclosure requirement.

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
* `home/lor/.local/bin/kscreen-fix-priority.sh` — Enforces DSI-1 display settings (rotation=right, scale=1.35, priority=1) in kscreen config files on every write (via `inotifywait`) and live via `kscreen-doctor`; on DRM hotplug also sweeps all non-mpv windows back to DSI-1.
* `home/lor/.local/share/kwin/scripts/keep-mpv-visible/` — KWin script preventing the video player window from being minimized.
* `home/lor/.local/share/kwin/scripts/osk-to-dsi1/` — KWin script that keeps all non-mpv windows on DSI-1 (including the on-screen keyboard and Touch Player UI).
* `home/lor/.local/share/plasma/look-and-feel/org.kde.breezedark.desktop/contents/logout/` — Modified logout screen (overrides the stock Breeze Dark theme's logout dialog).
* `home/lor/.local/share/plasma/plasmoids/org.kde.phone.homescreen.halcyon/` — Modified Halcyon homescreen plasmoid.
* `home/lor/src/plasma-mobile/components/mobileshell/` — Source patches against plasma-mobile (tag v5.27.2). Not deployed directly; built into `libmobileshellplugin.so`. See [`build-libmobileshellplugin.md`](build-libmobileshellplugin.md).

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
| `.local/bin/kscreen-fix-priority.sh` | N/A — original LOR script | Enforces DSI-1 rotation=right, scale=1.35, and priority=1 in kscreen config files (via `inotifywait`) and live (via `kscreen-doctor`); on DRM hotplug also sweeps all non-mpv windows back to DSI-1 via a one-shot KWin script |
| `boot/firmware/cmdline.txt` | N/A (config) | Adds `video=DSI-1:720x1280@60` for display configuration (`PARTUUID` and regdomain genericized in this copy) |
| `etc/systemd/system.conf` | LGPL-2.1-or-later (systemd) | Sets `RuntimeWatchdogSec=10` for hardware watchdog support |
| `src/plasma-mobile/components/mobileshell/qml/statusbar/ClockText.qml` | GPL-2.0-or-later | Clock format `h:mm` → `h:mm:ss` to prevent DSI-1 flicker; 24h branch `h:mm:ss` → `H:mm:ss` so Qt formats in 24-hour |
| `src/plasma-mobile/components/mobileshell/qml/statusbar/StatusBar.qml` | LGPL-2.0-or-later | DataSource interval `60000` + `AlignToMinute` → `1000` to prevent DSI-1 flicker |
| `src/plasma-mobile/components/mobileshell/shellutil.cpp` | GPL-2.0-or-later | `isSystem24HourFormat()`: (1) exact-match `"HH:mm:ss"` → `contains('H')` so any 24-hour `TimeFormat` in kdeglobals is recognised; (2) when `TimeFormat` is absent from kdeglobals, falls back to `QLocale::system().timeFormat()` (honours `LC_TIME`) instead of a hardcoded 24h default |
| `src/plasma-mobile/components/mobileshell/qml/actiondrawer/LandscapeContentContainer.qml` | LGPL-2.0-or-later | Action drawer clock 24h branch `"h:mm"` → `"H:mm"` so Qt formats in 24-hour |
| `etc/apt/sources.list.d/lor.list` | N/A (config) | Private APT repository for application packages; contains no credentials |

The four `plasma-mobile` source files exist to fix a DSI-1 screen flicker (the upstream clock redraws once a minute, leaving the compositor idle long enough to produce a visible artifact) and to make the 24-hour clock setting honour the system locale. See [`build-libmobileshellplugin.md`](build-libmobileshellplugin.md) for the rebuild procedure.

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
```

### 4. Rebuild the patched Plasma Mobile shell plugin

The files under `home/lor/src/plasma-mobile/` are source patches, not deployable files as-is. Build and install `libmobileshellplugin.so` per [`build-libmobileshellplugin.md`](build-libmobileshellplugin.md).

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
   * **mpv Media Player:** [mpv-player/mpv on GitHub](https://github.com/mpv-player/mpv)
   * **FTDI EEPROM Utility (libftdi):** [Intra2net libftdi](https://www.intra2net.com/en/developer/libftdi/)

2. **Our modifications.** Files in this repository are distributed under the GPL or LGPL license of the upstream file they modify; each modified file retains its original upstream SPDX license header. The repository-level [`LICENSE`](LICENSE) file contains the GPL-2.0-or-later text, which is the predominant license here; for the smaller set of files under LGPL, the per-file SPDX header governs (see the "Summary of Modifications" table above).

3. **Proprietary application.** The commercial Light-O-Rama Touch Player application is a standalone user-space program developed independently by Light-O-Rama. It communicates with `mpv` and the OS via standard interfaces (such as `/tmp/LORMPV`) and does not link against any copyleft-covered code. It remains proprietary, is distributed via our private APT infrastructure, and is not included in this repository.
