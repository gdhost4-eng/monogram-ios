# Monogram — матрица функций

Последнее обновление: 2026-09-01

Легенда: ✅ working · 🟡 partial · 🔴 broken · ⚪ not tested · ➕ custom.

Статус `⚪ not tested` означает, что исходная реализация присутствует в текущем upstream, но ещё не подтверждена сборкой и smoke test Monogram.

## Telegram parity

| Категория | Статус | Основа / примечание |
| --- | --- | --- |
| Auth | ⚪ not tested | `AuthorizationUI`, account authorization records, QR/2FA flows upstream |
| Accounts | 🟡 partial | Dynamic backend сохранён; пять UI gate и константы 3/4 удалены, build/runtime stress test не выполнен |
| Chats | ⚪ not tested | `ChatListUI`, `TelegramUI/ChatController` |
| Messages | ⚪ not tested | Postbox message model, TelegramCore pending/state pipeline, upstream renderer |
| Groups | ⚪ not tested | TelegramCore/TelegramUI upstream |
| Channels | ⚪ not tested | TelegramCore/TelegramUI upstream |
| Topics | ⚪ not tested | Chat locations, thread tables and forum UI upstream |
| Bots | ⚪ not tested | TelegramCore bot APIs and TelegramUI flows upstream |
| Mini Apps | ⚪ not tested | WebApp/WebUI upstream |
| Media | ⚪ not tested | Postbox `MediaBox`, gallery/player/upload pipelines upstream |
| Stories | ⚪ not tested | Postbox story tables, TelegramCore state, TelegramUI story components |
| Calls | ⚪ not tested | `TelegramCallsUI`, `TgVoipWebrtc`, CallKit integration upstream |
| Search | ⚪ not tested | Chat list/global/chat search upstream |
| Contacts | ⚪ not tested | TelegramCore contacts and ContactListUI upstream |
| Notifications | ⚪ not tested | Notification Service/Content extensions and notification settings upstream |
| Settings | 🟡 partial | Upstream Settings сохранён; Advanced Settings и persistence добавлены, build не выполнен |
| Privacy | ⚪ not tested | Privacy and Security controllers and TelegramCore privacy APIs upstream |
| Security | ⚪ not tested | Keychain/Postbox/session implementation requires dedicated audit |
| Premium | ⚪ not tested | Server-side entitlements and Premium UI upstream; bypass is out of scope |
| Payments | ⚪ not tested | Bot payments/Stars upstream |
| Proxy | ⚪ not tested | TelegramCore network proxy and SettingsUI upstream |
| Storage | ⚪ not tested | Postbox, MediaBox and Storage Usage UI upstream |
| Themes | ⚪ not tested | TelegramPresentationData, TelegramUIPreferences, SettingsUI themes |
| Extensions | ⚪ not tested | Share, Notification Service/Content, Widget, Siri Intents, Broadcast Upload, Watch |
| Accessibility | ⚪ not tested | Требуется VoiceOver/Dynamic Type/Reduce Motion audit |
| Localization | ⚪ not tested | Upstream string generation и `.lproj`; язык Monogram ещё не добавлен |

## Возможности Monogram

| Возможность | Статус | Следующая проверяемая точка |
| --- | --- | --- |
| Изолированный Extension Layer | 🟡 partial | `MonogramCore` и `MonogramUI` добавлены; build verification ожидается |
| Advanced Settings | 🟡 partial | Экран подключён, global/per-account persistence работает по коду; per-chat scope и build test ожидаются |
| Feature flags / experimental flags | 🟡 partial | Typed registry, schema v1, safe defaults/migration и tests добавлены, но не запущены |
| Нет фиксированного лимита аккаунтов | 🟡 partial | Пять UI gate и обе константы 3/4 удалены, policy = no maximum; нужны build и тесты 4+/10+ accounts |
| Reorder/account switcher improvements | ➕ custom — planned | Сохранить `AccountSortOrderAttribute`, добавить UX audit |
| Local bookmarks | 🟡 partial | Repository, privacy gates, context action, list, reactive note/tag search, editor, open-message и confirmed delete готовы; iOS build/tests ожидаются |
| Local notes | 🟡 partial | Peer annotation repository и message bookmark notes готовы; editor UI и iOS tests ожидаются |
| Custom tags | 🟡 partial | Общая нормализация и локальная фильтрация bookmarks/peers готовы; chat/search UI ожидается |
| Appearance enhancements | ➕ custom — planned | Расширить presentation preferences без поломки themes |
| Search enhancements | ➕ custom — planned | Объединить локальные результаты с server search |
| Translation controls | ➕ custom — planned | On-device/system-first, явное согласие для внешних сервисов |
| Power-user identifiers | ➕ custom — planned | По умолчанию выключено; безопасная выдача ID/debug info |
| Media enhancements | ➕ custom — planned | Download metadata, batch actions, autoplay/cache controls |
| Extended offline/storage | ➕ custom — planned | Cache policies, stats, low-storage и reconnect tests |
| Security redaction | ➕ custom — planned | Запрет sensitive logs и regression tests |

## Правило обновления

После каждого существенного изменения обновляются соответствующие строки. `✅ working` разрешён только после успешной сборки и релевантного smoke/regression test. Все обнаруженные `🔴 broken` имеют приоритет над custom-функциями.
