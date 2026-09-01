# Monogram — безопасность и приватность

Последнее обновление: 2026-09-01

## Чувствительные данные

К критическим данным относятся auth keys, session state, login codes, 2FA/recovery secrets, номера телефонов, приватные сообщения, локальная база, медиа, contacts/location и push payloads.

## Обязательные правила

- Никогда не хранить `api_hash`, signing keys, provisioning profiles или пользовательские credentials в tracked source files.
- Никогда не логировать auth keys, login codes, passwords/recovery data или полные приватные сообщения.
- Не отправлять analytics или содержимое сообщений сторонним сервисам без отдельной необходимости и явного согласия.
- Использовать upstream Keychain/file-protection/session mechanisms; не создавать параллельное небезопасное хранилище.
- Любой diagnostic export должен редактировать phone numbers, tokens, filesystem paths и message contents.
- Не сохранять self-destructing/secret-chat content после удаления и не обходить screenshot/security behavior.
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

- Bookmarks/notes/tags по умолчанию остаются только на устройстве.
- Данные из разных accounts разделяются account record ID и отдельными Postbox boundaries.
- Bookmark хранит `MessageId`, локальную заметку и теги, но не копирует текст или медиа исходного сообщения.
- `MonogramLocalDataPolicy` отклоняет постоянную запись для secret chats, ephemeral-сообщений и copy-protected сообщений; peer notes/tags для secret chats также запрещены.
- Перевод использует system/on-device mechanism в первую очередь; отправка текста во внешний сервис требует информированного opt-in.
- Clipboard actions для ID/text выполняются только явным действием пользователя; sensitive clipboard behavior подлежит отдельному audit.
- Power-user/debug information выключена по умолчанию.

## Logging/redaction

Планируемый Monogram logger должен принимать структурированные metadata и запрещать raw sensitive payloads. Production build не включает verbose message/network body logging. Crash context должен содержать технические категории и identifiers только в минимально необходимом, редактированном виде.

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
11. Удаление orphaned bookmarks/annotations после удаления сообщения, peer или account.

Результаты audit фиксируются здесь с датой, commit и найденными/исправленными рисками. На 2026-09-01 runtime security audit ещё не выполнен.
