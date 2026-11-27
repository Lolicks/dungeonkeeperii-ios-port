# ASSETS_CONVERSION

## Источник

Пользователь предоставил установленную оригинальную игру:

```
C:\Program Files (x86)\Dungeon Keeper 2
```

Проверено реально: 1434 файла, ~552 МБ. Присутствуют ключевые каталоги и файлы:

- `Data/editor/maps/FrontEnd3DLevel.kwd`
- `Data/Meshes.WAD`, `Data/FrontEnd.WAD`, `Data/Sprite.WAD`, `Data/Paths.WAD`
- `Data/Sound/sfx`, `Data/Movies`, `Data/Text`, `Data/EngineTextures`

Это ровно то, что ожидает `OpenKeeper/utils/PathUtils.java` и
`tools/convert/AssetsConverter.java`.

## Конвертация

OpenKeeper не хранит оригинальные ресурсы в Git и не может их распространять.
Конвертер запускается вручную через Swing UI; для автоматизации добавлен
headless-фронтенд:

- `tools/headless/HeadlessAssetsConverter.java`
- `tools/convert-assets.ps1`

Процедура:

1. Скачивается Temurin JDK 25 (toolchain OpenKeeper — Java 25, на хосте была
   только Java 8).
2. `gradlew.bat classes installDist --no-daemon` собирает проект и все зависимости.
3. `javac` компилирует headless-конвертер с classpath собранного приложения.
4. `java HeadlessAssetsConverter "C:\Program Files (x86)\Dungeon Keeper 2"`
   запускает **реальный** `AssetsConverter.convertAssets()`.
5. Результат появляется в `OpenKeeper/assets/Converted/`
   (Textures, Models, Sounds, Sprites, Interface, Thumbnails, Materials).

`assets/Converted/` намеренно исключён из Git (`.gitignore`) — конвертированные
ресурсы являются производными авторских материалов и не должны попадать в
репозиторий, особенно публичный.

## Статус

Конвертация **успешно выполнена**:

```
CONVERSION_RESULT=true
Conversion took 167 seconds!
converted=13,877 files, 770.6 MB
```

Каталоги: `Interface`, `Materials`, `Models`, `Sounds`, `Sprites`, `Textures`,
`Thumbnails`. Это реальные ресурсы оригинальной игры, подготовленные кодом
OpenKeeper, а не заглушки.

Dashboard: задача «Convert original DK2 assets» = COMPLETED, проблема
«Original DK2 assets not present» = RESOLVED.

## Сборка IPA

Сборка IPA возможна только на macOS. GitHub Actions остаётся заблокированным
биллингом аккаунта (annotation: payments failed / spending limit), поэтому
неподписанный IPA пока не собран.
