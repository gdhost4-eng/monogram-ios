# Monogram — синхронизация с upstream

Последнее обновление: 2026-10-04

## Зафиксированная база

- Repository: `https://github.com/TelegramMessenger/Telegram-iOS.git`, remote `upstream`, ветка `master`.
- Telegram iOS `12.9.2`, Xcode `26.2`, Bazel `8.4.2`, macOS `26`.
- База — коммит «Merge branch 'master' into beta» от 2026-07-17. На GitHub у него хеш `6ad963e5b62d354da79040f388ae2b9132fb17b8`, и на 2026-10-04 это по-прежнему вершина `upstream/master`: синхронизировать пока нечего.

### История не связана с upstream

В этом репозитории тот же коммит записан как `b0bec555` — корневой, без родителей, и с другим деревом (`1100f0fb…` против `7e4b2d09…` у `6ad963e5`). Репозиторий начинался с неполного клона, и общей истории с upstream у него нет. Отсюда два следствия:

- `git merge upstream/master` после обычного `git fetch` не найдёт общего предка. Понадобится либо `--allow-unrelated-histories` с разбором конфликтов по всему дереву, либо перенос правок Monogram поверх свежего клона upstream. Второй путь чище: правок немного, и они перечислены ниже.
- Чем различаются два дерева, не выяснено. Перед первым слиянием это нужно проверить (`git diff b0bec555 6ad963e5 --stat` после fetch), иначе разница попадёт в конфликты вперемешку с настоящими изменениями upstream.

## Remotes

- `upstream` — только официальный TelegramMessenger/Telegram-iOS. Коммиты Monogram туда не отправляются.
- `origin` — `https://github.com/gdhost4-eng/monogram-ios.git`.

## Политика правок

1. Новая логика размещается в `submodules/TelegramCore/Sources/Monogram/` и `submodules/MonogramUI/`.
2. В файлах upstream остаётся минимальная точка встраивания — обычно один вызов и комментарий `// Monogram:` с причиной.
3. Исходники хранятся с LF (`.gitattributes`). Файл, сохранённый с CRLF, даёт дифф на все строки и гарантированный конфликт при слиянии.
4. Серверные права, Premium и семантика Telegram API не подменяются.

## Текущие правки в файлах upstream

Список получен командой `git diff --name-status b0bec555 master` и сгруппирован по назначению.

**Сборка и конфигурация**

- `.github/workflows/build.yml` — сборка IPA на macOS-исполнителе с самоподписанными профилями и кэшем Bazel.
- `.gitmodules` — абсолютные URL для `rlottie` и `tgcalls` вместо относительных.
- `build-system/Make/BuildConfiguration.py`, `build-system/example-configuration/variables.bzl`, `submodules/BuildConfig/BUILD` — `api_hash` передаётся в `BuildConfig` из конфигурации.
- `.gitignore`, `.gitattributes` — локальная конфигурация и подпись вне Git; LF для исходников.
- `submodules/ShareItems/Impl/Sources/TGShareLocationSignals.m` — определён `shortenerUrl`, без которого файл не компилировался.

**Название и иконка**

- `Telegram/BUILD`, `Telegram/Telegram-iOS/*.lproj/InfoPlist.strings`, `Telegram/Share` и `Telegram/WidgetKitWidget` (`Localizable.strings`), `Telegram/SiriIntents/IntentHandler.swift` — имя Monogram.
- `Telegram/Telegram-iOS`: `Telegram.icon`, `AppIcons.xcassets`, `DefaultAppIcon.xcassets`, `BlueIcon.alticon` — собственная иконка; `TelegramUI/Images.xcassets/Chat List/GhostModeIcon.imageset` — значок режима призрака.
- `build-system/GenerateStrings/GenerateStrings.py` — в строках интерфейса «Telegram» заменяется на «Monogram» на лету, включая языковые пакеты с сервера; названия сервисов (Premium, Stars…), @имена и домены не трогаются.
- `SettingsUI/Sources/Themes/ThemeSettingsController.swift`, `SettingsUI/Sources/Search/SettingsSearchableItems.swift` — выбор иконки приложения скрыт.

**Аккаунты**

- `AccountUtils/Sources/AccountUtils.swift`, `SettingsUI/Sources/LogoutOptionsController.swift`, `SettingsUI/Sources/DeleteAccountOptionsController.swift`, `PeerInfoScreenSettingsActions.swift` — снят лимит в 3/4 аккаунта.

**Запуск и навигация**

- `TelegramUI/Sources/AppDelegate.swift` — запуск без App Group, быстрые действия режима призрака.
- `TelegramUI/Sources/ApplicationContext.swift` — готовность экрана чата не ждёт доступа к контактам.

**Функции Monogram** — точки встраивания, описанные в `ARCHITECTURE.md`:

- Postbox: `SeedConfiguration.swift`, `MessageHistoryTable.swift` (хук `preserveExistingMessageMedia`).
- TelegramCore: `Account/AccountManager.swift`, `Network/Network.swift`, `PendingMessages/EnqueueMessage.swift`, `State/AccountStateManagementUtils.swift`, `State/HistoryViewStateValidation.swift`, `State/ManagedAccountPresence.swift`, `State/ManagedAutoremoveMessageOperations.swift`, `State/ManagedLocalInputActivities.swift`, `State/ManagedSynchronizeConsumeMessageContentsOperations.swift`, `State/PendingMessageManager.swift`, `State/SynchronizePeerReadState.swift`, `SyncCore/SyncCore_StandaloneAccountTransaction.swift`, `TelegramEngine/Messages/AdMessages.swift`, `TelegramEngine/Messages/TelegramEngineMessages.swift`, `TelegramEngine/Peers/AdPeers.swift`, `Utils/MessageUtils.swift`, `Utils/PeerUtils.swift`.
- ChatListUI: `ChatContextMenus.swift`, `ChatListController.swift`.
- TelegramUI: `BUILD`, `ChatController.swift`, `ChatControllerContentData.swift`, `ChatHistoryListNode.swift`, `ChatInterfaceStateContextMenus.swift`, `Chat/ChatControllerMediaRecording.swift`, `ApplicationShortcutItem.swift`, `Components/Chat/ChatMessageDateAndStatusNode` (два файла), `Components/ChatListHeaderComponent/Sources/NavigationButtonComponent.swift`, `Components/PeerInfo/PeerInfoScreen` (`BUILD`, `PeerInfoProfileItems.swift`, `PeerInfoScreen.swift`, `PeerInfoSettingsItems.swift`).

## Ожидаемые конфликтные зоны

`ChatController.swift`, `ChatHistoryListNode.swift`, `ChatListController.swift`, `AccountStateManagementUtils.swift` и `PeerInfoProfileItems.swift` upstream меняет почти в каждом релизе. Правки Monogram в них — по несколько строк; при конфликте проще взять версию upstream и вставить вызов заново, чем разбирать конфликт построчно.

`Postbox/SeedConfiguration.swift`: если upstream добавит в инициализатор новый параметр, параметр `preserveExistingMessageMedia` нужно сохранить и в объявлении, и в `telegramPostboxSeedConfiguration`.

## Процесс обновления

1. Рабочее дерево чистое, последняя сборка в CI зелёная.
2. Получить `upstream/master`; прочитать изменения в `versions.json`, `.gitmodules`, `build-system` и в файлах из списка выше.
3. В отдельной ветке перенести правки Monogram на новую базу (см. «История не связана с upstream»).
4. Обновить submodules до коммитов upstream.
5. Собрать IPA, пройти smoke test по `FEATURE_MATRIX.md`.
6. Обновить этот файл, `PROJECT_STATUS.md`, `FEATURE_MATRIX.md` и `CHANGELOG.md`.

## Требования Telegram к форку

- Использовать собственные `api_id` и `api_hash`.
- Ясно обозначать неофициальный клиент и не называть продукт Telegram.
- Не использовать стандартный официальный логотип Telegram как логотип Monogram.
- Защищать пользовательские данные и публиковать исходный код в соответствии с лицензиями.
