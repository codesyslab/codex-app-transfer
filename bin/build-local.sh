#!/usr/bin/env bash
# Локальная сборка .deb (без GitHub Actions).
# Медленнее чем CI (cold cache), но полезно для проверки своих изменений без пуша.
#
# Использование:
#   ./bin/build-local.sh                  # debug build (~5-15 мин)
#   ./bin/build-local.sh --release        # release build (default)
#
# Требует: rustup, node, npm, ~10GB свободного места в target/.

set -euo pipefail

log() { printf '\033[1;34m[build-local]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[build-local]\033[0m %s\n' "$*" >&2; }

MODE="--release"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug) MODE=""; shift ;;
    --release) MODE="--release"; shift ;;
    *) err "Неизвестный флаг: $1"; exit 1 ;;
  esac
done

cd "$(git rev-parse --show-toplevel)"

command -v rustc >/dev/null || { err "rustc не установлен. Поставь rustup"; exit 1; }
command -v node >/dev/null || { err "node не установлен"; exit 1; }
command -v npm >/dev/null || { err "npm не установлен"; exit 1; }

if ! command -v cargo-tauri >/dev/null && ! cargo tauri --version >/dev/null 2>&1; then
  log "Ставлю tauri-cli (это займёт ~5 мин)..."
  cargo install tauri-cli --locked --version "^2.0"
fi

log "Собираю frontend..."
npm --prefix frontend ci
npm --prefix frontend run build

log "Собираю Tauri bundle $MODE..."
cargo tauri build $MODE --bundles deb

TARGET_DIR="$(cargo metadata --no-deps --format-version 1 | python3 -c 'import sys,json;print(json.load(sys.stdin)["target_directory"])')"
DEB="$(ls -t "$TARGET_DIR/release/bundle/deb/"*.deb 2>/dev/null | head -1 || true)"
if [[ -z "$DEB" ]]; then
  DEB="$(ls -t "$TARGET_DIR/$( [[ "$MODE" == "--release" ]] && echo release || echo debug )/bundle/deb/"*.deb 2>/dev/null | head -1 || true)"
fi

if [[ -z "$DEB" ]]; then
  err "Не нашёл .deb после сборки. Проверь $TARGET_DIR"
  exit 1
fi

log "✓ Собрано: $DEB"
log ""
log "Установить сейчас? [y/N]"
read -r ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  sudo apt-get install -y "$DEB"
  log "✓ Установлено. Версия: $(dpkg -l codex-app-transfer | awk '/^ii/{print $3}')"
fi
