#!/bin/bash

echo "Running on: `uname -a`"

# Enable the services on login/startup
mkdir -p /etc/systemd/system/graphical.target.wants/
ln -fs \
	/etc/systemd/system/x11-autologin.service \
	/etc/systemd/system/graphical.target.wants/
ln -fs \
	/etc/systemd/system/set-kiosk-url-from-cmdline.service \
	/etc/systemd/system/graphical.target.wants/

# Ensure everything in rockys home folder is owned by rocky
chown -R rocky:rocky /home/rocky

# Remove "unwanted" README
rm -f /home/rocky/README

# Remove log files
# TODO Maybe other files we can remove from the rootfs to shrink the size of it?
find /var/log -type f -name "*.log" -delete
