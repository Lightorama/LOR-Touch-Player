# Building and Installing designware_i2s.ko (lor-i2s-dkms)

## Purpose

`designware_i2s.ko` is the ALSA SoC driver for the Synopsys DesignWare I2S controller
used on the RP1 companion chip of the Raspberry Pi Compute Module 5. It drives the I2S
bus that the HiFiBerry DAC (PCM5102A) is connected to.

The upstream driver has a bug that prevents any ALSA client (including `mpv`) from
opening the HiFiBerry PCM device: `Playback open error: Invalid argument`.

**Root cause.** When the kernel opens an ALSA PCM substream, it computes a mask of
allowed access modes from `runtime->hw.info`. For the RP1 I2S path, no component in the
ASoC call chain ever calls `snd_soc_set_runtime_hwparams`, so `runtime->hw.info` stays
zero-initialised. The RP1's DMA controller uses non-coherent memory, so
`hw_support_mmap()` returns false. The kernel then builds the access mask solely from
`hw.info` bits 8–9 (INTERLEAVED / NONINTERLEAVED); with both bits clear the mask is 0,
and `snd_pcm_hw_constraint_mask(runtime, ACCESS, 0)` returns `-EINVAL`.

## Modified file (relative to kernel source root)

- `sound/soc/dwc/dwc-i2s.c` — `dw_i2s_startup()`: adds
  `substream->runtime->hw.info |= SNDRV_PCM_INFO_INTERLEAVED;`
  before `return 0`. This runs before `soc_pcm_init_runtime_hw()`, which only updates
  rates/formats/channels and never clears `hw.info`, so the flag persists into the
  constraint check.

## Why DKMS

Earlier the patched module was built by hand and placed over the stock file with
`dpkg-divert`. That only covers one kernel version: every `linux-image` upgrade installs
a new, unpatched module under a new `/lib/modules/<version>/` path, and audio silently
breaks again. The fix is now packaged as `lor-i2s-dkms`, and DKMS rebuilds the module
automatically for every new kernel.

## Package layout

The package source is in this repository at `home/lor/src/lor-i2s-dkms/`:

| Path | Purpose |
|---|---|
| `pkg/usr/src/lor-i2s-1.0.0/dwc-i2s.c` | **Patched** driver (the one-line change above) |
| `pkg/usr/src/lor-i2s-1.0.0/dwc-pcm.c`, `local.h` | Unmodified upstream companion files, needed because the module is built out of tree and `CONFIG_SND_DESIGNWARE_PCM=y` on this platform |
| `pkg/usr/src/lor-i2s-1.0.0/Makefile`, `dkms.conf` | Out-of-tree build of `designware_i2s.ko` (`dwc-i2s.o` + `dwc-pcm.o`), installed to `/lib/modules/<version>/updates/dkms/` |
| `pkg/usr/share/dkms/modules_to_force_install/lor-i2s` | `lor-i2s_version-override`. The stock and patched modules have no `MODULE_VERSION`, so DKMS's version check sees them as equal and would otherwise skip the install. |
| `pkg/DEBIAN/control`, `postinst`, `prerm` | Debian packaging: depends on `dkms` and `linux-headers-rpi-2712` |
| `build.sh` | Builds `lor-i2s-dkms_<version>_all.deb` |

The module in `updates/dkms/` takes precedence over the stock one in `kernel/`, so the
stock kernel files are not modified.

## Build and install

```bash
cd home/lor/src/lor-i2s-dkms
./build.sh
sudo apt install ./lor-i2s-dkms_1.0.0_all.deb
```

`apt` pulls in `dkms`, the matching kernel headers, and the compiler if they're missing.
On install, DKMS builds and installs the module for the running kernel. The postinst then:

- removes any older hand-installed `dpkg-divert` of
  `kernel/sound/soc/dwc/designware_i2s.ko.xz` and restores the stock file;
- reloads the driver if the sound card is idle, otherwise the patched module is loaded at
  the next reboot.

Check the result:

```bash
dkms status                        # lor-i2s/1.0.0, <kernel>, aarch64: installed
modinfo -n designware_i2s          # .../updates/dkms/designware_i2s.ko.xz
aplay -D plughw:CARD=sndrpihifiberry,DEV=0 /usr/share/sounds/alsa/Front_Center.wav
```

## Kernel upgrades

Nothing to do. Installing a new kernel or its headers triggers
`/etc/kernel/postinst.d/dkms` / `/etc/kernel/header_postinst.d/dkms`, which rebuilds the
module. If a future kernel changes the driver's internal API, the build fails (see
`/var/lib/dkms/lor-i2s/1.0.0/<kernel>/aarch64/log/make.log`), the stock driver is used, and
the bug returns. In that case refresh the three source files from the matching
`raspberrypi/linux` branch, re-apply the one-line change, and bump the package version.

Removing the package (`sudo apt remove lor-i2s-dkms`) removes the DKMS module and
restores the stock (unpatched) driver.

## Upstream source

`sound/soc/dwc/dwc-i2s.c`, `dwc-pcm.c` and `local.h` are from the Raspberry Pi Linux kernel
tree, branch `rpi-6.12.y`, licensed GPL-2.0-or-later. The SPDX headers are unchanged from
upstream.
