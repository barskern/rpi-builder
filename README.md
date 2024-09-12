# RPI booted using only RAM

This is a way of running Raspberry PI 4B (RPI) which requires no SD-card (after
setup). The RPI is booted over the network, and the full filesystem (which is
created using SquashFS) is loaded into RAM over HTTP. Lastly, a OverlayFS is
setup to enable seamless writing to the rootfs despite the SquashFS being
read-only.

This setup is suitable for immutable/non-persistent infrastructure use-cases,
such as kiosks, runners or similar. Out-of-the-box this repository includes a
setup for running the RPI as a simple kiosk displaying a HTTP page, however this
can be easily modified through the `xinitrc` script included.

This repo includes the setup to build and configure such a setup on an x86_64
system. This means that the RPI doesn't need to be used in the bootstrapping
process, and enables this method to be easily used in a CI/CD pipeline.

This project uses the [Rocky Linux Raspberry PI image maintained by SIG/Alt
Arch](https://git.resf.org/sig_altarch/RockyRpi) as a base.

## Build Requirements

- Some packages, including (but not limited to):
    - `make`
    - `curl`
    - `squashfs-tools`
    - `qemu-user-static`
    - `qemu-user-static-binfmt`
    - `aarch64-linux-gnu-gcc`
    - `rpi-imager`

## Runtime Requirements

- SD card to run a one-time firmware update of the RPI.
- DHCP service which can supply Network boot/BOOTP configuration.
- TFTP service to serve the RPI firmware, initial RAM disk, and kernel.
- HTTP service to serve the squashed filesystem.

## Setup

1. Prepare the RPI:
    1. Flash the SD card with `rpi-imager`, select utility and the 'Network boot'
       option (which tries to boot from the SD card first, and then from the network).
    2. Power the RPI with the SD card inserted, wait for the successful green screen.
    3. Then reboot the RPI without the SD card, and you should arrive at a
       startup screen where it shows that it tries to network boot. Note down
       the last 8 hex digits in the RPI serial number and MAC address.
3. Set the `RPI_OSROOTFS` environment variable to a reachable HTTP location from
   which the RPI will download the squashed root filesystem.
4. Run `make` to build `rpi-rocky9-boot.tar.gz` (the firmware, kernel and
   initramfs) and `rpi-rocky9-rootfs.sq` (the squashed root filesystem).
5. Unpack the `*-boot.tar.gz` file on the TFTP server in a folder with the same
   name as the RPI serial number from above. This must be a folder in the TFTP
   root (or if further customization is wanted of this location, a custom SD
   card must be made when flashing).
6. Move the `*-rootfs.sq` file to the HTTP server at the same location as the
   configured `RPI_OSROOTFS` environment variable.
7. Configure the DHCP server to provide at least the options `vendor-class-identifier=PXEClient`, `tftp-server-name=<IP-address of TFTP server>` and `vendor-encapsulated-options="Raspberry Pi Boot   "` (NB! Last 3 spaces must be included). For example, the configuration for DHCPD might look like:
8. When the DHCP server starts serving these new config options, the RPI will
   eventually retry to boot across the network and now successfully do so.

```conf
# /etc/dhcp/dhcpd.conf

# ...

host <RPI hostname> {
    hardware ethernet <RPI MAC>;
    fixed-address <RPI IP-address>;
    next-server <IP-address of TFTP server>;

    option tftp-server-name "<IP-address of TFTP server>";
    option vendor-class-identifier "PXEClient";
    option vendor-encapsulated-options "Raspberry Pi Boot   ";
}
```
