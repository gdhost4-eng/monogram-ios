# Changelog

Все заметные изменения Monogram документируются в этом файле. Проект следует непрерывному changelog до появления формальной release-схемы.

## Unreleased

### Added

- Подготовлен официальный Telegram-iOS 12.9.2 на commit `6ad963e5b62d354da79040f388ae2b9132fb17b8` со всеми зафиксированными submodules.
- Созданы `PROJECT_STATUS.md`, `FEATURE_MATRIX.md`, `UPSTREAM.md`, `ARCHITECTURE.md` и `SECURITY.md` как долговременная память проекта.
- Зафиксирована исходная карта Telegram app/framework/extension targets.
- Зафиксирована архитектура dynamic account records и расположение трёх UI gates лимита 3/4 аккаунта.
- Добавлен `MonogramCore`: typed feature registry, settings schema v1, migrations, experimental flags, global/per-account persistence и no-limit account policy.
- Добавлен `MonogramUI` с экраном Advanced Settings и отдельными global/current-account/experimental секциями.
- Добавлены MonogramCore unit tests и включение в общий Bazel test suite.
- Добавлены безопасный configuration example и инструкция `MONOGRAM_CONFIGURATION.md`.
- Добавлен fail-fast validator Monogram-конфигурации и portable unit tests без вывода секретов.
- Добавлен portable regression test, запрещающий повторное появление account-limit gate 3/4 в известных add-account paths.
- Добавлены account-local Postbox repositories для message bookmarks и peer notes/tags: наблюдение, upsert/remove, поиск и нормализация тегов без фиксированного лимита.
- Добавлена privacy policy, запрещающая сохранять secret-chat, ephemeral и copy-protected message references и secret-chat peer annotations.
- Добавлены Swift model/policy tests и portable source invariants для custom collection IDs, reference-only bookmark model и обязательных privacy gates.
- В message context menu добавлено feature-gated действие добавления/удаления локальной закладки с повторной проверкой privacy policy перед записью.
- В Advanced Settings добавлены реактивный счётчик и account-local экран закладок; выбор записи открывает исходное сообщение штатной навигацией.
- Добавлен редактор bookmark note/tags с единым parser разделителей, сохранением, действием открытия сообщения и подтверждаемым удалением локальной записи.
- Экран bookmarks получил реактивный account-local поиск по note/tag, поддержку `#tag`-запросов и отдельное состояние отсутствия результатов.

### Changed

- Официальный Git remote переименован из `origin` в `upstream`.
- Для локального checkout включён `core.longpaths`, необходимый для upstream assets на Windows.
- Пользовательский display name изменён с Telegram на Monogram; внутренние target names сохранены для совместимости с upstream.
- Удалены все пять найденных UI gate и обе константы 3/4 подключённых аккаунта; server-side Premium semantics не изменялись.

### Known limitations

- Baseline build и runtime parity ещё не проверены: текущий хост Windows не предоставляет Xcode/iOS SDK.
- `origin` для репозитория Monogram ещё не настроен.
- Собственные API/signing credentials отсутствуют; реальные secrets не добавлялись.
