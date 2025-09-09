#!/usr/bin/env bash
set -e

BRANCH=${BRANCH:-custom/main}
UP=upstream
FILES=(-f docker-compose.yml -f overrides/docker-compose.override.yml)
ENVFILE=${ENVFILE:-.env}

# --- 必須ファイルの存在確認 ---
need() { [[ -f "$1" ]] || { echo "✋ required file missing: $1"; exit 1; }; }
need "$ENVFILE"
need "overrides/Caddyfile.local"

# 未コミット変更チェック
git diff --quiet && git diff --cached --quiet || {
  echo "[ERROR] You have uncommitted changes. Please commit or stash them."
  exit 1
}

# 上流を fetch
git fetch "$UP" --tags

# 自分ブランチを rebase
git checkout "$BRANCH"
git rebase "$UP/main" --autostash

# コンテナ更新
docker compose "${FILES[@]}" up -d --build

echo "✅ update done"
