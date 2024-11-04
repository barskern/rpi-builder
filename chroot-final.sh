#!/bin/bash

echo "Running on: `uname -a`"

# Ensure ssh is disabled
#systemctl disable sshd

# Ensure wifi is disabled
systemctl disable wpa_supplicant

# Enable the services on login/startup
systemctl enable x11-autologin.service
systemctl enable set-kiosk-url-from-cmdline.service

# Ensure everything in rockys home folder is owned by rocky
chown -R rocky:rocky /home/rocky

# Set the user password
echo "$RPI_USER_PASSWORD" | passwd --stdin rocky

# Remove "unwanted" README
rm -f /home/rocky/README

# Remove log files
find /var/log -type f -name "*.log" -delete

# TODO Temporary, fix DNS over DHCP..
echo "nameserver 10.14.211.129" > /etc/resolv.conf

# TODO Maybe there are other files we can remove from rootfs?
