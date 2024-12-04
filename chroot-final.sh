#!/bin/bash

set -exuo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

echo "Running on: `uname -a`"

# Very useful for development/debugging
#systemctl disable sshd

# Ensure wifi is disabled
systemctl disable wpa_supplicant

# Enable the services on login/startup
systemctl enable x11-autologin.service
systemctl enable set-kiosk-url-from-cmdline.service
systemctl enable apply-remote-configuration.timer
systemctl enable redo-dhcp.service

# Ensure everything in rockys home folder is owned by rocky
chown -R rocky:rocky /home/rocky

# Set the user password
echo "$RPI_USER_PASSWORD" | passwd --stdin rocky

# Remove "unwanted" README
rm -f /home/rocky/README

# Remove log files
find /var/log -type f -name "*.log" -delete

# TODO Maybe there are other files we can remove from rootfs to make it skinner?
