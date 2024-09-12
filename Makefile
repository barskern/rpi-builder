MNT=mnt
DEST=dest
ASSETS=assets

BASE_IMG=RockyLinuxRpi_9-latest.img
BASE_IMG_URL=https://dl.rockylinux.org/pub/sig/9/altarch/aarch64/images/$(BASE_IMG).xz

SRCS=$(wildcard src/*)

default: $(DEST)/rpi-rocky9-rootfs.sq $(DEST)/rpi-rocky9-boot.tar.gz
.PHONY: default

# The boot configuration that should be available across TFTP
$(DEST)/rpi-rocky9-boot.tar.gz: .$(MNT).chroot-final
	tar -czf $@ --directory="$(MNT)/boot" .

# The squashed root filesystem that should be available across HTTP
$(DEST)/rpi-rocky9-rootfs.sq: .$(MNT).chroot-final
# NB! File permissions should not be modified by mksquashfs,
#     or else it breaks when booting.
# NB! SELinux is disabled for now, see
# (https://superuser.com/questions/1570463/how-can-an-selinux-filesystem-be-relabeled-in-an-unpacked-squashfs-filesystem)
	sudo mksquashfs $(MNT) $@ \
		-noappend \
		-progress \
		-one-file-system \
		-e proc sys dev etc/resolv.conf usr/bin/qemu-aarch64-static

# Divided into multiple buildsteps to provide some caching when developing
# to prevent having to rebuild from start on every change.

.$(MNT).setup: $(ASSETS)/$(BASE_IMG)
	sudo \
		--preserve-env=RPI_SIZE \
		--preserve-env=RPI_IMAGE_NAME \
		./setup-image.sh $< $(MNT) $(DEST)
	touch $@

.$(MNT).chroot-base: .$(MNT).setup chroot-base.sh
	sudo \
		--preserve-env=RPI_OSROOTFS \
		--preserve-env=RPI_HTML_TEMPLATE_NAME \
		./configure-image.sh $(MNT) chroot-base.sh
	touch $@

.$(MNT).chroot-final: .$(MNT).chroot-base chroot-final.sh $(SRCS)
	sudo \
		--preserve-env=RPI_OSROOTFS \
		--preserve-env=RPI_HTML_TEMPLATE_NAME \
		./configure-image.sh $(MNT) chroot-final.sh
	touch $@

$(DEST)/$(BASE_IMG): $(ASSETS)/$(BASE_IMG).xz
	xz --decompress --stdout $< > $@

$(ASSETS)/$(BASE_IMG).xz:
	@mkdir -p $(@D)
	curl \
		--retry 5 \
		--retry-max-time 120 \
		--output $@ \
		$(BASE_IMG_URL)

clean:
	-sudo umount -R mnt
	-sudo losetup -D $(DEST)/rpi-full.img
	-sudo losetup -D $(ASSETS)/$(BASE_IMG)
	-rm -f $(DEST)/rpi-full.img .$(MNT).*
	-rmdir mnt
#-rm -rf --one-file-system $(DEST)
.PHONY: clean

