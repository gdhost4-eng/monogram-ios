# Monogram — архитектура

Последнее обновление: 2026-09-01

## Принцип

Telegram-iOS остаётся фундаментом. Monogram добавляет типизированный custom layer и минимальные интеграционные патчи; он не дублирует MTProto, Postbox, message renderer или существующие Telegram flows.

## Карта upstream

| Область | Основные компоненты | Роль |
| --- | --- | --- |
| App/targets | `Telegram/BUILD`, `Telegram/Telegram-iOS` | Главный app target, plist/resources, app lifecycle |
| Networking | `submodules/MtProtoKit`, `TelegramCore/Sources/Network` | MTProto transport, network orchestration, proxy |
| API/domain | `submodules/TelegramApi`, `TelegramCore` | Telegram API model и business/state operations |
| Accounts | `TelegramCore/Sources/AccountManager`, `TelegramCore/Sources/Account`, `TelegramUI/Sources/SharedAccountContext.swift` | Account records, authorization, per-account Postbox/network/context |
| Local database | `submodules/Postbox` | Messages, peers, preferences, views, migrations and transactions |
| Media/cache | `Postbox/MediaBox*`, TelegramCore media resources, gallery/player UI | Fetch/upload/cache/playback lifecycle |
| Chat list | `submodules/ChatListUI` | Chat list controller, filters, search container and list node |
| Chat UI | `TelegramUI/Sources/ChatController.swift`, `ChatControllerNode.swift`, `TelegramUI/Sources/Chat` | Chat state, history rendering, input, actions and navigation |
| Settings | `submodules/SettingsUI`, `TelegramCore/Sources/Settings`, shared/account preferences | Settings screens and persistence |
| Notifications | `Telegram/NotificationService`, `Telegram/NotificationContent`, TelegramCore notification settings | Push processing and presentation extensions |
| Calls | `submodules/TelegramCallsUI`, `submodules/TgVoipWebrtc` | Voice/video/group call UI and media engine |
| Stories | Postbox story tables, TelegramCore state, TelegramUI story components | Story storage, sync and presentation |
| Themes/localization | `TelegramPresentationData`, `TelegramUIPreferences`, generated presentation strings | Themes, wallpaper, fonts and localized UI |
| iOS extensions | Share, Notification Service/Content, Widget, Siri Intents, Broadcast Upload, Watch | System integration targets |

## Account/session architecture

`AccountManager` хранит `AccountRecord` и current/auth records. Каждый авторизованный `Account` создаётся через `accountWithId` и получает собственные Postbox, MediaBox, network/session state и preferences. `SharedAccountContextImpl` наблюдает records, динамически добавляет/удаляет contexts и сортирует их через `AccountSortOrderAttribute`.

Технического фиксированного массива на 3/4 аккаунта в manager/context не найдено. Ограничение находилось в пяти UI paths и двух константах `AccountUtils`:

- `SettingsUI/Sources/LogoutOptionsController.swift`
- `SettingsUI/Sources/DeleteAccountOptionsController.swift`
- `TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoScreenSettingsActions.swift`
- `SettingsUI/Sources/Search/SettingsSearchableItems.swift`
- `AccountUtils/Sources/AccountUtils.swift`

Эти gate удалены и заменены `MonogramAccountPolicy`; изменение должно быть подтверждено нагрузочными тестами. Оно не меняет Telegram Premium entitlements или server-side limits, не связанные с локальным числом подключённых accounts.

## Custom layer

### `MonogramCore` — создан

Низкоуровневый модуль без UI:

- schema/version migrations (schema v1);
- global/per-account settings models и отдельные persistence keys;
- feature and experimental flags с typed registry;
- local bookmarks/notes/tags repositories;
- privacy-safe logging/redaction;
- account-add policy без фиксированного application maximum.

Зависимости должны быть минимальными: Foundation, SwiftSignalKit, Postbox и TelegramCore только там, где это необходимо. Модуль не должен зависеть от TelegramUI.

### `MonogramUI` — создан

UI-интеграция:

- Advanced Settings с global/current-account/experimental sections;
- appearance controls;
- chat list/search additions;
- context-menu and message actions;
- local bookmark/note/tag screens;
- power-user/debug presentation.

Он может зависеть от `MonogramCore`, Telegram presentation/UI abstractions и SettingsUI, но не должен создавать обратных зависимостей.

## Правила persistence

- Global settings: account-manager shared data, custom key `0x4d4f4e01`.
- Per-account settings: account-specific preferences/Postbox с отдельной таблицей и тем же namespaced key value.
- Per-chat settings: account Postbox keyed by `PeerId`.
- Message bookmarks: отдельная Postbox `OrderedItemList` collection `0x4d4f4201`; запись содержит только `MessageId`, локальную заметку, нормализованные теги и `Int64` timestamps, без копии текста/медиа сообщения.
- Peer notes/tags: отдельная Postbox `OrderedItemList` collection `0x4d4f4202`, keyed by `PeerId`, с наблюдаемым списком, upsert/remove и локальным поиском.
- Обе коллекции не имеют искусственного tail limit и физически изолированы Postbox текущего account.
- Secret-chat, ephemeral и copy-protected message references запрещены `MonogramLocalDataPolicy`; peer annotations для secret chats также запрещены.
- Secret/self-destructing content: не копировать в custom persistence вопреки Telegram semantics.
- Любой новый ключ имеет default value и безопасно игнорирует неизвестные поля.

## Extension points

1. `Telegram/BUILD` — подключение Monogram targets к app/UI graph.
2. Settings root/search — одна точка входа в Advanced Settings.
3. Account-add actions — общий policy helper вместо трёх копий gate logic.
4. Chat context menu — добавление custom actions через локальный registry.
5. Presentation data/preferences — appearance overrides поверх upstream defaults.
6. Postbox/account manager — только versioned local data adapters; не менять core message tables без необходимости.

Bookmark action в message context menu читает account-scoped feature flag и снимок соответствующей записи. Для одного допустимого сообщения он выполняет локальный upsert/remove; secret, ephemeral и copy-protected сообщения не получают эту action.

Bookmarks list и editor находятся в `MonogramUI`. Editor пишет note/tags только через `MonogramCore`, повторно использует единый parser/normalizer тегов и требует стандартного destructive confirmation перед удалением локальных данных.

## Failure isolation

Custom settings и локальные функции должны возвращать defaults при повреждённых/неизвестных данных. Ошибка Monogram-функции не должна блокировать авторизацию, синхронизацию, отправку/приём сообщений или открытие основного Telegram UI.
