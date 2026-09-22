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

Старый слой (MonogramCore/MonogramUI: закладки, теги, Advanced Settings, снятие лимита аккаунтов) удалён 2026-09-23. Функции заново перенесены из Monogram для ПК; все настраиваются в **Настройки → Monogram**. Статус — `⚪ not tested`, пока нет сборки и smoke test.

| Возможность | Статус | Где реализовано |
| --- | --- | --- |
| Режим призрака: без «прочитано», онлайна, «печатает…», прочих действий, просмотров историй | ⚪ not tested | `TelegramCore/Sources/Monogram/MonogramSettings.swift` (фильтр в `Network.request`), `ManagedAccountPresence`, `ManagedLocalInputActivities`, `SynchronizePeerReadState` |
| «Прочитано» при ответе и «Прочитать (видно собеседнику)» | ⚪ not tested | `MonogramGhostActions.swift`, `PendingMessageManager`, меню чата в `ChatListUI/ChatContextMenus` |
| Вход призраком с иконки (долгое нажатие) | ⚪ not tested | `ApplicationShortcutItem.swift`, `AppDelegate` |
| Сохранение удалённых сообщений (пометка 🗑) | ⚪ not tested | `MonogramMessageAttributes.swift`, `AccountStateManagementUtils` (`DeleteMessages*`), `StringForMessageTimestampStatus` |
| История изменений сообщений | ⚪ not tested | `MonogramEditHistoryMessageAttribute`, `.EditMessage` replay, `MonogramUI/MonogramEditHistoryController` |
| Снятие запрета на копирование, пересылка копией | ⚪ not tested | `MonogramCopyProtection.swift`, `Message.isCopyProtected`, `Peer.isCopyProtectionEnabled`, `enqueueMessages` |
| Скрытие рекламы | ⚪ not tested | `AdMessages.swift`, `AdPeers.swift` |
| ID, примерная дата регистрации, «Копировать ID сообщения» | ⚪ not tested | `MonogramUI/MonogramPeerInfo.swift`, `PeerInfoProfileItems`, `ChatInterfaceStateContextMenus` |
| Локальные заметки в профилях | ⚪ not tested | `MonogramPeerNotes` (UserDefaults, per account) |
| Подтверждение отправки стикеров, GIF, голосовых | ⚪ not tested | `Chat/ChatControllerMonogram.swift`, `ChatController` (sendSticker/sendGif), `dismissMediaRecorder` |
| Скрытие историй над списком чатов | ⚪ not tested | `ChatListController` |

Не перенесено (нерационально на iOS или уже есть в Telegram-iOS): режим стримера, автозагрузка медиа везде, история изменений профилей, статистика чата, оформление (скругление пузырей есть штатно), очистка файлов.

## Правило обновления

После каждого существенного изменения обновляются соответствующие строки. `✅ working` разрешён только после успешной сборки и релевантного smoke/regression test. Все обнаруженные `🔴 broken` имеют приоритет над custom-функциями.
