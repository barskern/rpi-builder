#!/bin/sh

cmdline_url="$(cat /proc/cmdline | grep 'kiosk.url=' | sed 's/.*\ kiosk.url=\([^\ ]\+\).*/\1/')"

location="$(cat /proc/cmdline | grep 'kiosk.location=' | sed 's/.*\ kiosk.location=\([^\ ]\+\).*/\1/')"

if [ -n "$cmdline_url" ]; then
	echo "Setting '$cmdline_url' as the kiosk url"
	echo "$cmdline_url" >/home/rocky/kiosk-url.txt
else
	echo "Did not find kernel parameter kiosk.url, using default page"
fi

if [ -n "$location" ]; then
	echo "$location" >/home/rocky/kiosk-location.txt
fi
