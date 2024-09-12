#!/bin/bash

# called by dracut
check() {
	return 255
}

# called by dracut
depends() {
	echo "url-lib"
	return 0
}

# called by dracut
install() {
	inst_hook mount 80 "$moddir/rootfs-over-http.sh"
}
