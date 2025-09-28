#!/usr/bin/env bash
set -euo pipefail

ENVFILE=${ENVFILE:-.env}
BRANCH=${BRANCH:-custom/main}

log() { printf "\033[1;34m[update]\033[0m %s\n" "$*"; }
die() { printf "\033[1;31m[error]\033[0m %s\n" "$*" >&2; exit 1; }

need_file() { [[ -f "$1" ]] || die "missing file: $1"; }
load_env()   { set -a; . "$ENVFILE"; set +a; }

ensure_volumes() {
  for v in caddy_data caddy_config n8n_data; do
    docker volume inspect "$v" >/dev/null 2>&1 || { log "create volume $v"; docker volume create "$v" >/dev/null; }
  done
}

redeploy() {
  FILES=(-f docker-compose.yml -f overrides/docker-compose.override.yml)

  docker compose "${FILES[@]}" pull --ignore-pull-failures || true
  docker compose "${FILES[@]}" build --pull --parallel
  docker compose "${FILES[@]}" up -d --remove-orphans

  # === add: Caddy reload step ===
  if docker compose "${FILES[@]}" ps caddy >/dev/null 2>&1; then
    docker compose "${FILES[@]}" exec caddy caddy validate --config /etc/caddy/Caddyfile
    docker compose "${FILES[@]}" exec caddy caddy reload --config /etc/caddy/Caddyfile --force
  fi

  docker compose "${FILES[@]}" ps
}

main() {
  need_file "$ENVFILE"
  need_file "overrides/Caddyfile.local"
  load_env
  ensure_volumes
  redeploy
}
main "$@"