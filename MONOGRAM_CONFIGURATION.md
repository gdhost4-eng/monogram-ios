# Конфигурация Monogram

Реальные Telegram API и Apple signing credentials не хранятся в Git.

## Development/simulator

1. Получить собственные `api_id` и `api_hash` на `https://my.telegram.org/apps`.
2. Скопировать `build-system/monogram-development-configuration.example.json` в `build-system/monogram-development-configuration.json`.
3. Заменить placeholders на собственные значения. Не использовать credentials официального Telegram.
4. Проверить конфигурацию без вывода секретов:

```sh
python3 scripts/validate_monogram_configuration.py \
  build-system/monogram-development-configuration.json
```

5. На macOS 26 с Xcode 26.2 сгенерировать проект официальным Make workflow:

```sh
python3 build-system/Make/Make.py \
  --cacheDir="$HOME/monogram-bazel-cache" \
  generateProject \
  --configurationPath=build-system/monogram-development-configuration.json \
  --xcodeManagedCodesigning
```

Для simulator-only workflow использовать поддерживаемый upstream флаг `--disableProvisioningProfiles`, когда передаётся отдельный signing information path.

## Device/App Store

Для device build дополнительно нужны собственные Bundle Identifier, Apple Team ID, certificates, provisioning profiles и APNs configuration. Production profiles и signing material размещаются вне repository и передаются build workflow через локальный путь или защищённую CI secret store.

Для установки на iPhone выполните device-сборку на macOS с Xcode. Артефакты всегда будут помещены непосредственно в каталог `build`: IPA — `build/Telegram.ipa`, а отладочные символы — `build/Telegram.DSYMs.zip`.

```sh
python3 build-system/Make/Make.py \
  --cacheDir="$HOME/monogram-bazel-cache" \
  build \
  --configurationPath=build-system/monogram-development-configuration.json \
  --xcodeManagedCodesigning \
  --configuration=release_arm64 \
  --buildNumber=100001 \
  --outputBuildArtifactsPath=build
```

Для реального iPhone требуется корректная development/ad-hoc подпись. IPA, собранный с `fake-codesigning`, предназначен только для CI-проверки и не устанавливается на устройство.

## Сборка с Windows через GitHub Actions

GitHub Actions выполняет сборку на macOS 26 с Xcode 26.2, поэтому Windows используется только для подготовки и скачивания результата. Workflow создаёт временный self-signed provisioning profile для упаковки IPA и исключает встроенные расширения (Siri, Share, уведомления, виджет). Этот профиль не пригоден для установки сам по себе: PlumeImpactor полностью переподписывает IPA при установке.

1. Создайте приватный репозиторий GitHub и отправьте в него исходники вместе с изменением workflow.

3. Откройте **Actions → CI → Run workflow**. После успешного выполнения скачайте `Monogram-IPA-<номер>` из блока **Artifacts**. В архиве находится `Telegram.ipa`.

PlumeImpactor при установке подпишет IPA вашим Apple ID или сертификатом.

## Branding

Пользовательское имя приложения — Monogram. Внутренние Bazel/Xcode target names могут оставаться upstream-именами `Telegram`, чтобы уменьшить конфликты при синхронизации. Перед распространением официальный Telegram app icon должен быть заменён на самостоятельную иконку Monogram.
