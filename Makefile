.PHONY: up down logs pull doctor check env tunnel

export HOST LOCAL_PORT REMOTE_PORT

LOAD_ENV = set -e; set -a; . ./.env; set +a;
COMPOSE = $(LOAD_ENV) docker compose --env-file /dev/null

up: check
	@$(LOAD_ENV) mkdir -p "$$ROMM_LIBRARY_PATH/roms/ps" "$$ROMM_LIBRARY_PATH/roms/dos" "$$ROMM_LIBRARY_PATH/roms/win9x" "$$ROMM_LIBRARY_PATH/bios/ps"
	@$(COMPOSE) up -d --wait --wait-timeout 180
	@echo 'RomM is running. Open localhost on ROMM_PORT from .env.'

down:
	@$(COMPOSE) down

logs:
	@$(COMPOSE) logs --follow --tail 100

pull: check
	@$(COMPOSE) pull

doctor: check
	@docker info --format 'Docker {{.ServerVersion}}: OK'

tunnel:
	@for field in HOST LOCAL_PORT REMOTE_PORT; do \
	    test -n "$$(printenv "$$field")" || { echo "Missing $$field. Pass HOST, LOCAL_PORT and REMOTE_PORT explicitly." >&2; exit 1; }; \
	done
	@echo "Open http://localhost:$$LOCAL_PORT — keep this terminal open; Ctrl+C closes the tunnel."
	@ssh -N -T -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
	    -L "127.0.0.1:$$LOCAL_PORT:127.0.0.1:$$REMOTE_PORT" -- "$$HOST"

check: env
	@$(LOAD_ENV) \
	for field in ROMM_LIBRARY_PATH ROMM_PORT ROMM_VERSION MARIADB_VERSION DB_NAME DB_USER DB_PASSWD DB_ROOT_PASSWD ROMM_AUTH_SECRET_KEY; do \
	    [ -n "$$(printenv "$$field")" ] || { echo "Set $$field in .env" >&2; exit 1; }; \
	done; \
	case "$$ROMM_LIBRARY_PATH" in /*) ;; *) echo 'ROMM_LIBRARY_PATH must be an absolute path.' >&2; exit 1;; esac; \
	[ -d "$$ROMM_LIBRARY_PATH" ] || { echo "Library directory does not exist: $$ROMM_LIBRARY_PATH" >&2; exit 1; }
	@$(COMPOSE) config --quiet

env:
	@set -eu; \
	if [ ! -e .env ]; then \
	    password=$$(openssl rand -hex 32); \
	    root_password=$$(openssl rand -hex 32); \
	    auth_secret=$$(openssl rand -hex 32); \
	    (umask 077; set -C; printf '%s\n' \
	        '# Absolute path to an existing library outside this repository; quote paths with spaces.' \
	        'ROMM_LIBRARY_PATH=' '' \
	        '# Local web interface port: http://localhost:8080 by default.' \
	        'ROMM_PORT=8080' '' \
	        '# Official RomM Docker image tag.' \
	        'ROMM_VERSION=5.4.1' '' \
	        '# Official MariaDB Docker image tag.' \
	        'MARIADB_VERSION=11.4' '' \
	        '# Database name, created on the first startup.' \
	        'DB_NAME=romm' '' \
	        '# Database user for RomM, created on the first startup.' \
	        'DB_USER=romm' '' \
	        '# Generated password for the RomM database user. Keep after initialization.' \
	        "DB_PASSWD=$$password" '' \
	        '# Generated MariaDB root password. Keep after initialization.' \
	        "DB_ROOT_PASSWD=$$root_password" '' \
	        '# Generated RomM authentication secret. Keep the same value between restarts.' \
	        "ROMM_AUTH_SECRET_KEY=$$auth_secret" > .env); \
	    echo 'Created .env. Fill in ROMM_LIBRARY_PATH and run make up again. Passwords are already generated.'; \
	    exit 1; \
	fi
