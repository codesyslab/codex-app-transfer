#!/usr/bin/env bash
# Полный цикл релиза: bump version → tag → push → GitHub Actions собирает deb → install.
#
# Использование:
#   ./bin/release.sh 2.4.6                # tag v2.4.6 + push, GH Actions соберёт
#   ./bin/release.sh 2.4.6 --no-install   # без установки после релиза
#
# Требует: gh (Codesyslab), clean tree, push-доступ к форку.

set -euo pipefail

log() { printf '\033[1;34m[release]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[release]\033[0m %s\n' "$*" >&2; }

VERSION="${1:-}"
INSTALL_AFTER=true

if [[ -z "$VERSION" ]]; then
  err "Укажи версию: $0 2.4.6"
  exit 1
fi
shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-install) INSTALL_AFTER=false; shift ;;
    *) err "Неизвестный флаг: $1"; exit 1 ;;
  esac
done

cd "$(git rev-parse --show-toplevel)"

if [[ -n "$(git status --porcelain)" ]]; then
  err "Working tree не чистый. Сначала commit или stash:"
  git status --short
  exit 1
fi

CURRENT_BRANCH="$(git branch --show-current)"
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  err "Ты на ветке $CURRENT_BRANCH, не main. Переключись: git checkout main"
  exit 1
fi

log "Текущая версия: $(dpkg -l codex-app-transfer 2>/dev/null | awk '/^ii/{print $3}' || echo 'не установлен')"
log "Новая версия:   $VERSION"

TAG="v$VERSION"

log "Создаю тег $TAG..."
git tag -a "$TAG" -m "release: $VERSION"

log "Push main + теги в origin..."
git push origin main --follow-tags

log "✓ Запушено. GitHub Actions начнёт сборку .deb"
log "  Следи за прогрессом: gh run watch --repo codesyslab/codex-app-transfer"
log "  Когда релиз опубликуется — запусти bin/install-latest.sh $TAG"

if [[ "$INSTALL_AFTER" == true ]]; then
  log ""
  log "Жду публикацию релиза (poll gh release view)..."
  for i in {1..60}; do
    if gh release view "$TAG" --repo codesyslab/codex-app-transfer >/dev/null 2>&1; then
      log "Релиз опубликован ✓"
      "$(git rev-parse --show-toplevel)/bin/install-latest.sh" "$TAG"
      exit 0
    fi
    sleep 30
  done
  err "Релиз не опубликовался за 30 мин. Запусти bin/install-latest.sh $TAG вручную"
  exit 1
fi
