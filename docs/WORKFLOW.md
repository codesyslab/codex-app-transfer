# Codex App Transfer (форк) — рабочий процесс

Это твой локальный клон форка [`codesyslab/codex-app-transfer`](https://github.com/codesyslab/codex-app-transfer).
Цель форка: держать свою сборку с возможностью sync с upstream (`Cmochance/codex-app-transfer`),
вносить локальные патчи и выпускать собственные `.deb` через GitHub Actions.

## Структура

```
bin/
├── install-latest.sh   Скачать последний .deb из релизов форка и поставить
├── sync-upstream.sh    Забрать свежие коммиты из Cmochance/codex-app-transfer
├── build-local.sh      Собрать .deb локально через cargo tauri (без CI)
└── release.sh          bump version → tag → push → CI собирает deb → install
```

## Remotes

| Remote | URL | Назначение |
|--------|-----|------------|
| `origin` | https://github.com/codesyslab/codex-app-transfer.git | Твой форк. Сюда пушишь. |
| `upstream` | https://github.com/Cmochance/codex-app-transfer.git | Оригинал. Только fetch. |

## Типичные сценарии

### 1. Обновить установленный deb до последней версии

```bash
bin/install-latest.sh                  # последний релиз из форка
bin/install-latest.sh v2.4.5           # конкретная версия
bin/install-latest.sh --check          # только показать что есть
```

### 2. Забрать свежие коммиты из upstream (без изменений)

```bash
bin/sync-upstream.sh                   # fetch + отчёт (ничего не меняет)
```

Увидишь сколько коммитов upstream опережает main и список изменений.

### 3. Применить обнову upstream в форк (fast-forward)

Если ты не вносил своих коммитов в main:

```bash
bin/sync-upstream.sh --ff-only
```

### 4. Применить обнову upstream (rebase — твои коммиты окажутся сверху)

```bash
bin/sync-upstream.sh --rebase
git push origin main --force-with-lease
```

### 5. Внести свой патч (PR из upstream в свой форк)

```bash
bin/sync-upstream.sh --pr my-feature   # новая ветка от upstream/main
# правишь код, коммитишь
git push origin my-feature
# в GitHub: открываешь PR в codesyslab/codex-app-transfer (форк → форк)
```

### 6. Собрать и установить свой .deb без CI

```bash
bin/build-local.sh                     # release build (~10-20 мин в первый раз)
```

Полезно для проверки патча перед пушем.

### 7. Выпустить релиз (полный цикл)

```bash
# чистый tree, на main, версия не дублируется
bin/release.sh 2.4.6                   # tag + push + ждать CI + install
bin/release.sh 2.4.6 --no-install      # tag + push (без авто-установки)
```

Этот скрипт:
1. Проверяет чистоту tree и ветку main
2. Создаёт annotated tag `v2.4.6`
3. Пушит main + теги в `origin`
4. GitHub Actions триггерится на тег → собирает deb → публикует release
5. Ждёт публикации релиза → скачивает deb → ставит через apt

## Локальный git config (уже настроен)

- `user.name = codesyslab`
- `user.email = codesyslab@users.noreply.github.com`
- `push.autoSetupRemote = true` — новые ветки сами пушатся
- `pull.rebase = true` — pull всегда делает rebase

## GitHub Actions

Workflow `.github/workflows/release.yml` автоматически собирает .deb при пуше тега `v*`.
Локально триггернуть: `gh workflow run release.yml -f version=2.4.6`

## Как автоматически держать deb свежим

Выбран вариант C — systemd user timer, уже настроен:

```bash
systemctl --user status codex-app-transfer-update.timer   # статус
systemctl --user list-timers codex-app-transfer-update    # следующий запуск
journalctl --user -u codex-app-transfer-update.service -n 50  # лог сервиса
tail -f ~/.local/log/codex-app-transfer-update.log        # лог скрипта
```

| Файл | Что |
|------|-----|
| `~/.config/systemd/user/codex-app-transfer-update.service` | oneshot сервис, запускает `bin/install-latest.sh` |
| `~/.config/systemd/user/codex-app-transfer-update.timer` | ежедневно в 04:17 ±15 мин, `Persistent=true` (догонит если пропустил) |
| `~/.local/log/codex-app-transfer-update.log` | stdout+stderr скрипта |

Если нужно изменить расписание:
```bash
systemctl --user edit codex-app-transfer-update.timer   # откроет editor с override
```

## История

- 2026-09-04 — форк создан из Cmochance/codex-app-transfer@74d79cb
- 2026-09-04 — установлен upstream remote, локальные git config, bin/ scripts
- 2026-09-04 — systemd user timer настроен (daily auto-update)

## История

- 2026-09-04 — форк создан из Cmochance/codex-app-transfer@74d79cb
- 2026-09-04 — установлен upstream remote, локальные git config, bin/ scripts
