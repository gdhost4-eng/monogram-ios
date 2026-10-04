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
| Режим призрака: отправитель не видит «прослушано / просмотрено» (голосовые, кружки, одноразовые медиа) | ⚪ not tested | `ManagedSynchronizeConsumeMessageContentsOperations`, `ManagedLocalInputActivities` |
| «Прочитано» при ответе и «Прочитать (видно собеседнику)» | ⚪ not tested | `MonogramGhostActions.swift`, `PendingMessageManager`, меню чата в `ChatListUI/ChatContextMenus` |
| Вход призраком с иконки (долгое нажатие), значок режима рядом с «Изм.» | ⚪ not tested | `ApplicationShortcutItem.swift`, `AppDelegate`, `ChatListController`, `NavigationButtonComponent` |
| Сохранение удалённых сообщений (значок корзины у времени) | ⚪ not tested | `MonogramMessageAttributes.swift`, `AccountStateManagementUtils` (`DeleteMessages*`), `StringForMessageTimestampStatus`, `ChatMessageDateAndStatusNode` |
| Сообщения, удалённые таймером автоудаления чата, сохраняются как удалённые | ⚪ not tested | `monogramKeepAutoremovedMessage`, `ManagedAutoremoveMessageOperations` |
| Список удалённых сообщений чата (профиль → «Удалённые сообщения»), переход к сообщению | ⚪ not tested | `MonogramUI/MonogramDeletedMessagesController`, `engine.messages.monogramDeletedMessages`, `PeerInfoProfileItems` |
| У удалённого сообщения нет «Ответить», «Закрепить», «Изменить» и реакций; пересылка отправляет копию | ⚪ not tested | `ChatInterfaceStateContextMenus`, `canAddMessageReactions`, `monogramConvertProtectedForwards` |
| Удалённые сообщения переживают перепроверку истории каналов и перезапись сообщения | ⚪ not tested | `HistoryViewStateValidation`, хук `mergeMessageAttributes` в `SyncCore_StandaloneAccountTransaction` |
| История изменений сообщений (только текст, до 100 версий) | ⚪ not tested | `MonogramEditHistoryMessageAttribute`, `.EditMessage` replay, `MonogramUI/MonogramEditHistoryController` |
| Карандаш вместо слова «изменено» у времени сообщения | ⚪ not tested | `ChatMessageDateAndStatusNode` (`monogramEditedIcon`) |
| Сохранение одноразовых медиа и медиа с таймером (в т.ч. секретные чаты) | ⚪ not tested | `MonogramSelfDestructingMedia.swift`: хук Postbox `SeedConfiguration.preserveExistingMessageMedia`, предзагрузка в `AccountStateManagementUtils`, `ManagedAutoremoveMessageOperations` (секретные чаты) |
| Снятие запрета на копирование, пересылка копией | ⚪ not tested | `MonogramCopyProtection.swift`, `Message.isCopyProtected`, `Peer.isCopyProtectionEnabled`, `enqueueMessages` |
| Скрытие рекламы | ⚪ not tested | `AdMessages.swift`, `AdPeers.swift` |
| ID, примерная дата регистрации, «Копировать ID сообщения» | ⚪ not tested | `MonogramUI/MonogramPeerInfo.swift`, `PeerInfoProfileItems`, `ChatInterfaceStateContextMenus` |
| Локальные заметки в профилях | ⚪ not tested | `TelegramCore/Sources/Monogram/MonogramPeerNotes.swift` (UserDefaults, per account) |
| Поиск в списке чатов находит чаты по тексту заметки | ⚪ not tested | `MonogramKit/MonogramSearch`, `MonogramNotesIndex`, `searchLocalPeers(includeMonogramNotes:)`, `ChatListSearchListPaneNode` |
| Настройки Monogram общие с расширениями (Share, Siri, уведомления) через App Group | ⚪ not tested | `MonogramSettings.defaults`, `MonogramKit/MonogramAppGroup`; без App Group — как раньше |
| Подтверждение отправки стикеров, GIF, голосовых | ⚪ not tested | `Chat/ChatControllerMonogram.swift`, `ChatController` (sendSticker/sendGif), `dismissMediaRecorder` |
| Скрытие историй над списком чатов | ⚪ not tested | `ChatListController` |
| Без лимита на число аккаунтов | ⚪ not tested | `AccountUtils`, экраны выхода и удаления аккаунта |

Всё перечисленное собрано в CI 2026-10-04 (коммит `ccd28780`); на устройстве правки этого дня ещё не проверялись.

Чистая логика слоя (поиск по словам, формат ID, оценка даты регистрации, имя App Group, список запросов режима призрака, индекс заметок) вынесена в `submodules/MonogramKit` и покрыта тестами: `swift test --package-path submodules/MonogramKit`. Они запускаются в CI перед сборкой IPA (36 тестов, проходят).

## Расхождения с Monogram для ПК

Есть на ПК, нет на iOS. «Намеренно» — решение, принятое при переносе 2026-09-23: функция нерациональна на iOS или уже есть в Telegram-iOS.

| Функция ПК | Состояние на iOS |
| --- | --- |
| Поиск внутри списка удалённых сообщений; удалённые находятся поиском по чату | Список есть (профиль чата), поиска по нему нет |
| Удалённые сообщения хранятся в отдельной базе и переживают очистку чата | Хранятся в самой базе чата: «Очистить историю» на устройстве удаляет и их |
| Изменения профилей (имя, юзернейм, аватарка, описание) | Не перенесено намеренно |
| Автозагрузка медиа во всех чатах | Не перенесено намеренно: есть штатные настройки автозагрузки |
| Режим стримера | Не перенесено намеренно |
| Статистика чата | Не перенесено намеренно |
| Скрытие реакций, Premium-разделов, подарков; статичные эмодзи | Не перенесено |
| Оформление, анимации, очистка хранилища Monogram | Не перенесено намеренно: либо есть штатно, либо относится к окну ПК |

## Правило обновления

После каждого существенного изменения обновляются соответствующие строки. `✅ working` разрешён только после успешной сборки и проверки самой функции на устройстве. Все обнаруженные `🔴 broken` имеют приоритет над новыми функциями.
