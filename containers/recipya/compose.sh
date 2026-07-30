#!/bin/sh
# compose.sh -- recipe actions for recipya container.
# Recipya is built from source using Go + npm + templ + task.

RECIPYA_PORT="8078"
RECIPYA_USER="recipya"
RECIPYA_HOME="/var/db/recipya"

pre_pkg() {
	:
}

post_pkg() {
	local dest="${DESTDIR:-}"

	# Create service user
	chroot "$dest" pw useradd "$RECIPYA_USER" \
		-d "$RECIPYA_HOME" -s /usr/sbin/nologin \
		-c "Recipya Service" 2>/dev/null || true

	# Build from source
	chroot "$dest" sh -c '
		export PATH="$PATH:/root/go/bin"
		cd /tmp
		git clone https://github.com/reaper47/recipya.git
		go install github.com/go-task/task/v3/cmd/task@latest
		go install github.com/a-h/templ/cmd/templ@latest
		CGO_ENABLED=1 go install -tags extended github.com/gohugoio/hugo@latest
		cd recipya
		task build
		go build -ldflags="-s -w" -o /usr/local/bin/recipya main.go
	'
	rm -rf "${dest}/tmp/recipya" "${dest}/root/go"

	# Create config directory and config.json
	mkdir -p "${dest}${RECIPYA_HOME}/Recipya/Database"
	cat > "${dest}${RECIPYA_HOME}/Recipya/Database/config.json" <<-CONF
	{
	    "server": {
	        "autologin": false,
	        "isDemo": false,
	        "isProduction": true,
	        "noSignups": false,
	        "port": ${RECIPYA_PORT},
	        "url": ""
	    },
	    "email": {
	        "from": "",
	        "sendGridAPIKey": ""
	    },
	    "integrations": {
	        "azureDocumentIntelligence": {
	            "key": "",
	            "endpoint": ""
	        }
	    }
	}
	CONF
	chroot "$dest" chown -R "${RECIPYA_USER}:${RECIPYA_USER}" "$RECIPYA_HOME"

	# rc.d script
	cat > "${dest}/usr/local/etc/rc.d/recipya" <<-'RCD'
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
	chmod +x "${dest}/usr/local/etc/rc.d/recipya"

	# Enable service
	sysrc -f "${dest}/etc/rc.conf" recipya_enable="YES"

	# Emplace nginx reverse proxy config into shared www
	mkdir -p "${dest}/usr/local/www/conf.d"
	cat > "${dest}/usr/local/www/conf.d/recipya.conf" <<-'NGINX'
	server {
	    listen 80;
	    server_name recipes.*;

	    client_max_body_size 250M;

	    location / {
	        proxy_pass http://127.0.0.1:8078;
	        proxy_set_header Host $host;
	        proxy_set_header X-Real-IP $remote_addr;
	        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
	        proxy_set_header X-Forwarded-Proto $scheme;
	    }
	}
	NGINX
}
