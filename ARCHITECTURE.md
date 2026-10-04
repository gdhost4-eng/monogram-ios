# Monogram — архитектура

Последнее обновление: 2026-10-04

## Принцип

Telegram-iOS остаётся фундаментом. Monogram добавляет небольшой собственный слой и точечные правки в файлах upstream; он не дублирует MTProto, Postbox, отрисовку сообщений или существующие экраны Telegram. Чем меньше строк изменено в файлах upstream, тем дешевле следующее слияние.

Функции повторяют Monogram для ПК (`monogram-pc/tdesktop/Telegram/SourceFiles/monogram`). Если поведение на iOS и на ПК расходится без причины, эталон — ПК-версия.

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

## Аккаунты

`AccountManager` хранит `AccountRecord`, каждый авторизованный `Account` получает собственные Postbox, MediaBox, сеть и настройки; `SharedAccountContextImpl` добавляет и удаляет контексты динамически. Фиксированного массива на 3/4 аккаунта в ядре нет — лимит жил только в UI. Он снят: `maximumNumberOfAccounts` и `maximumPremiumNumberOfAccounts` в `AccountUtils` равны `Int.max`, а экраны выхода, удаления аккаунта и настроек читают эти константы вместо чисел 3 и 4. Серверные ограничения и Premium это не меняет.

## Слой Monogram

### Чистая логика: `submodules/MonogramKit/`

Модуль без зависимостей, кроме Foundation. В него вынесено всё, что можно проверить без приложения; от него зависят `TelegramCore` и `MonogramUI`.

| Файл | Что делает |
| --- | --- |
| `MonogramSearch.swift` | Сопоставление слов для локального поиска, те же правила, что в `monogram_search` на ПК |
| `MonogramNotesIndex.swift` | Заметки одного аккаунта в памяти, поиск по ним, ключи `UserDefaults` |
| `MonogramPeerIdentity.swift` | ID в формате ботов, оценка даты регистрации по ID |
| `MonogramAppGroup.swift` | Имя App Group по bundle id приложения или расширения |
| `MonogramGhostRequests.swift` | Какие запросы режим призрака гасит по имени функции |

Тесты лежат рядом (`Tests/MonogramKitTests`) и запускаются без симулятора: `swift test --package-path submodules/MonogramKit`. Workflow сборки выполняет их перед IPA; упавший тест помечает запуск, но сборку не останавливает. Для Bazel есть цель `//submodules/MonogramKit:MonogramKitTests`.

Новую логику, которой не нужны Postbox, сеть и UIKit, стоит писать здесь, а в `TelegramCore` и `MonogramUI` оставлять обёртку.

### Ядро: `submodules/TelegramCore/Sources/Monogram/`

Часть модуля `TelegramCore`, поэтому без UIKit и Display (TelegramCore общий с macOS-клиентом).

| Файл | Что делает |
| --- | --- |
| `MonogramSettings.swift` | Все переключатели (`MonogramSettings.Key`), проверки режима призрака (`MonogramGhost`), фильтр исходящих запросов |
| `MonogramPeerNotes.swift` | Локальные заметки: хранение, индекс в памяти, поиск чатов по тексту заметки |
| `MonogramGhostActions.swift` | «Прочитать (видно собеседнику)», действия после отправки сообщения в режиме призрака |
| `MonogramMessageAttributes.swift` | Атрибуты «удалено» и «история изменений», их сохранение при удалении, автоудалении, правке и перезаписи сообщения; выборка удалённых сообщений чата |
| `MonogramSelfDestructingMedia.swift` | Одноразовые медиа и медиа с таймером остаются в чате, предзагрузка при получении |
| `MonogramCopyProtection.swift` | Снятие запрета на копирование; пересылка копией защищённого или уже удалённого на сервере сообщения |

### Интерфейс: `submodules/MonogramUI/`

Отдельный Bazel-модуль, зависит от `TelegramCore` и общих UI-модулей; от него зависят `TelegramUI` и `PeerInfoScreen`.

| Файл | Что делает |
| --- | --- |
| `MonogramSettingsController.swift` | Экран «Настройки → Monogram» |
| `MonogramEditHistoryController.swift` | Экран истории изменений сообщения |
| `MonogramDeletedMessagesController.swift` | Список удалённых сообщений чата, открывается из профиля |
| `MonogramPeerInfo.swift` | Текст ID и примерной даты регистрации для профиля, редактор локальной заметки |

`submodules/TelegramUI/Sources/Chat/ChatControllerMonogram.swift` — подтверждение отправки стикеров и GIF.

## Как это встроено

Режим призрака перехватывает запросы в двух местах. Общий фильтр стоит в `Network.request`: по имени функции он гасит отметки о прочтении (`messages.readHistory`, `channels.readHistory`, `messages.readDiscussion`, `messages.readSavedHistory`, `messages.readEncryptedHistory`) и просмотры историй (`stories.readStories`, `stories.incrementStoryViews`). Запрос, который должен пройти несмотря на режим, заранее разрешается через `MonogramGhost.allowRequest`. Остальное отключается там, где запрос рождается:

| Что скрывается | Где |
| --- | --- |
| Онлайн | `ManagedAccountPresence` шлёт `offline: true`, таймер продолжает работать |
| «Печатает…» и прочие действия | `ManagedLocalInputActivities.monogramGhostBlocksActivity` |
| «Прослушано / просмотрено» | `ManagedSynchronizeConsumeMessageContentsOperations` отбрасывает операцию |
| Счётчик непрочитанного после локального чтения | `SynchronizePeerReadState` не повторяет запрос, которого сервер не получит |
| Онлайн после отправки сообщения | `PendingMessageManager` → `monogramGhostDidSendMessage` |

Имя `readMessageContents` в общий фильтр не добавлено намеренно: тем же запросом клиент гасит упоминания и реакции, и блокировка по имени ломала бы эти счётчики.

Сохранение того, что пытаются забрать, держится на двух хуках `SeedConfiguration` в Postbox (`telegramPostboxSeedConfiguration`):

- `mergeMessageAttributes` (штатный хук upstream) — при любой перезаписи сообщения переносит атрибуты «удалено» и «история изменений» из прежней версии;
- `preserveExistingMessageMedia` (добавлен Monogram) — не даёт затереть фото или файл заглушкой `TelegramMediaExpiredContent`.

Точки, где сообщение удаляется или меняется по команде сервера:

| Событие | Где | Что делает Monogram |
| --- | --- | --- |
| Удаление, пришедшее обновлением | `AccountStateManagementUtils` (`DeleteMessages`, `DeleteMessagesWithGlobalIds`) | `monogramKeepDeletedMessages` помечает вместо удаления |
| Удаление, найденное при перепроверке истории канала | `HistoryViewStateValidation` | `monogramKeepMessageRemovedByValidation` помечает и обновляет версию состояния канала |
| Правка, пришедшая обновлением или найденная при перепроверке | `AccountStateManagementUtils` (`EditMessage`), `HistoryViewStateValidation` | `monogramAttributesForEdit` дописывает прежний текст в историю |
| Истечение таймера в секретном чате | `ManagedAutoremoveMessageOperations` | `monogramKeepExpiredSecretMessage` снимает таймер, медиа остаётся |
| Истечение таймера автоудаления в обычном чате | `ManagedAutoremoveMessageOperations` | `monogramKeepAutoremovedMessage` помечает удалённым и снимает таймер. Таймер снимать обязательно: иначе запись о нём остаётся первой в очереди и удаление планируется снова |

То, что пользователь удаляет на этом устройстве, идёт мимо этих точек (`DeleteMessagesInteractively`) и удаляется по-настоящему. Удаление своего сообщения с другого устройства приходит обычным обновлением и сохраняется с пометкой, как и чужое.

Сообщение с пометкой «удалено» существует только на устройстве, поэтому всё, что требует его на сервере, для него отключено: «Ответить», «Закрепить», «Изменить» (`ChatInterfaceStateContextMenus`) и реакции (`canAddMessageReactions`). Пересылка превращается в отправку копии (`monogramConvertProtectedForwards`); медиа при этом уйдёт, только пока действительна ссылка на файл.

Список удалённых сообщений чата строится без отдельного индекса: `engine.messages.monogramDeletedMessages` просматривает атрибуты последних 50 000 сообщений чата (`scanMessageAttributes`). Так в список попадают и сообщения, сохранённые до появления этого экрана.

Поиск по заметкам подключён в одном месте — `TelegramEngine.Contacts.searchLocalPeers(includeMonogramNotes: true)`, который вызывает только поиск списка чатов. Остальные вызовы (подсказки упоминаний, выбор получателя) заметки не видят.

Остальные точки входа: меню чата в списке (`ChatListUI/ChatContextMenus`), меню сообщения (`ChatInterfaceStateContextMenus`), профиль (`PeerInfoProfileItems`), раздел настроек (`PeerInfoSettingsItems`, `PeerInfoScreenSettingsActions`), значок режима рядом с «Изм.» (`ChatListController`, `NavigationButtonComponent`), быстрые действия иконки (`ApplicationShortcutItem`, `AppDelegate`), значки «изменено» и «удалено» у времени сообщения (`StringForMessageTimestampStatus`, `ChatMessageDateAndStatusNode`), реклама (`AdMessages`, `AdPeers`), защита от копирования (`MessageUtils`, `PeerUtils`, `EnqueueMessage`).

## Хранение

- **Настройки** — ключи `monogram.<имя>`, общие для всех аккаунтов. Если у приложения есть App Group (`group.<bundle id>`), они лежат в его `UserDefaults` и видны расширениям; при первом запуске основное приложение переносит туда сохранённые ранее значения. Если App Group нет (так бывает после переподписи), каждый процесс пользуется своим `UserDefaults.standard`, и расширения видят значения по умолчанию. Значения кэшируются в памяти, чтение дешёвое и безопасно в горячих путях.
- **Заметки** — `UserDefaults.standard` основного приложения, ключ `monogram.note.<аккаунт>.<собеседник>`; при первом обращении читаются в память целиком.
- **Удалённые сообщения и история изменений** — атрибуты `MonogramDeletedMessageAttribute` и `MonogramEditHistoryMessageAttribute` на самом сообщении в Postbox, зарегистрированы в `AccountManager.swift`. Отдельной базы, как в ПК-версии, нет, поэтому очистка истории чата на устройстве удаляет и их. История ограничена 100 версиями и хранит только текст.
- Новый ключ настроек обязан иметь значение по умолчанию в `MonogramSettings.Key.defaultValue`.

## Правила для правок

- Исходники в репозитории хранятся с LF (`.gitattributes`). Правка, сохранённая с CRLF, превращает изменение одной строки в замену всего файла и ломает слияние с upstream.
- В файлах upstream правка помечается комментарием `// Monogram:` с объяснением, зачем она нужна.
- Логика выносится в файлы слоя Monogram, в файле upstream остаётся один вызов.
- Сбой функции Monogram не должен мешать авторизации, синхронизации, отправке и приёму сообщений: при неожиданных данных хелперы возвращают управление штатному коду (`return false`, `return nil`, исходный список).
