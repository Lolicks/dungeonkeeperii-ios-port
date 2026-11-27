# GAMELOGIC_COVERAGE

Прозрачная карта того, что реально перенесено из OpenKeeper в `Sources/GameLogic`.
Статус `NEEDS TESTING` означает: логика портирована, локальный Python-эталон
проходит, но Swift ещё не компилировался (нет toolchain на Windows).

| Swift-файл | Источник(и) в OpenKeeper | Формулы | Проверка |
|---|---|---|---|
| `MapModel.swift` | `INavigable.java`, `Room.java:40-93`, `Thing.java:366-404` | 1.0/1.4/8.0, биты RoomFlag, RoomType | oracle 10-11 |
| `PathFinder.swift` | `MapIndexedGraph.java`, `MapDistance.java`, `WorldUtils.java:180` | A*, Manhattan, 4/8 соседей, corner rule | oracle 1-4 |
| `CreatureNeeds.swift` | `CreatureController.java:3074`, `CreatureSleepSystem.java:117`, `CreatureMood.java` | missed meals, sleepNeed, anger clamp /4 | oracle 5-8 |
| `Economy.swift` | `GameWorldController.java:252-338` | add/sub gold, ceil per treasury | oracle 9 |
| `WorldModel.swift` | `MapData.java`, `StoredGoldVisuals.java`, `PlayerGoldControl.java` | index y·w+x, gold tiers, cap + mined | oracle 10-11 |
| `GameClock.swift` | `utils/GameLoop.java` | 16 666 667 нс, dropped frames, pause | oracle 12 |
| `Combat.swift` | `EntityController.java:225`, `HealthSystem.java:440`, `CombatRules.java:60`, `CreatureExperienceSystem.java`, `CreaturesController.java:634` | scaleDamage /128, clamp health, rear bonus, xp/level % | oracle 13-15 |
| `PayAndMood.swift` | `PayDaySystem.java:102-257`, `CreatureMoodSystem.java:63-221` | часы выплат, unpaid, гнев /4, lair recovery | oracle 16 |
| `TaskSystem.swift` | `TaskWorkerPriorityComparator.java`, `TaskManager.java:1504`, `TileWork.java`, `ChickenSpawnSystem.java` | distance+priority, 3×open sides, perSwing/perTick, cooldown | oracle 17-19 |
| `Shots.swift` | `ShotsController.java:305-389`, `LightningShotProcessor.java:81` | falloff, CONSTANT rect, drain, ×2 water | oracle 20 |
| `Social.swift` | `BattleSystem.java`, `SlapSystem.java`, `CreatureTorturingSystem.java`, `CollectPay.java` | radius 5 / 4 s, slap anger без /4, collect/2 | oracle 21-22 |

Итого: **11 Swift-файлов**, **22 группы локальных проверок**, все проходят.

## Что ещё НЕ портировано (реально)

- 988 Java-файлов OpenKeeper целиком; портированы только чистые формулы выше.
- Отображение/view-слой jMonkeyEngine (требует Metal-бэкенд).
- Загрузка и конвертация оригинальных ресурсов DK2 (нет ресурсов).
- Кампания и KWD-данные уровней.
- Сеть/мультиплеер, TGQ-видео, Nifty UI, Swing-настройка.
- Сохранение/загрузка (Savable/JME).
- Компиляция Swift, XCTest, IPA, установка на iPhone — внешние блокеры.
