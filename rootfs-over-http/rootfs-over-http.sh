#!/bin/sh
#
# Mount rootfs as a read-only in RAM from a network http squashfs, add an overlayfs over it.
#

command -v getarg > /dev/null || . /lib/dracut-lib.sh
command -v fetch_url > /dev/null || . /lib/url-lib.sh

info "custom mount script (v2) started"

http_source=$(getarg osrootfs=)
[ -z "$http_source" ] && { warn "osrootfs= has to be set as a cmdline arg"; return 1; }

tmp_squash_file=/tmp/squashfs.img
squash_file=/run/initramfs/squashfs.img
squash_mount=/run/initramfs/squashfs

if [ ! -f "$squash_file" ]; then
	info "downloading squashfs to tmp directory..."

	if ! fetch_url "$http_source" "$tmp_squash_file"; then
		warn "failed to download squashfs..."
		return 1
	fi

	# We need to ensure that /run has enough space for the entire
	# squashfile/filesystem
	info "remounting /run with bigger size"
	mount -o remount,size=2G /run

	info "transferring squashfs to run to be persistent on switch-root"
	mv $tmp_squash_file $squash_file

	[ -f "$squash_file" ] || { warn "did not find squash file after download"; return 1; };
	info "successfully downloaded squashfs to RAM"
fi

if [ ! -d "$squash_mount" ]; then
	mkdir -m 0755 -p $squash_mount
	info "mounting squash filesystem to $squash_mount"
	mount -n -t squashfs -o loop,ro $squash_file $squash_mount
fi

info "squashfs mounted!"

base_dir=/run/rootfsbase
overlay_dir=/run/overlayfs
work_dir=/run/overlaywork

mkdir -m 0755 -p $base_dir
mount --rbind $squash_mount $base_dir

mkdir -m 0755 -p $overlay_dir
mkdir -m 0755 -p $work_dir

info "mounting overlay.."
mount -t overlay overlay -o lowerdir=$base_dir,upperdir=$overlay_dir,workdir=$work_dir /sysroot
info "mounted overlayfs to sysroot"

# Make directories not included in squashfs but needed in root (checked by
# dracut-mount)
mkdir -m 0555 -p /sysroot/{proc,dev,sys}

# Remake old resolve.conf which was overridded when creating squashfs
[[ -f "/sysroot/etc/resolve.conf.orig" ]] && mv /sysroot/etc/resolve.conf.orig /sysroot/etc/resolve.conf

export NEWROOT=/sysroot
info "sat up new root at $NEWROOT!"
