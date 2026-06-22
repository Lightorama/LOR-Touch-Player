# Building and Installing libmobileshellplugin.so

## Purpose

`libmobileshellplugin.so` is the Qt/QML plugin that provides the Plasma Mobile shell UI,
including the status bar clock. This rebuild is required to fix DSI-1 screen flicker:
the upstream clock updates once per minute, leaving the compositor idle long enough to
cause a visible artifact on the first new frame. Rebuilding with a 1-second clock interval
keeps the compositor active and eliminates the flicker.

## Modified files (relative to plasma-mobile source root)

- `components/mobileshell/qml/statusbar/ClockText.qml` — clock format `"h:mm"` → `"h:mm:ss"` (DSI-1 flicker fix); 24h branch format `"h:mm:ss"` → `"H:mm:ss"` (Qt uppercase H = 24-hour)
- `components/mobileshell/qml/statusbar/StatusBar.qml` — DataSource `interval: 60 * 1000` + `intervalAlignment: AlignToMinute` → `interval: 1000` (DSI-1 flicker fix)
- `components/mobileshell/shellutil.cpp` — `isSystem24HourFormat()` changed from exact equality with `"HH:mm:ss"` to `contains('H')`, so any valid 24-hour `TimeFormat` value in kdeglobals is recognised
- `components/mobileshell/qml/actiondrawer/LandscapeContentContainer.qml` — action drawer clock 24h branch `"h:mm"` → `"H:mm"` (Qt uppercase H = 24-hour)

The modified copies of these files are in this repository under `home/lor/src/plasma-mobile/`.

## Prerequisites

```
sudo apt install cmake extra-cmake-modules \
    libkf5plasma-dev libkf5plasmaquick-dev \
    libkf5wayland-dev libkf5windowsystem-dev \
    qtbase5-dev qtdeclarative5-dev \
    libkf5coreaddons-dev libkf5i18n-dev
```

## First-time build

```bash
# Clone or have source already at ~/src/plasma-mobile (tag v5.27.2)
cd ~/src/plasma-mobile

# Create and configure build directory
mkdir -p ~/src/plasma-mobile-build
cd ~/src/plasma-mobile-build
cmake ~/src/plasma-mobile \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr

# Build only the mobileshell component (fast; avoids building unrelated targets)
make -j$(nproc) -C components/mobileshell
```

## Install

```bash
sudo cp ~/src/plasma-mobile-build/bin/libmobileshellplugin.so \
    /usr/lib/aarch64-linux-gnu/qt5/qml/org/kde/plasma/private/mobileshell/libmobileshellplugin.so
```

Then restart the Plasma shell to load the new plugin:

```bash
kquitapp5 plasmashell && kstart5 plasmashell
```

Or reboot.

## After a plasma-mobile package update

The `.so` is overwritten by `apt upgrade`. Rebuild and reinstall:

```bash
cd ~/src/plasma-mobile-build
make -j$(nproc) -C components/mobileshell
sudo cp bin/libmobileshellplugin.so \
    /usr/lib/aarch64-linux-gnu/qt5/qml/org/kde/plasma/private/mobileshell/libmobileshellplugin.so
```

## Backup

A `.bak` of the unmodified upstream `.so` is kept at:

```
/usr/lib/aarch64-linux-gnu/qt5/qml/org/kde/plasma/private/mobileshell/libmobileshellplugin.so.bak
```

To revert to stock: `sudo cp ...bak /usr/.../libmobileshellplugin.so`
