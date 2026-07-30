#!/bin/sh
# compose.sh -- recipe actions for nginx container.
# Runs inside the jail via jexec — no chroot or DESTDIR needed.

pre_pkg() {
	:
}

post_pkg() {
	# Enable nginx
	sysrc nginx_enable="YES"

	# Create conf.d for app-specific location blocks.
	# Each app (e.g. recipya) drops its own .conf snippet here
	# via the shared /usr/local/www nullfs mount.
	mkdir -p /usr/local/www/conf.d

	# Write a clean nginx.conf with the include in the right place
	cat > /usr/local/etc/nginx/nginx.conf <<-'CONF'
	worker_processes 1;

	events {
	    worker_connections 1024;
	}

	http {
	    include       mime.types;
	    default_type  application/octet-stream;

	    sendfile       on;
	    keepalive_timeout 65;

	    server {
	        listen 80;
	        server_name localhost;

	        include /usr/local/www/conf.d/*.conf;

	        location / {
	            root   /usr/local/www/nginx;
	            index  index.html index.htm;
	        }

	        error_page 500 502 503 504 /50x.html;
	        location = /50x.html {
	            root /usr/local/www/nginx-dist;
	        }
	    }
	}
	CONF
}
