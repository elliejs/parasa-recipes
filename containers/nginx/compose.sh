#!/bin/sh
# compose.sh -- recipe actions for nginx container.
# Runs inside the jail via jexec — no chroot or DESTDIR needed.

pre_pkg() {
	:
}

post_pkg() {
	# Enable nginx
	sysrc nginx_enable="YES"

	# Include app-specific configs from shared www/conf.d/
	# Each app (e.g. recipya) drops its own .conf snippet there.
	mkdir -p /usr/local/www/conf.d
	if ! grep -q 'conf.d' /usr/local/etc/nginx/nginx.conf 2>/dev/null; then
		sed -i '' '/^http {/a\
\    include /usr/local/www/conf.d/*.conf;
' /usr/local/etc/nginx/nginx.conf
	fi
}
