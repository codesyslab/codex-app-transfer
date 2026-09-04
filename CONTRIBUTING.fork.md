# Contributing to codesyslab/codex-app-transfer

Этот репозиторий — **форк** [Cmochance/codex-app-transfer](https://github.com/Cmochance/codex-app-transfer).
Весь upstream код остаётся под авторством оригинального автора и его лицензией (см. `LICENSE.txt`).
Fork-only изменения (папка `bin/`, документы, скрипты) — под этой же лицензией, если явно не указано иное.

## Когда вносить изменения

| Тип изменения | Куда |
|--------------|------|
| Баг upstream кода, фича полезна всем | PR в [Cmochance/codex-app-transfer](https://github.com/Cmochance/codex-app-transfer) |
| Локальный патч только для форка | Feature-ветка в этом репо, потом merge в `main` |
| Скрипты (`bin/`), документы (`docs/`) | Свободно в `main` (это fork-only) |

## Setup

```bash
# 1. Форк уже склонирован в /home/codesyslab/data/sysprojects/codex-app-transfer
cd /home/codesyslab/data/sysprojects/codex-app-transfer

# 2. Установить pre-push hook (формат + check + test, как в upstream CI)
# upstream рекомендует scripts/install-hooks.sh, но в форке можно вручную:
git config core.hooksPath .githooks

# 3. Убедиться что Rust ≥ 1.85 стоит (upstream требует)
rustc --version   # должно быть 1.85+

# 4. dev пакеты для Tauri (Linux)
sudo apt-get install -y libwebkit2gtk-4.1-dev libgtk-3-dev \
    libayatana-appindicator3-dev librsvg2-dev libsoup-3.0-dev \
    libjavascriptcoregtk-4.1-dev libssl-dev build-essential pkg-config
```

## Внесение изменения в upstream код

```bash
# 1. Создать ветку от свежего upstream/main
bin/sync-upstream.sh --pr my-fix

# 2. Править код
# ... edit crates/foo/src/bar.rs ...

# 3. Локально проверить
cargo fmt --all
cargo check --workspace --all-targets --exclude codex-app-transfer
cargo test  --workspace --no-fail-fast --exclude codex-app-transfer

# 4. Commit
git add crates/foo/src/bar.rs
git commit -m "fix(foo): [MOC-XXX] description"

# 5. Push в форк
git push origin my-fix

# 6. Открыть PR:
#    a) codesyslab/codex-app-transfer:main ← my-fix (для истории форка)
#    b) Cmochance/codex-app-transfer:main ← codesyslab:my-fix (в upstream, если хочешь мержить обратно)
```

## Внесение изменения в fork-only код (bin/, docs/)

```bash
# Просто коммит в main, без ветки — это не upstream код, конфликтов не будет
git add bin/install-latest.sh
git commit -m "chore(fork): improve error message in install-latest.sh"
git push origin main
```

## Pre-push gate (ОБЯЗАТЕЛЬНО для изменений в upstream коде)

Hook `.githooks/pre-push` запускает:

1. `cargo fmt --all -- --check` — форматирование
2. `cargo check --workspace --all-targets --exclude codex-app-transfer` — компиляция
3. `cargo test --workspace --no-fail-fast --exclude codex-app-transfer` — тесты
4. `scripts/check-test-repo-drift.sh` (только на main push) — drift в test repo

Если hook не активен — установи: `git config core.hooksPath .githooks`.

Обход (НЕ рекомендуется): `git push --no-verify`. CI всё равно забанит.

## Стиль коммитов

upstream использует свободный формат с conventional-подобными префиксами:

```
feat(scope): краткое описание
fix(scope): [MOC-XXX] что исправили
chore(scope): что подчистили
docs(scope): что задокументировали
refactor(scope): что упростили
test(scope): что покрыли тестами
```

Fork-only коммиты помечай префиксом `(fork)`:
```
chore(fork): add install-latest.sh helper
docs(fork): document systemd timer workflow
```

## Релиз

Только maintainer форка (codesyslab) делает релиз:

```bash
bin/release.sh 2.4.6             # tag + push + ждать CI + install
bin/release.sh 2.4.6 --no-install # tag + push без авто-установки
```

CI (`.github/workflows/release.yml`) собирает `.deb`, `.AppImage`, `.msi`, `.dmg`,
публикует GitHub release с подписями и sha256.

## Безопасность

- **Не коммить секреты.** API ключи и OAuth токены хранятся в `~/.codex-app-transfer/`
  с правами 0600. Если случайно закоммитил — немедленно rotate ключ + `git filter-repo`
  для удаления из истории.
- **Локальные артефакты сборки** — `target/`, `dist/`, `release/`, `node_modules/`
  в .gitignore. Не форсируй `git add -f` для них.
- **GitHub PAT** — никогда в репо. Используй `gh auth login` или `~/.git-credentials`
  с правами 0600.

## Лицензия

См. `LICENSE.txt` (наследуется от upstream). Fork-only код — под той же лицензией,
если явно не указано иное в файле.
