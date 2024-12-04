#!/bin/sh

remote_script_url="$(cat /proc/cmdline | grep 'kiosk.remote-cfg=' | sed 's/.*\ kiosk.remote-cfg=\([^\ ]\+\).*/\1/')"

remote_script=/tmp/remote-script.sh

if [ -n "$remote_script_url" ]; then
	echo "Fetching remote script from '$remote_script_url'..."
	curl \
		--location \
		--retry 5 \
		--retry-all-errors \
		--max-time 30 \
		--output "$remote_script" \
		--user-agent "curl from $hostname" \
		"$remote_script_url"

	if [[ -f "$remote_script" ]]; then
		echo "Executing remote script..."
		. "$remote_script"
	else
		echo "Did not find script after download, skipping"
	fi
else
	echo "Did not find kernel parameter kiosk.remote-cfg, will not dynamically update"
	systemctl disable apply-remote-configuration.timer
fi
