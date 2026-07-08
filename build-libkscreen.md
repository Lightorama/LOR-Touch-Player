# Building and Installing the Patched kscreen.so kded Plugin

## Purpose

`kscreen.so` (installed at `/usr/lib/aarch64-linux-gnu/qt5/plugins/kf5/kded/kscreen.so`)
is KDE's `kded5` module that generates the initial display configuration whenever a new
set of outputs is seen for the first time (no saved config for that output combination
yet).

On this device, the built-in DSI-1 panel must always be the primary/default display,
regardless of what else is connected. The stock plugin doesn't guarantee that.

**Root cause.** `Generator::idealConfig()` (`kded/generator.cpp`) picks the primary
output by device class: `isLaptop()` puts the laptop's built-in panel first, but a
Raspberry Pi Compute Module is not detected as a laptop, so the code falls through to
`extendToRight()`, which places outputs by resolution — the highest-resolution output
becomes primary. On this device, an external 1920x1080 HDMI monitor beats the
720x1280 DSI-1 panel, so this path can select HDMI-A-1 as primary/default, which is
wrong for this hardware regardless of what happens to be plugged into HDMI at boot.

`kscreen-fix-priority.sh` (see the main README) already corrects this after the fact
once `~/.local/share/kscreen/` has a saved config for the current output set, but on a
first boot with an empty kscreen config directory there is a window before that
correction takes effect. This patch fixes the default at the source instead.

## Modified file (relative to the kscreen source root)

- `kded/generator.cpp` — `Generator::idealConfig()`: after the existing `isLaptop()`
  check, adds a check for `embeddedOutput(connectedOutputs)` (returns non-null when any
  connected output is of type `Panel`, which DSI-1 always is on this hardware). If
  found, calls `laptop(config)` — the same code path used for laptop panels — instead
  of falling through to `extendToRight()`. `laptop()` places the panel at `(0,0)` as
  primary and extends any external display to the right, independent of resolution.

The modified copy is in this repository at `home/lor/src/kscreen/kded/generator.cpp`.

## Prerequisites

```bash
sudo apt build-dep kscreen
```

This pulls in `extra-cmake-modules`, the KF5 `*-dev` packages, and the other
Build-Depends declared by the Debian `kscreen` source package (`4:5.27.5-2`, bookworm).

## Build

```bash
mkdir -p ~/src/kscreen && cd ~/src/kscreen

# Fetch the unmodified upstream source matching the installed package version
apt source kscreen   # or: apt-get source kscreen

cd kscreen-5.27.5

# Apply the patch: replace kded/generator.cpp with this repository's copy
cp ~/Documents/github/home/lor/src/kscreen/kded/generator.cpp kded/generator.cpp

mkdir -p ../build && cd ../build
cmake ../kscreen-5.27.5 -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
make -j$(nproc) kscreen
```

`make ... kscreen` builds only the `kded/kscreen.so` plugin target
(`kcoreaddons_add_plugin(kscreen ...)` in `kded/CMakeLists.txt`), not the full kscreen
package (KCM, console tool, plasmoid, etc.), which are unmodified and don't need
rebuilding.

## Install

On first install, protect the plugin from being overwritten by `apt upgrade` using
`dpkg-divert` (same pattern as `designware_i2s.ko` and `libmobileshellplugin.so`):

```bash
PLUGIN=/usr/lib/aarch64-linux-gnu/qt5/plugins/kf5/kded/kscreen.so

sudo dpkg-divert --add --local --rename --divert "${PLUGIN}.distrib" "$PLUGIN"
```

Then install the patched plugin:

```bash
sudo cp ~/src/kscreen/build/bin/kf5/kded/kscreen.so "$PLUGIN"
```

(Check `~/src/kscreen/build/bin/` for the exact output path if the CMake layout
differs — the plugin is wherever `kded/CMakeLists.txt`'s `INSTALL_NAMESPACE
"kf5/kded"` resolves it under the build tree.)

Reload without rebooting:

```bash
qdbus org.kde.kded5 /kded unloadModule kscreen
qdbus org.kde.kded5 /kded loadModule kscreen
```

Or simply reboot. This only affects the *default* config generated for a previously
unseen output combination — an existing saved config for the current outputs (in
`~/.local/share/kscreen/`) is used as-is and this plugin isn't consulted.

## After a kscreen package upgrade

1. Re-fetch the new source version and re-apply the patch:
   ```bash
   cd ~/src/kscreen && rm -rf kscreen-<old-version>
   apt source kscreen
   cd kscreen-<new-version>
   cp ~/Documents/github/home/lor/src/kscreen/kded/generator.cpp kded/generator.cpp
   ```
2. Rebuild and reinstall as above. `dpkg-divert` will already be in place from the
   first install — no need to re-add it.

## Upstream source

`kded/generator.cpp` is from the KDE kscreen project
([invent.kde.org/plasma/kscreen](https://invent.kde.org/plasma/kscreen)), as packaged
by Debian in source package `kscreen` version `4:5.27.5-2` (bookworm), licensed
GPL-2.0-or-later per the file's own SPDX header (unchanged from upstream).
