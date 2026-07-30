#!/bin/sh
# compose.sh -- recipe actions for recipya container.
# Recipya is built from source using Go + npm + templ + task.
# Runs inside the jail via jexec — no chroot or DESTDIR needed.

RECIPYA_PORT="8078"
RECIPYA_USER="recipya"
RECIPYA_HOME="/var/db/recipya"

pre_pkg() {
	:
}

post_pkg() {
	# Create service user
	pw useradd "$RECIPYA_USER" \
		-d "$RECIPYA_HOME" -s /usr/sbin/nologin \
		-c "Recipya Service" 2>/dev/null || true

	# Build from source
	export PATH="$PATH:/root/go/bin"
	cd /tmp
	git clone https://github.com/reaper47/recipya.git
	go install github.com/go-task/task/v3/cmd/task@latest
	go install github.com/a-h/templ/cmd/templ@latest
	CGO_ENABLED=1 go install -tags extended github.com/gohugoio/hugo@latest
	cd recipya
	task build
	go build -ldflags="-s -w" -o /usr/local/bin/recipya main.go
	cd /
	rm -rf /tmp/recipya /root/go

	# Create config directory and config.json
	mkdir -p "${RECIPYA_HOME}/Recipya"
	cat > "${RECIPYA_HOME}/Recipya/config.json" <<-CONF
	{
	    "server": {
	        "autologin": false,
	        "isDemo": false,
	        "isProduction": true,
	        "noSignups": false,
	        "port": ${RECIPYA_PORT},
	        "url": "http://0.0.0.0"
	    },
	    "email": {
	        "from": "",
	        "host": "",
	        "username": "",
	        "password": ""
	    },
	    "integrations": {
	        "azureDocumentIntelligence": {
	            "endpoint": "",
	            "key": ""
	        }
	    }
	}
	CONF
	chown -R "${RECIPYA_USER}:${RECIPYA_USER}" "$RECIPYA_HOME"

	# rc.d script
	cat > /usr/local/etc/rc.d/recipya <<-'RCD'
	#!/bin/sh

	# PROVIDE: recipya
	# REQUIRE: DAEMON
	# KEYWORD: shutdown

	. /etc/rc.subr

	name="recipya"
	rcvar="recipya_enable"

	load_rc_config $name

	: ${recipya_enable:="NO"}
	: ${recipya_user:="recipya"}

	pidfile="/var/run/${name}.pid"
	command="/usr/local/bin/recipya"
	command_args="serve"

	recipya_env="XDG_CONFIG_HOME=/var/db/recipya HOME=/var/db/recipya"

	start_cmd="recipya_start"

	recipya_start()
	{
	    echo "Starting ${name}."
	    /usr/sbin/daemon -p ${pidfile} -u ${recipya_user} \
	        env ${recipya_env} ${command} ${command_args}
	}

	run_rc_command "$1"
	RCD
	chmod +x /usr/local/etc/rc.d/recipya

	# Enable service
	sysrc nginx_enable="YES"
	sysrc recipya_enable="YES"

	# Emplace nginx reverse proxy config into shared www
	mkdir -p /usr/local/www/conf.d
	cat > /usr/local/www/conf.d/recipya.conf <<-'NGINX'
	location /recipes/ {
	    proxy_pass http://127.0.0.1:8078/;
	    proxy_set_header Host $host;
	    proxy_set_header X-Real-IP $remote_addr;
	    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
	    proxy_set_header X-Forwarded-Proto $scheme;
	    client_max_body_size 250M;
	}
	NGINX
}
