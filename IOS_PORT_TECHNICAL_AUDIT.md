# IOS_PORT_TECHNICAL_AUDIT

Документ основан на реальном осмотре клонированного репозитория
`OpenKeeper` (ветка `master`, HEAD `1a0e5f5`), а не на предположениях.
Дата аудита: 2026-11-27.

## 1. Что реально есть

| Параметр | Значение |
|---|---|
| Репозиторий | `https://github.com/tonihele/OpenKeeper` |
| Рабочая ветка | `ios-port` (создана от `master`, `master` сохранён как резервная копия) |
| Размер рабочего дерева | ~14.7 МБ (без `.git`), `.git` ~20.7 МБ |
| Исходники | 988 Java-файлов в `src/main/java`, ~157k строк |
| Тесты | 423 Java-файла в `src/test/java`, 2142 `@Test` |
| Точка входа | `src/main/java/toniarts/openkeeper/Main.java:122` |
| Лицензия | GNU GPL v3 (файл `LICENSE`, 674 строки; `license.txt` — шаблон заголовка GPLv3-or-later) |
| jMonkeyEngine | 3.9.0-stable (`build.gradle:12`) |
| Gradle | wrapper 9.8.1 (`gradle/wrapper/gradle-wrapper.properties`) |
| Java toolchain | 25 (`build.gradle:80-84`, `114-118`; CI: `ubuntu-latest` + Temurin 25) |
| JUnit | Jupiter 5.14.4, launcher 1.14.4, `useJUnitPlatform()` |

## 2. Хост разработки (реальные данные)

- ОС: Windows (не macOS).
- Git 2.47.0.windows.2 — доступен.
- Java 1.8.0_401 — доступна, **не соответствует toolchain 25**.
- Gradle — не установлен (есть `gradlew`, но ему нужен JDK 25).
- Xcode / xcodebuild / Swift — **отсутствуют и не могут быть установлены на Windows**.

**Вывод:** сборка IPA, подпись и установка на iPhone физически невозможны на этом хосте.
Для этой части нужна macOS-машина или macOS CI-runner. Это зафиксировано как
критический блокер в Dashboard, а не скрыто.

## 3. Архитектурные блокеры для iOS

### 3.1 Desktop-Java рантайм

Проект — обычное desktop-приложение на JVM 25 с плагинами `java`, `application`.
iOS не поддерживает стандартную JVM. Требуется либо AOT-трансляция, либо
перереализация рантайма, либо перенос игровой логики на поддерживаемый стек.
Ни одного готового JNI-модуля или нативного кода в репозитории нет: `System.loadLibrary`
не используется, бинарников `.dll/.so/.dylib` нет (они игнорируются в `.gitignore`).

### 3.2 Графика

`build.gradle` подключает `jme3-desktop` и `jme3-lwjgl3` — desktop-only артефакты.
`jme3-android`/iOS-бэкенда нет. Прямые зависимости от desktop API:

- `src/main/java/toniarts/openkeeper/Main.java:39,70-72` —
  `com.jme3.system.lwjgl.LwjglWindow`, `org.lwjgl.glfw.GLFW`, `GLFWVidMode`,
  `org.lwjgl.opengl.*`. Метод `setBorderless()` (строки 409-418) получает нативный
  handle окна через `getWindowHandle()` и вызывает `glfwSetWindowAttrib/Pos/Size`.
- `Main.java:435-438` — отладочный путь через `GL.getCapabilities().OpenGL43`,
  `GL43C.glDebugMessageControl` (требуется OpenGL 4.3).
- `utils/DisplayModeUtils.java:49-67`, `utils/Lwjgl3DisplayModeProvider.java`,
  `utils/Lwjgl2DisplayModeProvider.java`, `utils/AwtDisplayModeProvider.java` —
  перебор режимов через `Class.forName("org.lwjgl.glfw.GLFW")`, `org.lwjgl.opengl.Display`,
  затем AWT `GraphicsEnvironment`.
- `view/…`, `utils/AssetUtils.java` и ~20 других файлов используют
  `java.awt.image.BufferedImage`, `Graphics2D`, `ImageIO`.

Для iOS нужен бэкенд на Metal (или как минимум GLES-совместимый слой), замена GLFW
и AWT-обработки изображений.

### 3.3 Звук

`game/sound/AudioOutput.java` напрямую использует LWJGL OpenAL (`ALC10`,
расширения `SOFTHRTF`, `SOFTOutputMode`, `MemoryStack.stackPush()`,
`UnsatisfiedLinkError`). На iOS требуется замена на AVAudio/OpenAL-совместимый слой.

### 3.4 UI и first-run Setup

- `setup/DKFolderSelector.java` — `javax.swing.JFrame`, `JFileChooser`, Nimbus L&F.
- `setup/DKConverter.java` — `JFrame`, `JOptionPane`, `SwingUtilities`.
- `Main.java:203-233,321-387` — `WindowAdapter`, `BufferedImage`, `ImageIO`, `JFrame`.

Весь first-run UI нужно заменить на нативный Swift/iOS UI.

### 3.5 Файлы, потоки, внешние процессы

- `utils/PathUtils.java` — путь к DK2 получается из настройки `DungeonKeeperIIFolder`,
  проверяется наличие `Data/editor/maps/FrontEnd3DLevel.kwd`; много `File.separator`.
- `tools/convert/AssetsConverter.java:111,308` — `assets/Converted` относительно
  текущей рабочей директории (`Paths.get("").toAbsolutePath()`).
- `utils/SettingUtils.java:37` — `openkeeper.properties` в CWD; `~/.OpenKeeper/`.
- `utils/GameLoop.java` — собственный тик-цикл с `synchronized(pauseFlag)`;
  `ScheduledExecutorService`, `Executors`, `CountDownLatch` в сетевом коде и TGQ-видео.
- `tools/hdtextures/HdTextures.java:415,917` — `ProcessBuilder` (Real-ESRGAN, `git rev-parse`),
  загрузка бинарников с GitHub, `System.exit(1)`. Для iOS это непригодно без адрезки.

## 4. Игровые ресурсы — критический пробел

`assets/` содержит только 59 файлов (~5.53 МБ): иконки, Nifty-XML интерфейса (21),
6 `.j3md`, 15 шейдеров, модель `Models/ModelViewer/studio.j3o` (3 МБ) и 6 мраморных
текстур для model viewer.

**Оригинальных ресурсов Dungeon Keeper II в репозитории нет.**
`README.md:6-8`: проект требует оригинальную игру для игры/разработки.
`tools/convert/AssetsConverter.java:51-55`: «Since we own no copyright to these and
cannot distribute these, these wont go into our JAR files». Каталог
`assets/Converted` не отслеживается Git (`.gitignore:5`) и исключён из resource set
(`build.gradle:75`). Конвертация запускается Swing-диалогами и записывает
`Sounds/Models/Textures/Sprites/Thumbnails/Interface/*`.

Без законно полученных исходных ресурсов DK2 (версия 1.7 + 3 бонус-пака) и
прогона конвертера невозможно загрузить оригинальную сцену — значит, требование
«максимально точного порта» невыполнимо без участия пользователя.

## 5. Оценка трудозатрат (реалистичная)

| Направление | Что нужно | Оценка |
|---|---|---|
| Рантайм | AOT/нативная компиляция или перенос логики на Swift/Kotlin-native | недели-месяцы |
| Графика | Metal-бэкенд jME или замена рендерера; 988 файлов view-слоя затронуты | месяцы |
| Аудио | Замена LWJGL OpenAL | дни-недели |
| UI | Замена Swing/AWT + Nifty на iOS UI | недели |
| Ресурсы | Получение и конвертация оригинальных ассетов | зависит от пользователя |
| Сборка | macOS + Xcode + Apple signing | зависит от пользователя |

Это не «.demo за один вечер». Dashboard показывает реальный, а не желаемый прогресс.

## 6. Что запрошено у пользователя и текущий ответ

1. macOS/Xcode — **решено через GitHub Actions** (`macos-15`, workflow `build-ios.yml`);
   неподписанный IPA собран в run `45941116495`.
2. Apple Developer credentials / signing team — **всё ещё требуется** для установки
   на реальный iPhone.
3. Оригинальные ресурсы DK2 — пользователь подтвердил наличие; **нужна передача**
   в приватный репозиторий (или готовый `assets/Converted`).
4. Физический iPhone — пользователь подтвердил наличие; установка блокируется
   отсутствием подписи.

## 7. Что сделано на текущем этапе

- [x] Проверена среда.
- [x] Клонирован OpenKeeper, создана ветка `ios-port`.
- [x] Проведён технический аудит (этот документ).
- [x] Создан локальный Control Center с реальными источниками данных.
- [ ] Выбор рантайм-стратегии (блокер: пользователь).
- [ ] Минимальный iOS-прототип (блокер: macOS/Xcode).
