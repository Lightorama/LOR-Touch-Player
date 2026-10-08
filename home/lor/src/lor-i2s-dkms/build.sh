#!/bin/sh
# Build lor-i2s-dkms_<version>_all.deb from ./pkg (version from pkg/DEBIAN/control).
set -e
cd "$(dirname "$0")"
v=$(sed -n 's/^Version: //p' pkg/DEBIAN/control)
chmod 755 pkg/DEBIAN/postinst pkg/DEBIAN/prerm
chmod 644 pkg/DEBIAN/control pkg/usr/src/lor-i2s-*/* pkg/usr/share/dkms/modules_to_force_install/*
dpkg-deb --root-owner-group --build pkg "lor-i2s-dkms_${v}_all.deb"
