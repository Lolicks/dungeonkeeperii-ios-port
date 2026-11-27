# LEGAL_AND_LICENSE_REPORT

## Код

Кодовая база OpenKeeper распространяется по **GNU GPL v3 (or later)**:

- `OpenKeeper/LICENSE` — полный текст GPL v3 (674 строки, FSF, 29 июня 2007).
- `OpenKeeper/license.txt` — шаблон заголовка «Copyright (C) 2014-${year} OpenKeeper»
  с указанием GPLv3-or-later; присутствует в заголовках Java-файлов.
- `OpenKeeper/README.md:41` — «GNU GPLv3 or later.»

Любой порт, являющийся производным произведением, должен сохранить GPLv3 и
открытый исходный код. Удалять или переименовывать лицензионные заголовки запрещено.
DRM не добавляется.

## Ресурсы оригинальной игры

**Оригинальные ресурсы Dungeon Keeper II не входят в репозиторий и не могут
распространяться.** Об этом прямо сказано в `OpenKeeper/tools/convert/AssetsConverter.java:51-55`:
«Since we own no copyright to these and cannot distribute these, these wont go into
our JAR files». `assets/Converted` исключён из Git (`.gitignore:5`) и из resource set
(`build.gradle:75`).

Для запуска Original-сцены пользователь должен законно предоставить:
- Dungeon Keeper II v1.7 + 3 бонус-пака (для конвертера OpenKeeper), либо
- уже сконвертированный каталог `assets/Converted`, либо
- явное разрешение использовать совместимую свободную замену ресурсов (тогда
  точность порта будет ниже и это должно быть отражено в Dashboard).

Сторонние компоненты:
- jMonkeyEngine 3.9.0-stable, LWJGL3, Nifty GUI forks, simsilica-библиотеки —
  их собственные лицензии проверяются отдельно перед релизом IPA.
- Real-ESRGAN (BSD-3-Clause) используется опционально в `tools/hdtextures`;
  получаемые текстуры являются производными игровых ресурсов и, согласно
  `tools/hd-textures/README.md:111`, должны оставаться у пользователя.

## Статус

Релиз IPA не выполнялся. Дистрибуция не производится. Перед любой публикацией
требуется повторная проверка лицензий всех зависимостей.
