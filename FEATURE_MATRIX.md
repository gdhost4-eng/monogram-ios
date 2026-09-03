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
| Вкладка Monogram | 🟡 partial | Пустые feature-флаги удалены; экран показывает только подключённые функции, build test ожидается |
| Ghost Mode | 🟡 partial | Read receipts, typing/sticker/recording activity, таймер, ручное прочтение и исключения чатов подключены; build/runtime test ожидается |
| Сохранение удалённых сообщений | 🟡 partial | Перед удалением создаётся локальный пузырь в отдельном namespace; сохраняются только уже загруженные файлы/изображения; sensitive content исключён |
| История редактирования | 🟡 partial | До 50 прошлых текстовых версий на сообщение, просмотр и очистка из context menu; build/runtime test ожидается |
| Feature flags / experimental flags | 🟡 partial | Typed registry, schema v2, safe defaults/migration и source tests добавлены; iOS build ожидается |
| Нет фиксированного лимита аккаунтов | 🟡 partial | Пять UI gate и обе константы 3/4 удалены, policy = no maximum; нужны build и тесты 4+/10+ accounts |
| Reorder/account switcher improvements | ➕ custom — planned | Сохранить `AccountSortOrderAttribute`, добавить UX audit |
| Local bookmarks | 🟡 partial | Repository, privacy gates, context action, list, reactive note/tag search, editor, open-message и confirmed delete готовы; iOS build/tests ожидаются |
| Local notes | 🟡 partial | Редактор подключён к профилю, добавлены список и локальный поиск; iOS tests ожидаются |
| Custom tags | 🟡 partial | Нормализация, редактор и локальный поиск bookmarks/peers подключены; iOS tests ожидаются |
| Локальные закрепления | 🟡 partial | Context action использует локальные bookmarks с системным тегом; build/runtime test ожидается |
| Power-user identifiers | 🟡 partial | Копирование peer/message/namespace ID добавлено в context menu и выключено по умолчанию |
| Подтверждение записи | 🟡 partial | Голосовые и видеосообщения переводятся в preview до отправки; build/runtime test ожидается |
| Автоклавиатура | 🟡 partial | Автоматически запланированный focus подавляется, ручной focus сохранён; build/runtime test ожидается |
| Проверка активного аккаунта | 🟡 partial | Перед отправкой показывается имя текущего аккаунта и требуется подтверждение; build/runtime test ожидается |
| Блокировка автопрокрутки | 🟡 partial | При входящей вставке viewport фиксируется через stationary range; ручная навигация и исходящие сообщения не затрагиваются |

## Правило обновления

После каждого существенного изменения обновляются соответствующие строки. `✅ working` разрешён только после успешной сборки и релевантного smoke/regression test. Все обнаруженные `🔴 broken` имеют приоритет над custom-функциями.
