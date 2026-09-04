# AGENTS.fork.md — правила для AI агентов в этом репозитории (форк)

> Этот файл читается AI-ассистентами (OpenCode, Claude Code, Codex CLI и др.) при работе
> с проектом. Если ты AI и читаешь это — следуй инструкциям ниже.
>
> **Почему `AGENTS.fork.md`, а не `AGENTS.md`?** Upstream исключил `AGENTS.md` в
> `.gitignore` (строка 111) — у автора свой локальный AGENTS.md с личными правилами.
> Чтобы наши fork-only правила не конфликтовали при sync с upstream, используем
> суффикс `.fork`. Файл читается AI агентами так же, как и стандартный `AGENTS.md`.
>
> **Для maintainer'а форка (codesyslab):** личная шпаргалка — в `bin/RULES.md`.
> Документация для контрибьюторов — в `CONTRIBUTING.fork.md`.
>
> **Почему `AGENTS.fork.md`, а не `AGENTS.md`?** Upstream исключил `AGENTS.md` в
> `.gitignore` (строка 111) — у автора свой локальный AGENTS.md с личными правилами.
> Чтобы наши fork-only правила не конфликтовали при sync с upstream, используем
> суффикс `.fork`. Файл читается AI агентами так же, как и стандартный `AGENTS.md`.

## Контекст

Это **форк** upstream проекта [Cmochance/codex-app-transfer](https://github.com/Cmochance/codex-app-transfer).

| | |
|---|---|
| Upstream | `https://github.com/Cmochance/codex-app-transfer.git` |
| Этот форк (origin) | `https://github.com/codesyslab/codex-app-transfer.git` |
| Maintainer форка | codesyslab |
| Что делает | Десктопный шлюз Responses API → Chat Completions для Kimi/DeepSeek/GLM/etc |
| Стек | Rust (Tauri 2.x), JS/TS frontend, SQLite, axum |

**Главное правило:** этот репозиторий — форк. Содержит ~99% upstream кода + fork-only патчи.
Любые правки upstream кода нужно либо мержить обратно в upstream через PR, либо держать
в изолированных ветках — не коммитить напрямую в `main` без явной команды пользователя.

## Структура репозитория

```
.
├── crates/                          # ← upstream код (Rust workspace)
│   ├── adapters/                   # Provider протокол адаптеры
│   ├── codex_integration/          # Codex CLI конфиг интеграция
│   ├── conversation_export/        # JSONL rollout экспорт
│   ├── gemini_oauth/               # Gemini OAuth flow
│   └── ...                         # ещё ~15 крейтов
├── frontend/                        # ← upstream код (JS/TS)
├── src-tauri/                       # ← upstream Tauri shell
├── .githooks/pre-push              # ← upstream gate (cargo fmt/check/test)
├── bin/                             # ← fork-only: наши скрипты
│   ├── install-latest.sh           # скачать .deb из релизов форка + поставить
│   ├── sync-upstream.sh            # fetch/ff-only/rebase/PR из upstream
│   ├── release.sh                  # полный цикл: tag → CI → install
│   └── build-local.sh              # локальная cargo tauri сборка
├── docs/                            # ← force-added, в .gitignore upstream'а
│   └── WORKFLOW.md                 # документация workflow для людей
├── Cargo.toml                       # workspace root
├── Makefile                         # урезанный (только mac-app и clean)
└── .github/workflows/release.yml   # GitHub Actions: tag → .deb/AppImage/.msi
```

## Что НЕЛЬЗЯ делать без явной команды

1. **Не коммитить в `main` изменения upstream кода** (`crates/`, `src-tauri/`, `frontend/`)
   без явного запроса пользователя. Любые такие изменения — только в feature-ветке.
2. **Не удалять `bin/`** — это fork-only, удаление сломает локальный workflow пользователя.
3. **Не трогать `.githooks/pre-push`** — это upstream gate, изменения повлияют на чужой workflow.
4. **Не коммитить `docs/` обычным `git add`** — папка в .gitignore upstream'а.
   Если очень надо — `git add -f docs/...`. См. `docs/WORKFLOW.md` для истории.
5. **Не коммитить артефакты сборки** — `target/`, `dist/`, `release/`, `node_modules/`.
   Уже в .gitignore, но проверяй `git status` перед коммитом.
6. **Не пушить секреты** — API ключи и OAuth токены живут в `~/.codex-app-transfer/`
   с правами 0600, не в репо. См. ниже секцию про секреты.

## Что МОЖНО делать свободно

- Править `bin/*.sh` — это fork-only, обновляется по желанию maintainer'а форка.
- Править `docs/*.md` (с `git add -f`) — локальные заметки maintainer'а.
- Создавать feature-ветки от upstream/main для PR обратно в upstream.
- Править `Cargo.toml` workspace declarations ТОЛЬКО при добавлении нового `bin/*.sh`
  скрипта как workspace member, и то — лучше через PR в upstream, чтобы не было
  конфликтов при sync.

## Команды

### Сборка (локальная, без CI)

```bash
# первый раз — занимает 10-20 мин
bin/build-local.sh                  # release build

# в CI
bin/release.sh 2.4.6                # tag → push → CI → install
```

### Тестирование

```bash
# pre-push gate (то же что upstream CI rust-fast-check)
cargo fmt --all -- --check
cargo check --workspace --all-targets --exclude codex-app-transfer
cargo test --workspace --no-fail-fast --exclude codex-app-transfer

# полный (включает src-tauri, требует webkit2gtk-dev)
cargo test --workspace

# xtask fixtures drift (редко, при изменении registry fixtures)
cargo run -p xtask -- gen-fixtures   # потом git diff fixtures/
```

### Линт и форматирование

```bash
cargo fmt --all                      # авто-формат
cargo clippy --workspace --all-targets -- -D warnings
```

### Sync с upstream

```bash
bin/sync-upstream.sh                # fetch + отчёт
bin/sync-upstream.sh --rebase       # rebase main на upstream
bin/sync-upstream.sh --pr <branch>   # новая ветка от upstream для PR
```

### Установка/обновление deb

```bash
bin/install-latest.sh               # скачать .deb из релизов форка + поставить
bin/install-latest.sh v2.4.5        # конкретная версия
bin/install-latest.sh --check       # только показать что есть нового

# systemd timer для авто-обновления (ежедневно 04:17 ±15 мин)
systemctl --user status codex-app-transfer-update.timer
journalctl --user -u codex-app-transfer-update.service -n 50
tail -f ~/.local/log/codex-app-transfer-update.log
```

## Git workflow

| Действие | Команда |
|----------|---------|
| Push в форк | `git push origin <branch>` (autoSetupRemote=true, новые ветки автоматически) |
| Pull из форка | `git pull --rebase` (pull.rebase=true в локальном git config) |
| Fetch upstream | `git fetch upstream --tags --prune` (= `bin/sync-upstream.sh`) |
| Создать PR | `bin/sync-upstream.sh --pr <branch>`, потом `git push origin <branch>` |
| Squash-merge | upstream требует branch up-to-date — сначала `git rebase upstream/main` |
| Тег + релиз | `bin/release.sh 2.4.6` (проверяет clean tree, на main, создаёт tag, пушит) |

### Conventional commits — НЕ обязательно

upstream использует свободный формат. Принятые префиксы:
- `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`
- Для значимых — ссылка на MOC/issue: `feat(grok): [MOC-319] grok-4.5 модель`

## Секреты и приватные данные

**Категорически не коммитить:**

| Что | Где должно быть |
|-----|-----------------|
| Upstream API ключи (Kimi/DeepSeek/GLM/...) | `~/.codex-app-transfer/config.json` (0600) |
| OAuth токены | `~/.codex-app-transfer/*.json` (0600) |
| Codex auth.json | `~/.codex/auth.json` (0600) |
| GitHub PAT | `~/.git-credentials` (0600), или `gh auth login` |
| MCP credentials | `~/.codex/.credentials.json` (0600), зеркало в `~/.codex-app-transfer/mcp-credentials.json` |

**Перед коммитом всегда:**

```bash
git status --short
git diff --cached
```

Ищи: `.env`, `*.key`, `*.pem`, `config.json` с полями `apiKey`/`token`/`secret`.

## Что полезно знать AI

1. **Язык комментариев в коде:** китайский (中文). Документация для пользователя в
   `docs/WORKFLOW.md` и `bin/*.sh` — английский + комментарии на русском где есть.
2. **MOC-XXX** — внутренние тикеты автора, ссылка в коммитах = трейс до требования.
   В fork-only коммитах префикс `chore(fork):` или `docs(fork):`.
3. **Stage numbers** — внутренний roadmap (Stage 2, Stage 2.5, Stage 3). Не путай
   с версиями релиза (v2.4.x).
4. **Тесты на сеть** — отмечены `#[ignore]` или `#[cfg(feature = "net-tests")]`.
   По умолчанию НЕ запускаются. CI гоняет их отдельно.
5. **Tauri bundle names** — `Codex-App-Transfer-v<X>-Linux-x86_64.deb` —
   именно так генерирует release.yml, скрипт `install-latest.sh` ждёт этот формат.
6. **Локальная машина пользователя** — это dev workstation, а не CI. Долгие команды
   (cargo build всего workspace) занимают 10-20 мин, не предлагай запускать без
   явной просьбы.
