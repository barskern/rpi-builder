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

install_file() {
	file="$1"
	dest="$2"
	perm="${3:-"644"}"
	[ -z "$file" ] && { echo "Error: file argument empty"; exit 1; }
	[ -z "$dest" ] && { echo "Error: dest argument empty"; exit 1; }

	# Ensure dest is the path to the file itself, important for permission below
	if [ "${dest: -1}" == "/" ]; then
		dest="$dest$file"
	fi

	echo "Installing '$file' to '$dest' with '$perm'"

	cp "src/$file" "$mount$dest"
	chmod "$perm" "$mount$dest"
}

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

install_file 10-harden.conf /etc/X11/xorg.conf.d/
install_file set-kiosk-url-from-cmdline.service /etc/systemd/system/
install_file x11-autologin.service /etc/systemd/system/

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

install_file set-kiosk-url-from-cmdline.sh /home/rocky/ 755
install_file xinitrc /home/rocky/.xinitrc 755

# TODO Setup repos which should be used within the chroot

cp "$script" "$mount/tmp/"
chmod 755 "$mount/tmp/$script"
chroot "$mount" "/tmp/$script"
