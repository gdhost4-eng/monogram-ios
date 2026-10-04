# Monogram — матрица функций

Последнее обновление: 2026-10-04

Легенда: ✅ working · 🟡 partial · 🔴 broken · ⚪ not tested · ➕ custom.

`⚪ not tested` означает, что код есть и собирается в CI, но функция не проходила отдельную проверку на устройстве. Приложение при этом запускается и используется; `✅` ставится только после целевой проверки самой функции.

## Telegram parity

| Категория | Статус | Основа / примечание |
| --- | --- | --- |
| Auth | ⚪ not tested | `AuthorizationUI`, account authorization records, QR/2FA flows upstream |
| Accounts | 🟡 partial | UI-лимит 3/4 снят (`AccountUtils`: `Int.max`); работа с большим числом аккаунтов не проверялась |
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
| Settings | 🟡 partial | Upstream Settings сохранён; добавлен раздел «Monogram»; выбор иконки приложения скрыт |
| Privacy | ⚪ not tested | Privacy and Security controllers and TelegramCore privacy APIs upstream |
| Security | ⚪ not tested | Keychain/Postbox/session implementation requires dedicated audit |
| Premium | ⚪ not tested | Server-side entitlements and Premium UI upstream; bypass is out of scope |
| Payments | ⚪ not tested | Bot payments/Stars upstream |
| Proxy | ⚪ not tested | TelegramCore network proxy and SettingsUI upstream |
| Storage | ⚪ not tested | Postbox, MediaBox and Storage Usage UI upstream |
| Themes | ⚪ not tested | TelegramPresentationData, TelegramUIPreferences, SettingsUI themes |
| Extensions | ⚪ not tested | Share, Notification Service/Content, Widget, Siri Intents, Broadcast Upload, Watch; настройки Monogram расширениям не видны |
| Accessibility | ⚪ not tested | Требуется VoiceOver/Dynamic Type/Reduce Motion audit |
| Localization | 🟡 partial | Upstream-строки и языковые пакеты работают, «Telegram» заменяется на «Monogram» на лету; строки слоя Monogram только на русском |

## Возможности Monogram

Все настраиваются в **Настройки → Monogram**. Устройство слоя — в `ARCHITECTURE.md`.

| Возможность | Статус | Где реализовано |
| --- | --- | --- |
| Режим призрака: без «прочитано», онлайна, «печатает…», прочих действий, просмотров историй | ⚪ not tested | `MonogramSettings.swift` (фильтр в `Network.request`), `ManagedAccountPresence`, `ManagedLocalInputActivities`, `SynchronizePeerReadState` |
| Режим призрака: отправитель не видит «прослушано / просмотрено» (голосовые, кружки, одноразовые медиа) | ⚪ not tested, не собиралось | `ManagedSynchronizeConsumeMessageContentsOperations`, `ManagedLocalInputActivities` |
| «Прочитано» при ответе и «Прочитать (видно собеседнику)» | ⚪ not tested | `MonogramGhostActions.swift`, `PendingMessageManager`, меню чата в `ChatListUI/ChatContextMenus` |
| Вход призраком с иконки (долгое нажатие), значок режима рядом с «Изм.» | ⚪ not tested | `ApplicationShortcutItem.swift`, `AppDelegate`, `ChatListController`, `NavigationButtonComponent` |
| Сохранение удалённых сообщений (значок корзины у времени) | ⚪ not tested | `MonogramMessageAttributes.swift`, `AccountStateManagementUtils` (`DeleteMessages*`), `StringForMessageTimestampStatus`, `ChatMessageDateAndStatusNode` |
| Удалённые сообщения переживают перепроверку истории каналов и перезапись сообщения | ⚪ not tested, не собиралось | `HistoryViewStateValidation`, хук `mergeMessageAttributes` в `SyncCore_StandaloneAccountTransaction` |
| История изменений сообщений (только текст, до 100 версий) | ⚪ not tested | `MonogramEditHistoryMessageAttribute`, `.EditMessage` replay, `MonogramUI/MonogramEditHistoryController` |
| Сохранение одноразовых медиа и медиа с таймером (в т.ч. секретные чаты) | ⚪ not tested | `MonogramSelfDestructingMedia.swift`: хук Postbox `SeedConfiguration.preserveExistingMessageMedia`, предзагрузка в `AccountStateManagementUtils`, `ManagedAutoremoveMessageOperations` (секретные чаты) |
| Снятие запрета на копирование, пересылка копией | ⚪ not tested | `MonogramCopyProtection.swift`, `Message.isCopyProtected`, `Peer.isCopyProtectionEnabled`, `enqueueMessages` |
| Скрытие рекламы | ⚪ not tested | `AdMessages.swift`, `AdPeers.swift` |
| ID, примерная дата регистрации, «Копировать ID сообщения» | ⚪ not tested | `MonogramUI/MonogramPeerInfo.swift`, `PeerInfoProfileItems`, `ChatInterfaceStateContextMenus` |
| Локальные заметки в профилях | ⚪ not tested | `MonogramPeerNotes` (UserDefaults, per account) |
| Подтверждение отправки стикеров, GIF, голосовых | ⚪ not tested | `Chat/ChatControllerMonogram.swift`, `ChatController` (sendSticker/sendGif), `dismissMediaRecorder` |
| Скрытие историй над списком чатов | ⚪ not tested | `ChatListController` |
| Без лимита на число аккаунтов | ⚪ not tested | `AccountUtils`, экраны выхода и удаления аккаунта |

«Не собиралось» — правка от 2026-10-04, сделанная на Windows; пометка снимается после первой успешной сборки.

## Расхождения с Monogram для ПК

Есть на ПК, нет на iOS. «Намеренно» — решение, принятое при переносе 2026-09-23: функция нерациональна на iOS или уже есть в Telegram-iOS.

| Функция ПК | Состояние на iOS |
| --- | --- |
| Сообщения, удалённые таймером автоудаления чата, сохраняются как удалённые | Таймер на устройстве удаляет их по-настоящему (`ManagedAutoremoveMessageOperations`) |
| Список удалённых сообщений чата с поиском; удалённые находятся поиском по чату | Нет: удалённые видны только на своих местах в чате |
| Иконка карандаша у изменённых сообщений | Штатная подпись «изменено» |
| Поиск чатов по тексту локальной заметки | Нет |
| Изменения профилей (имя, юзернейм, аватарка, описание) | Не перенесено намеренно |
| Автозагрузка медиа во всех чатах | Не перенесено намеренно: есть штатные настройки автозагрузки |
| Режим стримера | Не перенесено намеренно |
| Статистика чата | Не перенесено намеренно |
| Скрытие реакций, Premium-разделов, подарков; статичные эмодзи | Не перенесено |
| Оформление, анимации, очистка хранилища Monogram | Не перенесено намеренно: либо есть штатно, либо относится к окну ПК |

## Правило обновления

После каждого существенного изменения обновляются соответствующие строки. `✅ working` разрешён только после успешной сборки и проверки самой функции на устройстве. Все обнаруженные `🔴 broken` имеют приоритет над новыми функциями.
