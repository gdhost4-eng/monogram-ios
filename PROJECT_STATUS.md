# Monogram — состояние проекта

Последнее обновление: 2026-09-01

## Текущая фаза

Phase 0 — технический аудит официальной основы Telegram-iOS — завершён на уровне исходного дерева. Начаты Phase 2 и Phase 4: безопасная конфигурация Monogram и изолированный Extension Layer. Baseline build из Phase 1 ожидает совместимый macOS/Xcode-хост.

## Базовая версия

- Upstream: `https://github.com/TelegramMessenger/Telegram-iOS.git`
- Ветка: `master`
- Commit: `6ad963e5b62d354da79040f388ae2b9132fb17b8`
- Версия приложения: `12.9.2`
- Требуемый Xcode: `26.2`
- Требуемый Bazel: `8.4.2`
- Требуемый macOS: `26`
- Checkout: shallow clone; все 13 зафиксированных submodules инициализированы.

## Что подготовлено

- Официальный исходный код размещён в рабочем репозитории без переписывания архитектуры.
- Git настроен на длинные пути, необходимые для upstream assets на Windows.
- Официальный remote переименован в `upstream`.
- Рабочее дерево после bootstrap было чистым.
- Найдены основные архитектурные точки account/session, Postbox, chat list, chat controller, settings, media, notifications, calls и extensions.
- Найдены пять UI-проверок и две общие константы официального лимита аккаунтов 3/4. Нижележащие `AccountManager` и `SharedAccountContextImpl` уже используют динамические коллекции аккаунтов.
- Созданы отдельные Bazel-модули `MonogramCore` и `MonogramUI`.
- Добавлены versioned settings schema, typed feature registry, global/per-account persistence и experimental flags.
- Advanced Settings подключён к существующему Settings UI.
- Все пять найденных UI gate лимита аккаунтов 3/4 заменены единой политикой без application-level maximum; константы 3/4 удалены из `AccountUtils`.
- Добавлены unit tests для registry, migrations, persistence model и account policy; они ещё не запущены из-за отсутствия iOS toolchain.
- Добавлен безопасный configuration example, реальные credentials/signing paths занесены в `.gitignore`, display name изменён на Monogram.
- Добавлен account-local слой данных для message bookmarks и peer notes/tags на штатном Postbox `OrderedItemList`: наблюдаемые списки, upsert/remove, поиск, нормализация и отсутствие искусственного лимита записей.
- Bookmark-модель сохраняет ссылку `MessageId`, заметку и теги, но не дублирует текст/медиа приватного сообщения. Запись secret-chat, ephemeral и copy-protected references запрещена общей privacy policy.
- Message context menu подключён к feature flag и privacy policy: для одного допустимого сообщения доступно добавление/удаление локальной закладки.
- Добавлен экран account-local списка закладок с реактивным счётчиком в Advanced Settings и переходом к исходному сообщению через штатную навигацию.
- Добавлен редактор локальной заметки и тегов закладки: нормализация разделителей, сохранение через Postbox transaction, открытие исходного сообщения и подтверждаемое destructive-удаление.
- Экран закладок получил реактивный локальный поиск по заметкам и тегам, включая запросы вида `#tag`, с отдельным empty/no-results состоянием.
- Portable source/configuration checks проверены локально: 12/12 Python unit tests проходят, example template проходит structural validation.

## Что пока не проверено

- Генерация Xcode-проекта.
- Компиляция simulator/device targets.
- Запуск и runtime smoke tests.
- Авторизация реального Telegram-аккаунта, APNs и signing.
- Полный parity audit относительно собранного официального клиента.

## Ограничения среды

Текущий рабочий хост — Windows. На нём отсутствуют Xcode и iOS SDK, поэтому он пригоден для аудита, подготовки архитектуры, Swift-кода без сборки и документации, но не для достоверной iOS-компиляции. Baseline build должен быть выполнен на macOS 26 с Xcode 26.2. Работа, не требующая Xcode, продолжается.

Для device build позднее потребуются собственные `api_id`, `api_hash`, Bundle Identifier, Apple Team ID и provisioning profiles. До их получения используются только шаблоны без секретов.

## Текущая задача

1. Проверить `MonogramCore`, `MonogramUI` и generated localization build на macOS/Xcode 26.2.
2. Подключить локальные peer notes/tags к профилям пользователей, групп и каналов.
3. Подключить редактор peer notes/tags и локальные результаты к поиску.
4. Провести runtime stress test account switcher для 4+/10+ accounts.

## Следующие задачи

1. Выполнить baseline build на совместимом macOS-хосте.
2. Запустить `//submodules/MonogramCore:MonogramCoreTests` и `//Tests/AllTests:AllTests`.
3. Исправить найденные compile/test issues до начала широкой feature-разработки.
4. Добавить UI и runtime tests для готовой account-aware schema bookmarks/notes/tags.
5. Реализовать Advanced Settings search entry и остальные scopes, включая per-chat.
6. Подготовить самостоятельные app icons Monogram.

## Известные проблемы

- `origin` не настроен: URL репозитория Monogram ещё не предоставлен.
- Build status неизвестен до появления совместимого macOS/Xcode-хоста.
- Любые функциональные статусы в `FEATURE_MATRIX.md` остаются `⚪ not tested` до реальной проверки.
