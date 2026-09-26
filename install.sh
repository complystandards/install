#!/bin/sh
# Comply Standards: one-command install for a self-hosted app (Ubuntu/Debian/any Linux with Docker).
#
#   curl -fsSL <install-url>/install.sh | sudo sh -s -- <app>
#
# Installs Docker if needed, signs in with your access key (if you were given one), then fetches the approved
# release and hands over to "guardian", which asks a few questions, generates all passwords and keys, starts
# everything and checks it is healthy. From then on guardian backs up nightly and installs approved updates by
# itself (with automatic rollback). Safe to run again: an existing installation keeps its settings.
#
# Answers can be given up front instead of typed, e.g.:  ... | sudo PUBLIC_HOST=app.example.com sh -s -- cbam
set -eu

APP="${1:-${APP:-}}"
REGISTRY="${REGISTRY:-ghcr.io/complystandards}"
CHANNEL="${CHANNEL:-stable}"
[ -n "$APP" ] || { echo "Usage: curl -fsSL <install-url>/install.sh | sudo sh -s -- <app>"; exit 1; }
[ "$(id -u)" = 0 ] || { echo "Please run with sudo (as root)."; exit 1; }
DIR="${INSTALL_DIR:-/opt/$APP}"
BUNDLE="$REGISTRY/$APP-bundle:$CHANNEL"

say() { printf '\n==> %s\n' "$1"; }

if ! command -v docker >/dev/null 2>&1; then
  say "Installing Docker"
  curl -fsSL https://get.docker.com | sh
fi
docker compose version >/dev/null 2>&1 || { echo "Docker Compose plugin is missing (install docker-compose-plugin)."; exit 1; }

# Interactive if a terminal is available (curl | sh keeps the keyboard on /dev/tty); otherwise use preset answers.
if ( : </dev/tty ) 2>/dev/null; then TTY="-it"; IN=/dev/tty; else TTY="-i"; IN=/dev/null; fi

if [ -z "${ACCESS_KEY:-}" ] && [ "$IN" = /dev/tty ] && [ "${NO_ACCESS_KEY:-}" != 1 ]; then
  printf 'Access key from Comply Standards (press Enter if you were not given one): '
  read -r ACCESS_KEY </dev/tty || ACCESS_KEY=""
fi
if [ -n "${ACCESS_KEY:-}" ]; then
  say "Signing in to the software registry"
  echo "$ACCESS_KEY" | docker login "${REGISTRY%%/*}" -u "${ACCESS_USER:-complystandards-clients}" --password-stdin >/dev/null
fi

say "Fetching the approved release of $APP"
docker pull -q "$BUNDLE" >/dev/null
GUARDIAN=$(docker run --rm --entrypoint cat "$BUNDLE" /bundle/appliance.json \
  | sed -n 's/.*"guardian_image": *"\([^"]*\)".*/\1/p')
docker pull -q "$GUARDIAN" >/dev/null

mkdir -p "$DIR" /root/.docker
# Hand over any answers given up front (plain VAR=value from the environment), minus the shell's own variables.
ANSWERS=$(mktemp)
env | grep -E '^[A-Z][A-Z0-9_]*=' \
  | grep -vE '^(PATH|HOME|HOSTNAME|PWD|OLDPWD|SHLVL|TERM|USER|LOGNAME|SHELL|MAIL|LANG|LC_[A-Z]+|SUDO_[A-Z]+|DOCKER_[A-Z_]+|ACCESS_KEY|ACCESS_USER|APP|REGISTRY|CHANNEL|INSTALL_DIR|DIR|BUNDLE|GUARDIAN|TTY|IN|ANSWERS)=' \
  > "$ANSWERS" || true

say "Setting up $APP in $DIR"
# shellcheck disable=SC2086
docker run --rm $TTY --env-file "$ANSWERS" -e APP_DIR="$DIR" \
  -v /var/run/docker.sock:/var/run/docker.sock -v "$DIR:$DIR" -v /root/.docker:/root/.docker:ro \
  "$GUARDIAN" install "$BUNDLE" <"$IN"
rm -f "$ANSWERS"
