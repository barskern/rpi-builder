#!/bin/bash
set -euxo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
IFS=$'\n\t'

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

base_image="$1"
mount="$2"
dest="$3"

[ -z "$base_image" ] && { echo "Error: missing base image as first argument"; exit 1; }
[ -z "$mount" ] && { echo "Error: missing mount location as second argument"; exit 1; }
[ -z "$dest" ] && { echo "Error: missing image destination as second argument"; exit 1; }

size="${RPI_SIZE:-3.7G}"
image="${RPI_IMAGE_NAME:-rpi-full.img}"

mkdir -p $dest

src_lodev=$(losetup --partscan --find --show --read-only $base_image)
partprobe $src_lodev
src_bootdev=$(ls "${src_lodev}"*1)
# swap is second partition, which we dont need (or want)
src_rootdev=$(ls "${src_lodev}"*3)

[[ -z "$src_bootdev" ]] && { echo "did not find boot partition of base image"; exit 1; }
[[ -z "$src_rootdev" ]] && { echo "did not find root partition of base image"; exit 1; }

fallocate -l "$size" "$dest/$image"
dest_lodev=$(losetup --find --show "$dest/$image")
parted --script "${dest_lodev}" mklabel msdos
parted --script "${dest_lodev}" mkpart primary fat32 0% 350M
parted --script "${dest_lodev}" mkpart primary ext4 350M 100%
dest_bootdev=$(ls "${dest_lodev}"*1)
dest_rootdev=$(ls "${dest_lodev}"*2)
mkfs.vfat -F32 ${dest_bootdev}
mkfs.ext4 -F ${dest_rootdev}

dd if=$src_rootdev of=$dest_rootdev status=progress
dd if=$src_bootdev of=$dest_bootdev status=progress

# After dd, the filesystem is limited to the size of the original disk, however
# the partition is bigger (namely RPI_SIZE - 350M). Resize the filesystem to fit
# the partition.
resize2fs $dest_rootdev

# Mount the image
[ ! -d "${mount}" ] && mkdir -m 0755 "${mount}"
mount "${dest_rootdev}" "${mount}"
[ ! -d "${mount}/boot" ] && mkdir -m 0755 "${mount}/boot"
mount "${dest_bootdev}" "${mount}/boot"

# Prep for chroot
mount -t proc none "${mount}/proc"
mount -t sysfs none "${mount}/sys"
mount -o bind /dev "${mount}/dev"
cp /etc/resolv.conf "${mount}/etc/resolv.conf"
cp /usr/bin/qemu-aarch64-static "${mount}/usr/bin/"
