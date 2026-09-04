# Правила проекта — codesyslab/codex-app-transfer (fork)

> Локальная шпаргалка maintainer'а форка (codesyslab). Не для AI — для человека.
> Для AI: читай `AGENTS.fork.md` в корне.

## TL;DR

| Действие | Команда |
|----------|---------|
| Обновить установленный deb | `bin/install-latest.sh` |
| Проверить обновы upstream | `bin/sync-upstream.sh` |
| Применить обновы upstream | `bin/sync-upstream.sh --rebase && git push --force-with-lease` |
| Собрать deb локально | `bin/build-local.sh` |
| Выпустить релиз | `bin/release.sh 2.4.6` |
| Посмотреть лог авто-обновления | `tail -f ~/.local/log/codex-app-transfer-update.log` |
| Статус авто-обновления | `systemctl --user status codex-app-transfer-update.timer` |

## Железные правила

1. **main содержит только:** upstream код + наши fork-only патчи (`bin/`, `docs/`, `AGENTS.md`, `CONTRIBUTING.md`).
2. **Любое изменение upstream кода — через feature-ветку** от `upstream/main`, не напрямую в `main`.
3. **`docs/` в .gitignore upstream'а** — добавляем файлы туда через `git add -f` (это намеренно, см. `docs/WORKFLOW.md`).
4. **Секреты никогда в репо.** Перед `git commit` всегда `git diff --cached | grep -iE '(api[-_]?key|token|secret|password)'`.
5. **Тег версии — только через `bin/release.sh`**, не вручную. Скрипт проверяет чистоту tree и ветку.

## Sync cadence

| Когда | Действие |
|-------|----------|
| Раз в неделю | `bin/sync-upstream.sh` — посмотреть что нового в upstream |
| Когда есть что полезное | `bin/sync-upstream.sh --rebase && git push --force-with-lease` |
| Когда upstream выпустил v2.4.x | (опц.) cherry-pick в main или дождаться нашего следующего `--rebase` |
| Когда CI зелёный после push | сразу `bin/install-latest.sh` для проверки |

## Pre-push hook

Активен по умолчанию (если выставлен `core.hooksPath = .githooks`):

```bash
git config core.hooksPath .githooks
```

Что делает:
1. `cargo fmt --all -- --check`
2. `cargo check --workspace --all-targets --exclude codex-app-transfer`
3. `cargo test --workspace --no-fail-fast --exclude codex-app-transfer`
4. (на main) drift в test repo — advisory

Обход: `git push --no-verify` (CI всё равно забанит, не злоупотребляй).

## Релиз — полный цикл

```bash
# 1. Убедиться что локально свежий код
git checkout main
git pull --rebase
bin/sync-upstream.sh --ff-only   # если есть новые коммиты в upstream

# 2. Обновить версию во всех нужных местах (если есть version pinning)
#    обычно не нужно — версия берётся из тега

# 3. Bump
bin/release.sh 2.4.6             # tag + push + ждать CI + install

# 4. После релиза — проверить что deb установился и работает
dpkg -l codex-app-transfer
codex-app-transfer --help || true   # GUI, может не иметь --help
```

## Авто-обновление через systemd timer

| Файл | Что |
|------|-----|
| `~/.config/systemd/user/codex-app-transfer-update.service` | oneshot сервис |
| `~/.config/systemd/user/codex-app-transfer-update.timer` | ежедневно 04:17 ±15 мин |
| `~/.local/log/codex-app-transfer-update.log` | stdout/stderr |

Изменить расписание:
```bash
systemctl --user edit codex-app-transfer-update.timer
```

Временно отключить:
```bash
systemctl --user stop codex-app-transfer-update.timer
```

Включить обратно:
```bash
systemctl --user start codex-app-transfer-update.timer
```

## Аварийные ситуации

| Симптом | Что делать |
|---------|------------|
| `bin/install-latest.sh` падает с 404 | В форке нет релиза. Сделай `bin/release.sh 2.4.6`. |
| `bin/release.sh` отказывается — "tree не чистый" | `git status` → commit или stash |
| CI на теге красный | Открой [Actions](https://github.com/codesyslab/codex-app-transfer/actions), почини, удали тег, пересоздай |
| После `--rebase` конфликт | Resolve → `git rebase --continue` → `git push --force-with-lease` |
| Случайно закоммитил секрет | Немедленно: rotate ключ → `git filter-repo --invert-paths --path <file>` → force push → уведоми всех кто мог клонировать |
| Pre-push hook красный | `cargo fmt --all` затем повтори push |

## Что НЕ трогать

- `LICENSE.txt` — наследуется от upstream
- `.github/workflows/release.yml` — если править, синхронизировать с upstream
- `Cargo.lock` — обновляется автоматически при `cargo build`, руками не править
- `.githooks/pre-push` — это upstream gate, изменения повлияют на чужой workflow
- upstream код (`crates/`, `src-tauri/`, `frontend/`) — только через feature-ветку и PR
