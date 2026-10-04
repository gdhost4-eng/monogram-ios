# Monogram — безопасность и приватность

Последнее обновление: 2026-10-04

## Чувствительные данные

К критическим данным относятся auth keys, session state, login codes, 2FA/recovery secrets, номера телефонов, приватные сообщения, локальная база, медиа, contacts/location и push payloads.

## Обязательные правила

- Никогда не хранить `api_hash`, signing keys, provisioning profiles или пользовательские credentials в tracked source files.
- Никогда не логировать auth keys, login codes, passwords/recovery data или полные приватные сообщения.
- Не отправлять analytics или содержимое сообщений сторонним сервисам без отдельной необходимости и явного согласия.
- Использовать upstream Keychain/file-protection/session mechanisms; не создавать параллельное небезопасное хранилище.
- Любой diagnostic export должен редактировать phone numbers, tokens, filesystem paths и message contents.
- Сохранённое вопреки воле отправителя (удалённые сообщения, одноразовые медиа, копии защищённого контента) остаётся только на устройстве: не выгружается, не синхронизируется и не пересылается автоматически. См. «Локальные функции Monogram».
- Не подменять официальный клиент, `api_id`, Premium entitlements или обязательное API-поведение.

## Secrets/configuration

В Git разрешены только example/template values. Реальные значения поступают через локальную ignored configuration или защищённую CI secret store. Перед коммитом проверяются:

- Telegram `api_id` / `api_hash`;
- Apple Team ID и certificate identifiers;
- provisioning profiles;
- push certificates/keys;
- third-party tokens, URLs с credentials и signing artifacts.

Tracked template: `build-system/monogram-development-configuration.example.json`. Реальный `build-system/monogram-development-configuration.json` и `build-system/monogram-signing/` исключены через `.gitignore`. Официальные Telegram credentials из upstream examples не являются конфигурацией Monogram и не должны использоваться.

Перед генерацией проекта `scripts/validate_monogram_configuration.py` проверяет placeholders, формат identifiers и запрещает official Telegram `api_id`/bundle/scheme. Валидатор сообщает только имена некорректных полей и не печатает `api_hash`.

## Локальные функции Monogram

Monogram намеренно делает то, от чего официальный клиент защищает отправителя: оставляет удалённые сообщения, одноразовые медиа и медиа с таймером, снимает запрет на копирование. Это решение продукта, а не побочный эффект, и из него следуют обязательства перед владельцем устройства.

Что и где хранится:

- Удалённые сообщения, история изменений, сохранённые одноразовые медиа — в штатных Postbox и MediaBox аккаунта. На них действует та же защита, что и на остальную переписку этого аккаунта. Отдельного хранилища нет.
- Локальные заметки — в `UserDefaults.standard` (plist в контейнере приложения). Код-пароль приложения и шифрование Postbox на них **не** распространяются, и они попадают в резервную копию устройства. Текст заметок следует считать защищённым слабее, чем переписка.
- Настройки Monogram — в `UserDefaults` общего контейнера App Group, если он есть (иначе тоже в `UserDefaults.standard`). Это только переключатели, содержимого переписки в них нет; общий контейнер нужен, чтобы расширения соблюдали режим призрака.
- В секретных чатах сохраняются только медиа с истёкшим таймером (если включено «Сохранять одноразовые медиа»); удалённые сообщения секретных чатов не сохраняются.

Чего слой Monogram не делает и делать не должен:

- не отправляет сохранённое на сторонние серверы и не добавляет собственных сетевых запросов, кроме штатных запросов Telegram API;
- не сообщает собеседнику больше, чем официальный клиент: режим призрака только убирает исходящие сигналы (прочтение, онлайн, набор текста, просмотр);
- не подменяет серверные права: Premium, платный контент и ограничения сервера остаются как есть. «Пересылка копией» отправляет новое сообщение с тем же текстом и медиа вместо пересылки, которую сервер отклоняет;
- не пишет содержимое сообщений в лог.

Clipboard-действия (ID, текст версии сообщения) выполняются только по явному нажатию.

## Logging/redaction

Отдельного логгера у Monogram нет: используется штатный `Logger.shared`, в который слой Monogram пишет только идентификаторы сообщений и чатов (см. `HistoryValidation`). Содержимое сообщений и сетевые тела в лог не выводятся; временная диагностика удаляется после того, как причина найдена. Crash context должен содержать технические категории и identifiers только в минимально необходимом, редактированном виде.

## Обязательный audit перед release

1. Login, 2FA, recovery и QR flows.
2. Account switch/remove/logout cleanup.
3. Keychain и file protection.
4. Postbox/MediaBox deletion and cache cleanup.
5. Push payloads и notification extensions.
6. App switcher/screenshot privacy там, где это уместно.
7. Clipboard, share extension и temporary files.
8. Crash logs, diagnostics и analytics endpoints.
9. Secret chats и self-destructing media.
10. Low-storage/interrupted-write recovery.
11. Судьба локальных заметок и сохранённых удалённых сообщений после выхода из аккаунта и после удаления чата.

Результаты audit фиксируются здесь с датой, commit и найденными/исправленными рисками. На 2026-10-04 runtime security audit не выполнен.
