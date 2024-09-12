#!/bin/bash

echo "Running on: `uname -a`"

# Ensure there is a newline...
echo "" >> /etc/dnf/dnf.conf
echo "install_weak_deps=False" >> /etc/dnf/dnf.conf

echo "Updating and configuring image for use as office kiosk"
# TODO Enable update when development iterations are done
#dnf update -y
dnf config-manager --set-enabled crb -y

# Need epel for chromium
dnf install -y \
    https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm \
    https://dl.fedoraproject.org/pub/epel/epel-next-release-latest-9.noarch.rpm

dnf install @base-x chromium -y

# Remove "unneeded" packages
dnf autoremove -y

# Remove all package caches to prevent "unnecessarily" big squashfs
dnf clean all

# Empty fstab, rootfs already mounted in RAM when booted
echo "" > /etc/fstab

# Disable selinux, as it causes problems when built on a different system
sed -i 's/^SELINUX=[a-z]*/SELINUX=disabled/' /etc/selinux/config

# Generate the needed initramfs to boot over http in RAM for the current ARCH
# (uname -r does not "work" correctly for linux version when using qemu-static-user)
ARCH=$(ls /boot/initramfs*.img | sed 's;/boot/initramfs-\([0-9a-zA-Z\.-]\+\)\.img;\1;' | sort | tail -n 1)
[[ -z "$ARCH" ]] && { ARCH="6.1.23-v8.1.el9.altarch"; echo "ARCH was empty, defaulted"; }

echo "Making initramfs for arch: $ARCH"
cat >/etc/dracut.conf.d/filesystems.conf <<EOF
# Load squashfs and overlayfs for writable root in RAM
filesystems+=" squashfs overlay "

# We don't want to check the filesystems in RAM
nofscks="yes"
EOF

cat >/etc/dracut.conf.d/custom.conf <<EOF
add_dracutmodules+=" debug rootfs-over-http "
EOF

# TODO Disable splash screen when finished
cp /boot/config-kernel.inc /boot/config.txt
cat >>/boot/config.txt <<EOF
disable_splash=0

# Built at $(date +%Y-%m-%dT%H:%M:%S%Z) by $(whoami) at $(hostname)
EOF

cd /boot
dracut -v \
	--force \
	--kver "$ARCH" \
	"initramfs-$ARCH.img" \
	"$ARCH"
cd /
