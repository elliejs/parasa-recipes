#!/bin/sh
# compose.sh -- recipe actions for nginx container.
# Called during creation and update. Source this file, then call
# pre_pkg (before package install) and post_pkg (after).

pre_pkg() {
	:
}

post_pkg() {
	local dest="${DESTDIR:-}"

	# Enable nginx
	sysrc -f "${dest}/etc/rc.conf" nginx_enable="YES"

	# Include app-specific configs from shared www/conf.d/
	# Each app (e.g. recipya) drops its own .conf snippet there.
	mkdir -p "${dest}/usr/local/www/conf.d"
	if ! grep -q 'conf.d' "${dest}/usr/local/etc/nginx/nginx.conf" 2>/dev/null; then
		sed -i '' '/^http {/a\
\    include /usr/local/www/conf.d/*.conf;
' "${dest}/usr/local/etc/nginx/nginx.conf"
	fi
}
