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
  set -euo pipefail

  local FAST_MODE=0
  if [[ "${1:-}" == "--fast" ]]; then
    FAST_MODE=1
    shift
  fi

  # search
  local files=("docker-compose.yml")
  while IFS= read -r -d '' f; do files+=("$f"); done < <(
    find overrides -type f -name 'docker-compose*.yml' -print0 2>/dev/null | sort -z
  )

  local args=()
  for f in "${files[@]}"; do
    [[ -f "$f" ]] && args+=("-f" "$f")
  done

  echo "[redeploy] using compose files:"
  printf '  - %s\n' "${files[@]}"

  if [[ "$FAST_MODE" -eq 1 ]]; then
    echo "[redeploy] 🚀 Fast mode (no build, no pull)"
    docker compose "${args[@]}" up -d --no-build
  else
    echo "[redeploy] 🔨 Full mode (pull, build, remove orphans)"
    docker compose "${args[@]}" pull --ignore-pull-failures || true
    docker compose "${args[@]}" build --pull --parallel
    docker compose "${args[@]}" up -d --remove-orphans
  fi
}


main() {
  need_file "$ENVFILE"
  need_file "overrides/Caddyfile.local"
  load_env
  ensure_volumes
  redeploy
}
main "$@"
