# GameLogic — Swift port layer

Платформо-независимый слой игровой логики, перенесённый из реального кода
OpenKeeper. Нет зависимостей от UIKit, Metal, jMonkeyEngine, LWJGL, AWT/Swing
или libGDX — только Swift Standard Library.

| Файл | Что портировано | Источник в OpenKeeper |
|---|---|---|
| `MapModel.swift` | costs 1.0 / 1.4 / 8.0, Terrain, RoomFlag, RoomType, TileConstruction | `game/navigation/pathfinding/INavigable.java`, `tools/convert/map/Room.java`, `tools/convert/map/Thing.java` |
| `PathFinder.swift` | A* с Manhattan-эвристикой, 4/8 соседей, запрет «протискивания» между углами | `MapIndexedGraph.java`, `MapDistance.java`, `WorldUtils.java:180` |
| `CreatureNeeds.swift` | голод (missed meals), сон (sleepNeed), настроение/angry | `CreatureController.java:3074`, `CreatureSleepSystem.java:117`, `CreatureMood.java` |
| `Economy.swift` | добавление/списание золота с учётом вместимости | `GameWorldController.java:252-338` |
| `WorldModel.swift` | плитки/комнаты, индекс `y*width+x`, уровни золота, лимит игрока | `MapData.java`, `MapTile.java`, `StoredGoldVisuals.java`, `PlayerGoldControl.java` |
| `GameClock.swift` | фиксированный шаг 16 666 667 нс, dropped frames, пауза | `utils/GameLoop.java` |
| `Combat.swift` | масштабирование урона, здоровье, rear-бонус, опыт/уровни | `EntityController.java:225`, `HealthSystem.java:440`, `CombatRules.java:60`, `CreatureExperienceSystem.java` |
| `PayAndMood.swift` | часы выплат, зарплата, гнев (нет логов/еды/оплаты) | `PayDaySystem.java:102-257`, `CreatureMoodSystem.java:63-221` |
| `TaskSystem.swift` | приоритет задач, score = Manhattan + priority, TileWork, кинкубы | `TaskWorkerPriorityComparator.java`, `TaskManager.java:1504`, `TileWork.java`, `ChickenSpawnSystem.java` |
| `Shots.swift` | типы урона выстрелов, затухание по радиусу, молния ×2 на воде | `ShotsController.java:305-389`, `LightningShotProcessor.java:81` |
| `Social.swift` | группировка драк, slap, пытка, сбор зарплаты | `BattleSystem.java:54`, `SlapSystem.java`, `CreatureTorturingSystem.java`, `CollectPay.java` |
| `CreatureStateMachine.swift` | приоритет нужд IDLE, прерывание WORK | `CreatureState.java:82-167`, `CreatureController.java:654-713` |
| `HatcherySystem.swift` | спавн кур, cooldown, motionless/pecking | `ChickenSpawnSystem.java:148-211`, `ChickenController.java:198-223` |

## Проверка

Локально на Windows запускается Python-эталон (`tools/logic_oracle.py`):
```
python tools/logic_oracle.py
# ALL LOGIC ORACLE CHECKS PASSED (25 groups)
```

На macOS (или в CI, когда будет разблокирован биллинг):
```
swift test
```

Swift-код **не компилировался локально**: на этом хосте нет Swift toolchain.
Это честно отражено в задачах Dashboard (`NEEDS TESTING`).
