# Dungeon Keeper II — iOS Port (work in progress)

Порт open-source проекта [OpenKeeper](https://github.com/tonihele/OpenKeeper) на iOS
и локальный Control Center, показывающий реальный ход работ.

> Статус: **этап 2 — GitHub + macOS CI**. Удаленный репозиторий:
> `https://github.com/Lolicks/dungeonkeeperii-ios-port` (private).
> В CI на `macos-15` собирается **реальный неподписанный IPA** с нативным
> Metal-рендером и рабочей 3D-сценой. Это не готовая игра Dungeon Keeper II:
> игровая логика OpenKeeper, оригинальные ресурсы и кампания ещё не портированы,
> подпись для установки на iPhone отсутствует.

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
4. **Сейчас CI заблокирован биллингом GitHub**: первый run (`45936325569`)
   упал до выполнения шагов с сообщением «payments have failed or spending
   limit needs to be increased». Проверено и на `ubuntu-latest` — проблема
   аккаунтная, не в коде. Dashboard показывает реальную причину.

## Что нужно от пользователя

См. `IOS_PORT_TECHNICAL_AUDIT.md`, раздел 6. Пользователь сообщил, что
оригинальные ресурсы DK2 и физический iPhone доступны — их нужно передать в
проект (ресурсы не должны попадать в публичный репозиторий; он создан private).
Для установки на iPhone нужны Apple signing credentials.

## Лицензия

Производная работа от OpenKeeper, **GPLv3-or-later**. Оригинальные ресурсы
Dungeon Keeper II не распространяются. Подробности — `LEGAL_AND_LICENSE_REPORT.md`.
