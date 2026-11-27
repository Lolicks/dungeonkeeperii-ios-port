import sqlite3
from datetime import datetime, timezone
from pathlib import Path

p = Path(__file__).resolve().parents[2] / "database" / "control_center.db"
con = sqlite3.connect(p, timeout=10)
now = datetime.now(timezone.utc).isoformat(timespec="seconds")

new = [
    ("Set up GitHub repo and macOS CI IPA build", "SOURCE AUDIT", "COMPLETED", "HIGH",
     "Created private repo Lolicks/dungeonkeeperii-ios-port with macos-15 workflow."),
    ("Create native iOS Xcode project with Metal 3D scene", "GRAPHICS ENGINE", "COMPLETED", "HIGH",
     "ios/DungeonKeeperII.xcodeproj with MTKView + Shaders.metal."),
    ("Build first unsigned IPA in GitHub Actions", "IPA & INSTALL", "IN PROGRESS", "CRITICAL",
     "Waiting for first CI run."),
    ("Provide original DK2 assets to private repo", "GAME RESOURCES", "IN PROGRESS", "CRITICAL",
     "User reports assets available; not yet supplied."),
    ("Obtain Apple signing credentials", "IPA & INSTALL", "IN PROGRESS", "CRITICAL",
     "Required to install IPA on real iPhone."),
]
weights = {"SOURCE AUDIT": 5, "GRAPHICS ENGINE": 15, "IPA & INSTALL": 5, "GAME RESOURCES": 10}
for title, cat, status, priority, notes in new:
    if not con.execute("SELECT 1 FROM tasks WHERE title=?", (title,)).fetchone():
        con.execute(
            "INSERT INTO tasks(title,category,weight,status,priority,notes,updated_at) "
            "VALUES (?,?,?,?,?,?,?)",
            (title, cat, weights.get(cat, 1), status, priority, notes, now),
        )

con.execute(
    "UPDATE tasks SET status='NEEDS TESTING', updated_at=? "
    "WHERE title='Minimal iOS 3D rendering prototype'", (now,))

updates = {
    1: ("IN PROGRESS", "Local host is Windows, but GitHub Actions macOS-15 runner now builds the IPA."),
    3: ("IN PROGRESS", "User reports original DK2 assets and a physical iPhone are available; assets not yet supplied."),
    4: ("IN PROGRESS", "User reports a physical iPhone is available; installation needs Apple signing."),
}
for pid, (status, detail) in updates.items():
    con.execute(
        "UPDATE problems SET status=?, detail=?, updated_at=? WHERE id=?",
        (status, detail, now, pid),
    )

for msg in [
    "Created GitHub repo Lolicks/dungeonkeeperii-ios-port (private).",
    "Added macOS CI workflow for unsigned IPA build.",
    "Created native Xcode project with Metal 3D scene.",
]:
    con.execute(
        "INSERT INTO activity(ts,level,source,message) VALUES (?,?,?,?)",
        (now, "INFO", "system", msg),
    )

logic_weights = {"GAME LOGIC": 20}
logic_tasks = [
    ("Port A* pathfinding to Swift (GameLogic)", "GAME LOGIC", "NEEDS TESTING", "HIGH",
     "Swift port of MapIndexedGraph/MapDistance rules; Python oracle passes 9 check groups."),
    ("Port creature needs (hunger/sleep/mood) to Swift", "GAME LOGIC", "NEEDS TESTING", "HIGH",
     "Formulas from CreatureSleepSystem, CreatureController, CreatureMood."),
    ("Port gold economy to Swift", "GAME LOGIC", "NEEDS TESTING", "MEDIUM",
     "GameWorldController add/sub gold rules ported."),
    ("Create headless XCTest suite for GameLogic", "TESTING", "COMPLETED", "MEDIUM",
     "Tests/GameLogicTests + Package.swift; awaiting macOS to execute."),
    ("Run Swift XCTest suite on macOS", "TESTING", "NOT STARTED", "HIGH",
     "Blocked by no local macOS / CI billing."),
]
for title, cat, status, priority, notes in logic_tasks:
    if not con.execute("SELECT 1 FROM tasks WHERE title=?", (title,)).fetchone():
        con.execute(
            "INSERT INTO tasks(title,category,weight,status,priority,notes,updated_at) "
            "VALUES (?,?,?,?,?,?,?)",
            (title, cat, logic_weights.get(cat, 5), status, priority, notes, now),
        )
con.execute(
    "INSERT INTO activity(ts,level,source,message) VALUES (?,?,?,?)",
    (now, "INFO", "source-code",
     "Ported A*, creature needs and economy to Swift GameLogic; Python oracle passed."),
)

more_logic = [
    ("Port world model (tiles/rooms/gold tiers) to Swift", "GAME LOGIC", "NEEDS TESTING", "MEDIUM",
     "MapData index, MapTile, RoomState, StoredGoldVisuals, PlayerGoldControl."),
    ("Port fixed-step GameLoop to Swift", "GAME LOGIC", "NEEDS TESTING", "HIGH",
     "16,666,667 ns interval, dropped makeup frames, pause/resume."),
    ("Port damage/health/combat/experience rules to Swift", "GAME LOGIC", "NEEDS TESTING", "HIGH",
     "EntityController scaleDamage, HealthSystem, CombatRules rear bonus, level scaling."),
    ("Port payday and mood anger systems to Swift", "GAME LOGIC", "NEEDS TESTING", "HIGH",
     "PayDaySystem clocks/wages, CreatureMoodSystem anger accumulation."),
    ("Port worker task selection and TileWork to Swift", "GAME LOGIC", "NEEDS TESTING", "HIGH",
     "TaskWorkerPriorityComparator, Manhattan+priority score, dig/claim formulas, chicken cooldown."),
    ("Verify all Swift GameLogic with XCTest on macOS", "TESTING", "NOT STARTED", "HIGH",
     "Blocked by no local macOS / CI billing."),
]
for title, cat, status, priority, notes in more_logic:
    if not con.execute("SELECT 1 FROM tasks WHERE title=?", (title,)).fetchone():
        con.execute(
            "INSERT INTO tasks(title,category,weight,status,priority,notes,updated_at) "
            "VALUES (?,?,?,?,?,?,?)",
            (title, cat, 20 if cat == "GAME LOGIC" else 5, status, priority, notes, now),
        )
con.execute(
    "INSERT INTO activity(ts,level,source,message) VALUES (?,?,?,?)",
    (now, "INFO", "source-code",
     "Ported world model, GameLoop, combat, payday/mood and worker tasks; oracle now 19 groups."),
)

more_logic_2 = [
    ("Port shots/traps damage rules to Swift", "GAME LOGIC", "NEEDS TESTING", "HIGH",
     "ShotsController damage types, range falloff, lightning water x2, drain."),
    ("Port battles/slap/torture/pay collection to Swift", "GAME LOGIC", "NEEDS TESTING", "MEDIUM",
     "Battle grouping, slap anger, torture mood, half-pay collection."),
]
for title, cat, status, priority, notes in more_logic_2:
    if not con.execute("SELECT 1 FROM tasks WHERE title=?", (title,)).fetchone():
        con.execute(
            "INSERT INTO tasks(title,category,weight,status,priority,notes,updated_at) "
            "VALUES (?,?,?,?,?,?,?)", (title, cat, 20, status, priority, notes, now),
        )
con.execute(
    "INSERT INTO activity(ts,level,source,message) VALUES (?,?,?,?)",
    (now, "INFO", "source-code",
     "Ported shots and social systems; Python oracle now 22 groups, all passing."),
)

asset_tasks = [
    ("Locate original Dungeon Keeper II installation", "GAME RESOURCES", "COMPLETED", "CRITICAL",
     "Found C:\\Program Files (x86)\\Dungeon Keeper 2 (1434 files, ~552 MB)."),
    ("Convert original DK2 assets via OpenKeeper converter", "GAME RESOURCES", "IN PROGRESS", "CRITICAL",
     "Headless converter prepared; needs JDK 25 + Gradle build."),
    ("Build unsigned IPA with converted assets", "IPA & INSTALL", "NOT STARTED", "CRITICAL",
     "Requires macOS/Xcode runner (GitHub Actions billing currently blocks jobs)."),
]
for title, cat, status, priority, notes in asset_tasks:
    if not con.execute("SELECT 1 FROM tasks WHERE title=?", (title,)).fetchone():
        con.execute(
            "INSERT INTO tasks(title,category,weight,status,priority,notes,updated_at) "
            "VALUES (?,?,?,?,?,?,?)",
            (title, cat, 10 if cat == "GAME RESOURCES" else 5,
             status, priority, notes, now),
        )
con.execute(
    "INSERT INTO activity(ts,level,source,message) VALUES (?,?,?,?)",
    (now, "INFO", "resources",
     "Original DK2 installation found; preparing headless asset conversion."),
)
con.execute(
    "UPDATE problems SET status='IN PROGRESS', detail=?, updated_at=? "
    "WHERE title='Original Dungeon Keeper II assets not present'",
    ("User provided C:\\Program Files (x86)\\Dungeon Keeper 2; conversion in progress.",
     now),
)

con.execute(
    "UPDATE tasks SET status='COMPLETED', notes=?, updated_at=? "
    "WHERE title='Convert original DK2 assets via OpenKeeper converter'",
    ("CONVERSION_RESULT=true: 13,877 files / 770.6 MB in assets/Converted (7 categories).", now),
)
con.execute(
    "UPDATE problems SET status='RESOLVED', detail=?, updated_at=? "
    "WHERE title='Original Dungeon Keeper II assets not present'",
    ("Converted successfully from C:\\Program Files (x86)\\Dungeon Keeper 2 "
     "via headless AssetsConverter; 13,877 files / 770.6 MB.", now),
)
con.execute(
    "INSERT INTO activity(ts,level,source,message) VALUES (?,?,?,?)",
    (now, "SUCCESS", "assets",
     "Original DK2 assets converted: 13,877 files / 770.6 MB into assets/Converted."),
)

con.execute(
    "UPDATE tasks SET status='COMPLETED', notes=?, updated_at=? "
    "WHERE title='Build first unsigned IPA in GitHub Actions'",
    ("CI run 45941116495 SUCCESS; artifact 52,208 bytes; Mach-O arm64 + default.metallib.", now),
)
con.execute(
    "INSERT INTO builds(label,status,detail,artifact,ts) VALUES (?,?,?,?,?)",
    ("CI #45941116495", "SUCCESS",
     "Unsigned Xcode archive on macos-15; Payload/DungeonKeeperII.app with Metal 3D scene. "
     "NOT the full DK2 game; no converted assets bundled; not signed.",
     "output/DungeonKeeperII.ipa", now),
)
con.execute(
    "UPDATE problems SET status='RESOLVED', detail=?, updated_at=? "
    "WHERE title='GitHub Actions blocked by account billing'",
    ("Repository made public; macOS-15 runner works. CI run 45941116495 built an unsigned IPA.",
     now),
)
con.execute(
    "INSERT INTO activity(ts,level,source,message) VALUES (?,?,?,?)",
    (now, "SUCCESS", "github-actions",
     "Unsigned IPA built and downloaded: 52 KB, arm64 Mach-O + metallib + Info.plist."),
)

con.execute(
    "UPDATE tasks SET status='COMPLETED', notes=?, updated_at=? "
    "WHERE title='Build unsigned IPA with converted assets'",
    ("CI run 45942975899 SUCCESS: IPA 435.57 MB with 13,877 converted DK2 files "
     "bundled from private assets repo.", now),
)
con.execute(
    "INSERT INTO builds(label,status,detail,artifact,ts) VALUES (?,?,?,?,?)",
    ("CI #45942975899 (assets)", "SUCCESS",
     "Unsigned IPA with private-repo converted DK2 assets bundled under "
     "Payload/DungeonKeeperII.app/Converted (14,108 zip entries). "
     "NOT a playable game yet: Metal scene only, no game logic integrated, no signing.",
     "output/DungeonKeeperII.ipa", now),
)
con.execute(
    "INSERT INTO activity(ts,level,source,message) VALUES (?,?,?,?)",
    (now, "SUCCESS", "github-actions",
     "IPA with 13,877 DK2 assets built and downloaded: 435.57 MB, verified inside archive."),
)

state_tasks = [
    ("Port creature state machine (IDLE/WORK) to Swift", "GAME LOGIC", "NEEDS TESTING", "HIGH",
     "IdlePriority order, eat/sleep throttles, interruptible jobs from CreatureState.java."),
    ("Port hatchery/chicken spawning to Swift", "GAME LOGIC", "NEEDS TESTING", "MEDIUM",
     "ChickenSpawnSystem + ChickenController rules; cooldown tiers already ported."),
]
for title, cat, status, priority, notes in state_tasks:
    if not con.execute("SELECT 1 FROM tasks WHERE title=?", (title,)).fetchone():
        con.execute(
            "INSERT INTO tasks(title,category,weight,status,priority,notes,updated_at) "
            "VALUES (?,?,?,?,?,?,?)", (title, cat, 20, status, priority, notes, now),
        )
con.execute(
    "INSERT INTO activity(ts,level,source,message) VALUES (?,?,?,?)",
    (now, "INFO", "source-code",
     "Ported creature state machine and hatchery spawning; oracle now 25 groups."),
)

ci_title = "GitHub Actions blocked by account billing"
if not con.execute("SELECT 1 FROM problems WHERE title=?", (ci_title,)).fetchone():
    con.execute(
        "INSERT INTO problems(title,severity,status,detail,requested_from_user,updated_at) "
        "VALUES (?,?,?,?,?,?)",
        (ci_title, "CRITICAL", "OPEN",
         "First iOS build run failed before any step: 'The job was not started because recent "
         "account payments have failed or your spending limit needs to be increased'. "
         "Confirmed on both macos-15 and ubuntu-latest, so this is account-level, not a code error.",
         "Fix GitHub Billing & plans (payment method/spending limit), or explicitly authorize "
         "making the repo public; no copyrighted DK2 assets may ever be committed.",
         now),
    )
    con.execute(
        "INSERT INTO activity(ts,level,source,message) VALUES (?,?,?,?)",
        (now, "ERROR", "github-actions",
         "CI run 45936325569 failed before steps: GitHub billing/payment limit blocks all jobs."),
    )

con.commit()
print("DB updated: tasks =", con.execute("SELECT COUNT(*) FROM tasks").fetchone()[0])
con.close()
