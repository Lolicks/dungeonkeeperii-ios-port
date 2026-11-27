# Dungeon Keeper II — iOS Port (work in progress)

Порт open-source проекта [OpenKeeper](https://github.com/tonihele/OpenKeeper) на iOS
и локальный Control Center, показывающий реальный ход работ.

> Статус: **неподписанный IPA собран**. Репозиторий:
> `https://github.com/Lolicks/dungeonkeeperii-ios-port` (публичный, чтобы
> использовать бесплатные минуты macOS-раннера).
> CI run `45941116495` = SUCCESS: `output/DungeonKeeperII.ipa` (52 807 bytes),
> внутри arm64 Mach-O + `default.metallib` + `Info.plist`.
> Оригинальные ресурсы DK2 сконвертированы локально (13 877 файлов, 770.6 МБ).
> **Это не готовая игра**: в IPA только нативная Metal 3D-сцена; логика, ресурсы
> и кампания в IPA не включены; подпись для установки на iPhone отсутствует.

## Структура

```
DungeonKeeperII-iOS/
├── OpenKeeper/                     # клон оригинального репозитория, ветка ios-port
├── ios/                            # нативный Xcode-проект (Metal 3D-сцена)
├── .github/workflows/build-ios.yml # сборка IPA на macOS-раннере GitHub
├── Sources/GameLogic/              # Swift-порт A*, нужд существ и экономики
├── Tests/GameLogicTests/           # XCTest-набор (запускается swift test на Mac)
├── Package.swift                   # headless Swift package для тестов
├── tools/logic_oracle.py           # локально выполняемый эталон алгоритмов
├── GAMELOGIC_COVERAGE.md           # карта портированных формул и пробелов
├── Resources/ Configuration/
├── dashboard/
│   ├── frontend/                   # React + TypeScript + Recharts + Tailwind
│   ├── backend/                    # Python FastAPI + WebSocket
│   ├── database/                   # SQLite (создаётся при первом запуске)
│   ├── logs/ reports/ config/
│   └── start-dashboard.sh / start-dashboard.ps1
├── scripts/                        # build-ios.sh, build-ipa.sh, run-tests.sh
├── output/                         # DungeonKeeperII.ipa, BUILD_REPORT.md (пока пусто)
├── IOS_PORT_TECHNICAL_AUDIT.md
├── PROJECT_STATE.md
├── LEGAL_AND_LICENSE_REPORT.md
└── README.md
```

## Запуск Control Center

Требуется Python 3.10+ и Node 18+.

```powershell
# 1. Backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r dashboard/backend/requirements.txt

# 2. Frontend (уже собран при установке; при изменении исходников):
cd dashboard/frontend
npm install
npm run build
cd ..\..

# 3. Запуск (порт 8080)
python dashboard/backend/app.py   # или: uvicorn dashboard.backend.app:app --port 8080
```

Откройте `http://localhost:8080`.

Dashboard показывает: реальный процент (только подтверждённые задачи),
текущую/следующую задачу, блокеры, CRC состояния Git, данные окружения,
журнал активности, задачи и статус IPA. Обновления приходят по WebSocket.

## Сборка IPA в GitHub Actions

1. Изменения пушатся в ветку `ios-port`.
2. Workflow `.github/workflows/build-ios.yml` запускается на `macos-15`,
   собирает `DungeonKeeperII.xcarchive` (`CODE_SIGNING_ALLOWED=NO`),
   упаковывает `output/DungeonKeeperII.ipa` и загружает его как artifact.
3. Подписанный IPA для установки на реальный iPhone требует Apple Developer
   credentials — их пока нет. Неподписанный IPA пригоден только для проверки
   сборки/симуляции, не для установки на device.
4. Биллинг был разблокирован переводом репозитория в public; первый билд упал
   из-за неверных путей Swift-файлов в `.pbxproj` и ошибок компиляции, они
   исправлены. Run `45941116495` завершился успешно; IPA скачан в `output/`.
5. Конвертированные ресурсы DK2 намеренно **не загружаются** в публичный
   репозиторий (авторские материалы). Для IPA с ресурсами нужен приватный
   канал передачи ассетов в CI.

## Что нужно от пользователя

См. `IOS_PORT_TECHNICAL_AUDIT.md`, раздел 6. Пользователь сообщил, что
оригинальные ресурсы DK2 и физический iPhone доступны — их нужно передать в
проект (ресурсы не должны попадать в публичный репозиторий; он создан private).
Для установки на iPhone нужны Apple signing credentials.

## Лицензия

Производная работа от OpenKeeper, **GPLv3-or-later**. Оригинальные ресурсы
Dungeon Keeper II не распространяются. Подробности — `LEGAL_AND_LICENSE_REPORT.md`.
