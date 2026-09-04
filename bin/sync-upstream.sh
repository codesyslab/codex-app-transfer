#!/usr/bin/env bash
# Синхронизирует форк с upstream (Cmochance/codex-app-transfer).
#
# Использование:
#   ./bin/sync-upstream.sh                # fetch + показать что нового в upstream
#   ./bin/sync-upstream.sh --ff-only      # fast-forward main к upstream (только если нет diverge)
#   ./bin/sync-upstream.sh --rebase       # rebase main поверх upstream/main (создаёт merge commit)
#   ./bin/sync-upstream.sh --pr <branch>  # создать ветку <branch> от upstream/main для PR в форк
#
# Безопасный дефолт — только fetch + показать отчёт, ничего не меняет в локальном дереве.

set -euo pipefail

log() { printf '\033[1;34m[sync-upstream]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[sync-upstream]\033[0m %s\n' "$*" >&2; }

cd "$(git rev-parse --show-toplevel)"

git remote get-url upstream >/dev/null || {
  err "upstream remote не настроен. Добавь: git remote add upstream https://github.com/Cmochance/codex-app-transfer.git"
  exit 1
}

log "Fetch upstream..."
git fetch upstream --tags --prune

UPSTREAM_HEAD="$(git rev-parse upstream/main)"
LOCAL_HEAD="$(git rev-parse main)"

log "upstream/main: $UPSTREAM_HEAD"
log "main:          $LOCAL_HEAD"

if [[ "$UPSTREAM_HEAD" == "$LOCAL_HEAD" ]]; then
  log "main уже синхронизирован с upstream/main ✓"
  exit 0
fi

AHEAD="$(git rev-list --count upstream/main..main 2>/dev/null || echo 0)"
BEHIND="$(git rev-list --count main..upstream/main 2>/dev/null || echo 0)"

log "main опережает upstream на $AHEAD коммит(ов), отстаёт на $BEHIND"

if [[ "${1:-}" == "--ff-only" ]]; then
  if [[ "$AHEAD" -gt 0 ]]; then
    err "main имеет $AHEAD локальных коммитов — fast-forward невозможен. Сделай PR в форк или используй --rebase"
    exit 1
  fi
  log "Fast-forward main..."
  git checkout main
  git merge --ff-only upstream/main
  log "Готово ✓"
elif [[ "${1:-}" == "--rebase" ]]; then
  log "Rebase main на upstream/main..."
  git checkout main
  git rebase upstream/main
  log "Готово ✓ Теперь: git push origin main --force-with-lease"
elif [[ "${1:-}" == "--pr" && -n "${2:-}" ]]; then
  log "Создаю ветку $2 от upstream/main..."
  git checkout -b "$2" upstream/main
  log "Готово ✓ Теперь: внеси изменения, commit, push -u origin $2, открой PR в основной репо"
else
  log ""
  log "Новые коммиты в upstream (последние 20):"
  git log --oneline main..upstream/main | head -20
  log ""
  log "Твои локальные коммиты, которых нет в upstream:"
  git log --oneline upstream/main..main | head -20 || true
  log ""
  log "Доступные действия:"
  log "  $0 --ff-only    # fast-forward (если main чистый)"
  log "  $0 --rebase     # rebase main на upstream"
  log "  $0 --pr <name>  # новая ветка от upstream для PR"
fi
