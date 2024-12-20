#!/bin/bash

set -exuo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

echo "Running on: `uname -a`"

cat >>/etc/dnf/dnf.conf <<EOF
install_weak_deps=False
EOF

echo "Updating and configuring image for use as office monitor"
dnf update -y

# Need epel for chromium, and crb for epel
dnf config-manager -y --set-enabled crb
dnf install -y epel-release

# Run in two commands to prevent "too full filesystem"
dnf install -y @base-x
dnf install -y chromium

# Remove "unneeded" packages
dnf autoremove -y

# Remove all package caches to prevent "unnecessarily" big squashfs
dnf clean all --verbose
dnf clean dbcache --verbose
dnf clean metadata --verbose
dnf clean packages --verbose

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

cp /boot/config-kernel.inc /boot/config.txt
cat >>/boot/config.txt <<EOF
disable_splash=1
disable_poe_fan=1
boot_delay=0
force_eeprom_read=0
ignore_lcd=1
camera_auto_detect=0
dtoverlay=disable-wifi

# Built at $(date +%Y-%m-%dT%H:%M:%S%Z) by $(whoami) at $(hostname)
EOF

cd /boot
dracut -v \
	--force \
	--kver "$ARCH" \
	"initramfs-$ARCH.img" \
	"$ARCH"
cd /
