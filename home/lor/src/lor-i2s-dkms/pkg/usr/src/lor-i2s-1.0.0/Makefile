# Out-of-tree build of the RP1 DesignWare I2S driver (designware_i2s.ko) with
# the HiFiBerry hw.info fix in dwc-i2s.c. dkms runs this via dkms.conf MAKE[0].
obj-m := designware_i2s.o
designware_i2s-y := dwc-i2s.o dwc-pcm.o

KVER ?= $(shell uname -r)
KDIR ?= /lib/modules/$(KVER)/build

all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
