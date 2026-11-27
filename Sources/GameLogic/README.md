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

## Проверка

Локально на Windows запускается Python-эталон (`tools/logic_oracle.py`):
```
python tools/logic_oracle.py
# ALL LOGIC ORACLE CHECKS PASSED (9 groups)
```

На macOS (или в CI, когда будет разблокирован биллинг):
```
swift test
```

Swift-код **не компилировался локально**: на этом хосте нет Swift toolchain.
Это честно отражено в задачах Dashboard (`NEEDS TESTING`).
