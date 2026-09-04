#!/usr/bin/env bash
# Скачивает последний релиз .deb из форка codesyslab/codex-app-transfer
# и ставит его поверх установленного codex-app-transfer (через apt).
#
# Использование:
#   ./bin/install-latest.sh                # последний релиз из форка
#   ./bin/install-latest.sh v2.4.5         # конкретная версия
#   ./bin/install-latest.sh --check        # только показать что есть нового
#
# Требует: gh (авторизован под codesyslab), curl, sudo, apt

set -euo pipefail

REPO="${CODEX_TRANSFER_REPO:-codesyslab/codex-app-transfer}"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

log() { printf '\033[1;34m[install-latest]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[install-latest]\033[0m %s\n' "$*" >&2; }

resolve_tag() {
  if [[ "${1:-}" == "--check" ]]; then
    gh release view --repo "$REPO" --json tagName --jq '.tagName'
    exit 0
  fi
  if [[ -n "${1:-}" && "${1:-}" != "latest" ]]; then
    echo "$1"
  else
    gh release view --repo "$REPO" --json tagName --jq '.tagName'
  fi
}

main() {
  command -v gh >/dev/null || { err "gh не установлен"; exit 1; }
  command -v curl >/dev/null || { err "curl не установлен"; exit 1; }

  local tag
  tag="$(resolve_tag "${1:-latest}")"
  log "Версия: $tag"

  local deb_name="Codex-App-Transfer-${tag}-Linux-x86_64.deb"
  local deb_url="https://github.com/${REPO}/releases/download/${tag}/${deb_name}"

  log "Скачиваю: $deb_url"
  curl -fL --retry 3 -o "$TMPDIR/$deb_name" "$deb_url" || {
    err "Не удалось скачать. Проверь что релиз $tag существует в $REPO и содержит $deb_name"
    exit 1
  }

  log "SHA256:"
  sha256sum "$TMPDIR/$deb_name"

  log "Устанавливаю через apt..."
  sudo apt-get install -y "$TMPDIR/$deb_name"

  log "Готово. Версия после установки:"
  dpkg -l codex-app-transfer | tail -1
}

main "$@"
