#!/bin/bash
set -uo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
IFS=$'\n\t'

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

mount="$1"
script="$2"

[ -z "$mount" ] && { echo "Error: missing mount location as second argument"; exit 1; }
[ -z "$script" ] && { echo "Error: missing script to run as second argument"; exit 1; }

mount_module="rootfs-over-http"
osrootfs="${RPI_OSROOTFS}"
template="${RPI_HTML_TEMPLATE_NAME:-default}"

[ -z "$osrootfs" ] && { echo "Error: missing env RPI_OSROOTFS for HTTP location of squashed rootfs"; exit 1; }

rm -rf "${mount}/usr/lib/dracut/modules.d/80${mount_module}"
cp -r "${mount_module}" "${mount}/usr/lib/dracut/modules.d/80${mount_module}"

cat >$mount/boot/cmdline.txt <<EOF
console=ttyAMA0,115200 console=tty1 logo.nologo ip=dhcp rd.info rd.noverifyssl osrootfs=$osrootfs
EOF
chmod 644 $mount/boot/cmdline.txt

# Include some useful build info in the template if specified
rpi_builder_tag="$(git describe --abbrev=0 2>/dev/null || true)"
rpi_builder_branch="$(git rev-parse --abbrev-ref HEAD)"
rpi_builder_sha="$(git rev-parse --short HEAD)"

rpi_builder_version="${rpi_builder_tag:-$rpi_builder_branch}"

template_file="$template-page.html.template"
echo "Using '$template_file' as default template"
cat src/$template_file | \
	sed \
		-e "s/\[\[RPI_BUILDER_VERSION\]\]/$rpi_builder_version/g" \
		-e "s/\[\[RPI_BUILDER_SHA\]\]/$rpi_builder_sha/g" \
		-e "s/\[\[RPI_BUILDER_DATE\]\]/$(date +%Y-%m-%dT%H:%M:%S%Z)/g" \
	>$mount/home/rocky/default-page.html.template
chmod 644 $mount/home/rocky/default-page.html.template

cp src/set-kiosk-url-from-cmdline.sh $mount/home/rocky/
chmod 755 $mount/home/rocky/set-kiosk-url-from-cmdline.sh

cp src/xinitrc $mount/home/rocky/.xinitrc
chmod 755 $mount/home/rocky/.xinitrc

cp src/set-kiosk-url-from-cmdline.service $mount/etc/systemd/system/
chmod 644 $mount/etc/systemd/system/set-kiosk-url-from-cmdline.service

cp src/x11-autologin.service $mount/etc/systemd/system/
chmod 644 $mount/etc/systemd/system/x11-autologin.service

cp "${script}" "${mount}/tmp/${script}"
chmod 755 "${mount}/tmp/${script}"

# TODO Setup repos which should be used within the chroot

chroot "$mount" "/tmp/$script"
