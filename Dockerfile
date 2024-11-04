FROM multiarch/qemu-user-static:aarch64 as qemu

FROM rockylinux:9

COPY --from=qemu /usr/bin/qemu-aarch64-static /usr/bin

RUN yum -y install \
	sudo \
	xz \
	git \
	make \
	squashfs-tools \
	parted \
	dosfstools \
	e2fsprogs

COPY assets /src/assets
COPY rootfs-over-http /src/rootfs-over-http
COPY chroot-base.sh /src
COPY chroot-final.sh /src
COPY configure-image.sh /src
COPY Makefile /src
COPY setup-image.sh /src
COPY src /src/src

WORKDIR /src

RUN ls -la
RUN uname -a

CMD ["make"]
