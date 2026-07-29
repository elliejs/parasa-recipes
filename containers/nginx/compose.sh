#!/bin/sh
# compose.sh -- recipe actions for nginx container.
# Called during creation and update. Source this file, then call
# pre_pkg (before package install) and post_pkg (after).

pre_pkg() {
	:
}

post_pkg() {
	# Enable nginx in the container
	sysrc -f "${DESTDIR}/etc/rc.conf" nginx_enable="YES"
}
