# Monogram — синхронизация с upstream

Последнее обновление: 2026-09-01

## Зафиксированная база

- Repository: `https://github.com/TelegramMessenger/Telegram-iOS.git`
- Remote: `upstream`
- Branch: `master`
- Commit: `6ad963e5b62d354da79040f388ae2b9132fb17b8`
- Telegram iOS: `12.9.2`
- Xcode: `26.2`
- Bazel: `8.4.2`
- macOS: `26`

Первоначальный checkout выполнен с `--depth 1`; все commit IDs submodules сохранены в superproject. При необходимости анализа старой истории shallow-граница расширяется адресно.

## Remotes

- `upstream` — только официальный TelegramMessenger/Telegram-iOS.
- `origin` — должен указывать на репозиторий Monogram; пока не настроен, потому что URL не предоставлен.

Не отправлять custom commits в `upstream`. Push URL для официального remote перед первым production workflow следует отключить или заменить на `DISABLED`.

## Политика custom changes

1. Новая функциональность размещается в `MonogramCore`/`MonogramUI` или другом явно выделенном Monogram-модуле.
2. Upstream-файлы меняются только в минимальных extension points.
3. Причина каждого upstream-патча документируется в этом файле и `CHANGELOG.md`.
4. Если уместно, рядом с нетривиальным патчем ставится короткий комментарий `MONOGRAM:`; бессодержательные маркеры не добавляются.
5. Server-side entitlements, Telegram API semantics и security behavior не подменяются.

## Процесс обновления

1. Убедиться, что рабочее дерево чистое и все Monogram tests проходят.
2. Получить `upstream/master` и release tags.
3. Изучить `versions.json`, `.gitmodules`, build-system и изменения ключевых extension points.
4. Создать отдельную integration-ветку от текущей Monogram-ветки.
5. Merge нового upstream commit; не переписывать опубликованную историю без необходимости.
6. Разрешить конфликты минимально, сохраняя upstream semantics.
7. Синхронизировать и обновить submodules на commit IDs из upstream.
8. Сгенерировать Xcode project с собственной конфигурацией Monogram.
9. Выполнить build, unit tests и smoke matrix.
10. Обновить `FEATURE_MATRIX.md`, `PROJECT_STATUS.md`, этот файл и `CHANGELOG.md`.

## Текущие upstream-патчи

- `Telegram/BUILD`: пользовательский display name изменён на Monogram.
- `Telegram/Telegram-iOS/en.lproj/Localizable.strings`: добавлены строки Advanced Settings.
- `submodules/TelegramUI/BUILD` и `submodules/SettingsUI/BUILD`: подключены Monogram-модули.
- PeerInfo Settings: добавлена точка входа Advanced Settings.
- Пять add-account UI paths: удалены gate 3/4 и подключена `MonogramAccountPolicy`; константы 3/4 удалены из `AccountUtils`.
- `Tests/AllTests/BUILD`: добавлен MonogramCore test target.
- `.gitignore`: защищены локальная Monogram-конфигурация и signing directory.

Вся новая логика находится в `submodules/MonogramCore` и `submodules/MonogramUI`; перечисленные upstream-патчи являются интеграционными точками.

## Ожидаемые конфликтные зоны

- `Telegram/BUILD` и зависимости app/UI targets.
- Settings entry point и Settings search index.
- UI actions добавления аккаунта.
- Chat context menus и presentation preferences.
- App configuration/product naming/assets.

## Требования Telegram к форку

- Использовать собственные `api_id` и `api_hash`.
- Ясно обозначать неофициальный клиент и не называть продукт Telegram.
- Не использовать стандартный официальный логотип Telegram как логотип Monogram.
- Защищать пользовательские данные и публиковать исходный код в соответствии с лицензиями.
