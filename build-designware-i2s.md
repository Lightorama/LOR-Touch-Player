# Building and Installing designware_i2s.ko

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

The modified copy is in this repository at
`home/lor/src/rpi-kernel-patches/dwc-build/dwc-i2s.c`.

The two companion files (`dwc-pcm.c` and `local.h`) are unmodified upstream sources
fetched at build time; they are not tracked here.

## Prerequisites

```bash
sudo apt install linux-headers-$(uname -r) xz-utils
```

The `linux-kbuild-*` package that provides the module build scripts is installed
automatically as a dependency of the headers package.

## Build

```bash
cd ~/src/rpi-kernel-patches/dwc-build

# Fetch unmodified companion files from the RPi kernel tree
curl -L -o dwc-pcm.c \
  https://raw.githubusercontent.com/raspberrypi/linux/rpi-6.12.y/sound/soc/dwc/dwc-pcm.c
curl -L -o local.h \
  https://raw.githubusercontent.com/raspberrypi/linux/rpi-6.12.y/sound/soc/dwc/local.h

# dwc-i2s.c is our patched copy (already present)
make
```

The `Makefile` in that directory builds against `/lib/modules/$(uname -r)/build` and
includes both `dwc-i2s.o` and `dwc-pcm.o` (required because `CONFIG_SND_DESIGNWARE_PCM=y`
on this platform).

## Install

On first install, protect the module from being overwritten by `apt upgrade` using
`dpkg-divert`:

```bash
MODPATH=/lib/modules/$(uname -r)/kernel/sound/soc/dwc/designware_i2s.ko.xz

sudo dpkg-divert --add --local --rename --divert "${MODPATH}.distrib" "$MODPATH"
```

Then install the patched module:

```bash
xz -k -f ~/src/rpi-kernel-patches/dwc-build/designware_i2s.ko
sudo cp ~/src/rpi-kernel-patches/dwc-build/designware_i2s.ko.xz "$MODPATH"
sudo depmod -a
```

Reload the module stack without rebooting:

```bash
sudo rmmod snd_soc_rpi_simple_soundcard snd_soc_pcm5102a designware_i2s
sudo modprobe designware_i2s
sudo modprobe snd_soc_pcm5102a
sudo modprobe snd_soc_rpi_simple_soundcard
```

Or simply reboot.

## After a linux-image package upgrade

The kernel module path changes with each kernel version. On upgrade:

1. Rebuild against the new headers:
   ```bash
   cd ~/src/rpi-kernel-patches/dwc-build
   make clean
   make
   ```

2. Set up `dpkg-divert` for the new kernel version's path:
   ```bash
   MODPATH=/lib/modules/$(uname -r)/kernel/sound/soc/dwc/designware_i2s.ko.xz
   sudo dpkg-divert --add --local --rename --divert "${MODPATH}.distrib" "$MODPATH"
   ```

3. Install and reload as above.

## Upstream source

`sound/soc/dwc/dwc-i2s.c` is from the Raspberry Pi Linux kernel tree, branch
`rpi-6.12.y`, licensed GPL-2.0-or-later. The SPDX header in the modified file is
unchanged from upstream.
