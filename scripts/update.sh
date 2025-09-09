#!/usr/bin/env bash
set -euo pipefail

ENVFILE=${ENVFILE:-.env}
BRANCH=${BRANCH:-custom/main}
UP=${UP:-upstream}
COMPOSE_FILES=(-f docker-compose.yml -f overrides/docker-compose.override.yml)

log() { printf "\033[1;34m[update]\033[0m %s\n" "$*"; }
die() { printf "\033[1;31m[error]\033[0m %s\n" "$*" >&2; exit 1; }

need_file() { [[ -f "$1" ]] || die "missing file: $1"; }
load_env()   { set -a; . "$ENVFILE"; set +a; }
check_envs() { for v in N8N_HOST WEBHOOK_URL DB_PASSWORD; do [[ -n "${!v:-}" ]] || die "missing env: $v"; done; }

ensure_volumes() {
  for v in caddy_data caddy_config n8n_data; do
    docker volume inspect "$v" >/dev/null 2>&1 || { log "create volume $v"; docker volume create "$v" >/dev/null; }
  done
}

git_update() {
  log "fetch $UP --tags";   git fetch "$UP" --tags
  log "checkout $BRANCH";   git checkout "$BRANCH"
  log "rebase $UP/main";    git rebase "$UP/main" --autostash
}

redeploy() {
  log "compose up n8n (no-deps, build)"
  docker compose "${COMPOSE_FILES[@]}" up -d --no-deps --build n8n
  log "done ✅"
}

main() {
  need_file "$ENVFILE"
  need_file "overrides/Caddyfile.local"
  load_env
  check_envs
  ensure_volumes
  git_update
  redeploy
}
main "$@"