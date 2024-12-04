#!/bin/sh

sudo nmcli con down eth0
sudo nmcli con up eth0
