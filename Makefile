MNT = mnt
DEST = dest
ASSETS = assets

BASE_IMG = RockyRpi_9.2.img
BASE_IMG_URL = https://dl.rockylinux.org/pub/sig/9/altarch/aarch64/images/$(BASE_IMG).xz

SRCS = $(wildcard src/*)

RPI_BUILDER_VERSION ?= unset
RPI_BUILDER_SHA ?= 999999

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
		-e proc sys dev etc/resolv.conf usr/bin/qemu-aarch64-static

# Divided into multiple buildsteps to provide some caching when developing
# to prevent having to rebuild from start on every change.

.$(MNT).setup: $(DEST)/$(BASE_IMG)
	sudo \
		--preserve-env=RPI_SIZE \
		--preserve-env=RPI_IMAGE_NAME \
		./setup-image.sh $< $(MNT) $(DEST)
	touch $@

.$(MNT).chroot-base: .$(MNT).setup chroot-base.sh
	RPI_BUILDER_VERSION=$(RPI_BUILDER_VERSION) \
	RPI_BUILDER_SHA=$(RPI_BUILDER_SHA) \
	sudo \
		--preserve-env=RPI_BUILDER_VERSION \
		--preserve-env=RPI_BUILDER_SHA \
		--preserve-env=RPI_HTML_TEMPLATE_NAME \
		--preserve-env=RPI_USER_PASSWORD \
		./configure-image.sh $(MNT) chroot-base.sh
	touch $@

.$(MNT).chroot-final: .$(MNT).chroot-base chroot-final.sh $(SRCS)
	RPI_BUILDER_VERSION=$(RPI_BUILDER_VERSION) \
	RPI_BUILDER_SHA=$(RPI_BUILDER_SHA) \
	sudo \
		--preserve-env=RPI_BUILDER_VERSION \
		--preserve-env=RPI_BUILDER_SHA \
		--preserve-env=RPI_HTML_TEMPLATE_NAME \
		--preserve-env=RPI_USER_PASSWORD \
		./configure-image.sh $(MNT) chroot-final.sh
	touch $@

$(DEST)/$(BASE_IMG): $(ASSETS)/$(BASE_IMG).xz
	@mkdir -p $(@D)
	xz --decompress --stdout $< > $@

$(ASSETS)/$(BASE_IMG).xz:
	@mkdir -p $(@D)
	curl \
		--retry 5 \
		--retry-max-time 120 \
		--skip-existing \
		--output $@ \
		$(BASE_IMG_URL)
	curl \
		--retry 5 \
		--retry-max-time 120 \
		--output $@ \
		$(BASE_IMG_URL).sha256sum
	@cd $(ASSETS); sha256sum --check $(BASE_IMG).xz.sha256sum

clean:
	-sudo umount -R mnt
	-sudo losetup -D $(DEST)/rpi-full.img
	-sudo losetup -D $(ASSETS)/$(BASE_IMG)
	-rm -f $(DEST)/rpi-full.img .$(MNT).*
	-rmdir mnt
#-rm -rf --one-file-system $(DEST)
.PHONY: clean

