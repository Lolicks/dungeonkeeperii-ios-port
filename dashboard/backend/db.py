"""SQLite storage for the iOS port control center.

All data written here is produced by real checks or by explicit user/agent
actions. The dashboard never invents progress.
"""
from __future__ import annotations

import json
import sqlite3
import threading
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB_PATH = ROOT / "database" / "control_center.db"

_lock = threading.RLock()  # reentrant: init_db() logs while already holding the lock

SCHEMA = """
CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    weight REAL NOT NULL DEFAULT 1,
    status TEXT NOT NULL DEFAULT 'NOT STARTED',
    priority TEXT NOT NULL DEFAULT 'MEDIUM',
    notes TEXT NOT NULL DEFAULT '',
    updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS activity (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts TEXT NOT NULL,
    level TEXT NOT NULL,
    source TEXT NOT NULL,
    message TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS problems (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    severity TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'OPEN',
    detail TEXT NOT NULL DEFAULT '',
    requested_from_user TEXT NOT NULL DEFAULT '',
    updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS builds (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT NOT NULL,
    status TEXT NOT NULL,
    detail TEXT NOT NULL DEFAULT '',
    artifact TEXT NOT NULL DEFAULT '',
    ts TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
"""

# Weight groups mirror section 20 of the project brief.
CATEGORY_WEIGHTS = {
    "SOURCE AUDIT": 5,
    "IOS RUNTIME": 15,
    "GRAPHICS ENGINE": 15,
    "GAME RESOURCES": 10,
    "GAME LOGIC": 20,
    "TOUCH CONTROLS": 10,
    "CAMPAIGN": 10,
    "OPTIMIZATION": 5,
    "TESTING": 5,
    "IPA & INSTALL": 5,
}

STATUS_FRACTION = {
    "NOT STARTED": 0.0,
    "BLOCKED": 0.0,
    "IN PROGRESS": 0.25,
    "NEEDS TESTING": 0.75,
    "COMPLETED": 1.0,
}

# Seeded from the actual work already performed by the agent, not from a
# desired end state. Only verifiable items are marked COMPLETED.
SEED_TASKS = [
    ("Verify working environment (Git/Java/Gradle/Xcode)", "SOURCE AUDIT", "COMPLETED", "HIGH",
     "Verified on host: Windows, Git 2.47, Java 1.8.0_401, no Gradle, no Xcode, no Swift."),
    ("Clone OpenKeeper source repository", "SOURCE AUDIT", "COMPLETED", "HIGH",
     "Cloned https://github.com/tonihele/OpenKeeper into OpenKeeper/."),
    ("Create ios-port branch", "SOURCE AUDIT", "COMPLETED", "HIGH",
     "Branch ios-port created from master; pristine master kept as backup."),
    ("Run technical audit of source tree", "SOURCE AUDIT", "IN PROGRESS", "HIGH", ""),
    ("Write IOS_PORT_TECHNICAL_AUDIT.md", "SOURCE AUDIT", "NOT STARTED", "HIGH", ""),
    ("Set up local development control center", "SOURCE AUDIT", "NOT STARTED", "MEDIUM", ""),

    ("Select Java runtime strategy for iOS", "IOS RUNTIME", "NOT STARTED", "CRITICAL", ""),
    ("Evaluate AOT / native-image compatibility", "IOS RUNTIME", "NOT STARTED", "CRITICAL", ""),
    ("Replace JVM-only runtime assumptions", "IOS RUNTIME", "NOT STARTED", "CRITICAL", ""),
    ("ARM64 target configuration", "IOS RUNTIME", "NOT STARTED", "HIGH", ""),
    ("Design iOS application layer in Swift", "IOS RUNTIME", "NOT STARTED", "HIGH", ""),
    ("Implement fixed-timestep update loop", "IOS RUNTIME", "NOT STARTED", "MEDIUM", ""),
    ("Native iOS integration layer", "IOS RUNTIME", "NOT STARTED", "MEDIUM", ""),

    ("jMonkeyEngine dependency compatibility audit", "GRAPHICS ENGINE", "NOT STARTED", "CRITICAL", ""),
    ("Select Metal-capable rendering backend", "GRAPHICS ENGINE", "NOT STARTED", "CRITICAL", ""),
    ("Replace desktop GL/GLFW native bindings", "GRAPHICS ENGINE", "NOT STARTED", "CRITICAL", ""),
    ("Minimal iOS 3D rendering prototype", "GRAPHICS ENGINE", "NOT STARTED", "CRITICAL", ""),
    ("Load first original 3D scene", "GRAPHICS ENGINE", "NOT STARTED", "HIGH", ""),
    ("Materials, lighting and shadows", "GRAPHICS ENGINE", "NOT STARTED", "MEDIUM", ""),
    ("Animation support", "GRAPHICS ENGINE", "NOT STARTED", "MEDIUM", ""),
    ("Resource loading pipeline", "GRAPHICS ENGINE", "NOT STARTED", "HIGH", ""),

    ("Locate/obtain original Dungeon Keeper II assets", "GAME RESOURCES", "NOT STARTED", "CRITICAL",
     "Original game assets are not present in OpenKeeper and are not redistributable."),
    ("Asset conversion and packaging", "GAME RESOURCES", "NOT STARTED", "HIGH", ""),
    ("3D models import", "GAME RESOURCES", "NOT STARTED", "HIGH", ""),
    ("Texture and audio assets import", "GAME RESOURCES", "NOT STARTED", "MEDIUM", ""),

    ("Preserve core game rules from OpenKeeper", "GAME LOGIC", "NOT STARTED", "HIGH", ""),
    ("Creatures and creatures needs", "GAME LOGIC", "NOT STARTED", "HIGH", ""),
    ("Rooms and construction", "GAME LOGIC", "NOT STARTED", "HIGH", ""),
    ("Economy and resources", "GAME LOGIC", "NOT STARTED", "HIGH", ""),
    ("Spells and combat", "GAME LOGIC", "NOT STARTED", "HIGH", ""),
    ("Save/load system", "GAME LOGIC", "NOT STARTED", "MEDIUM", ""),
    ("Creature AI", "GAME LOGIC", "NOT STARTED", "HIGH", ""),
    ("Pathfinding", "GAME LOGIC", "NOT STARTED", "HIGH", ""),
    ("Multiplayer", "GAME LOGIC", "NOT STARTED", "LOW", ""),

    ("Touch camera controls", "TOUCH CONTROLS", "NOT STARTED", "HIGH", ""),
    ("Touch selection and orders", "TOUCH CONTROLS", "NOT STARTED", "HIGH", ""),
    ("Gesture handling and safe areas", "TOUCH CONTROLS", "NOT STARTED", "MEDIUM", ""),
    ("Landscape iPhone UI", "TOUCH CONTROLS", "NOT STARTED", "MEDIUM", ""),
    ("HUD and menus", "TOUCH CONTROLS", "NOT STARTED", "MEDIUM", ""),

    ("Port original campaign data", "CAMPAIGN", "NOT STARTED", "HIGH", ""),
    ("Campaign missions verification", "CAMPAIGN", "NOT STARTED", "MEDIUM", ""),

    ("CPU/GPU profiling on device", "OPTIMIZATION", "NOT STARTED", "HIGH", ""),
    ("Draw call and memory optimization", "OPTIMIZATION", "NOT STARTED", "MEDIUM", ""),
    ("Target 60 FPS on supported iPhone", "OPTIMIZATION", "NOT STARTED", "HIGH", ""),

    ("Unit tests for ported systems", "TESTING", "NOT STARTED", "MEDIUM", ""),
    ("Integration tests", "TESTING", "NOT STARTED", "MEDIUM", ""),
    ("iOS Simulator testing", "TESTING", "NOT STARTED", "HIGH", ""),
    ("Real iPhone testing", "TESTING", "NOT STARTED", "CRITICAL",
     "Requires a physical iPhone and Apple signing."),

    ("Xcode project and signing configuration", "IPA & INSTALL", "NOT STARTED", "CRITICAL",
     "Requires macOS + Xcode + Apple Developer credentials."),
    ("Build development IPA", "IPA & INSTALL", "NOT STARTED", "CRITICAL", ""),
    ("Install and launch on real iPhone", "IPA & INSTALL", "NOT STARTED", "CRITICAL", ""),
    ("Build report and final verification", "IPA & INSTALL", "NOT STARTED", "HIGH", ""),
]

SEED_PROBLEMS = [
    ("No macOS host / Xcode available", "CRITICAL", "OPEN",
     "Host is Windows. Xcode, xcodebuild, Swift toolchain and iOS SDK are unavailable. "
     "An IPA cannot be compiled, signed or installed from this machine.",
     "A macOS build machine with Xcode (or a CI macOS runner) is required."),
    ("No Apple Developer credentials", "CRITICAL", "OPEN",
     "No signing certificate, provisioning profile or Apple ID team was provided.",
     "Apple Developer account + signing assets, or confirmation to use a local development team."),
    ("Original Dungeon Keeper II assets not present", "CRITICAL", "OPEN",
     "OpenKeeper contains code, not the copyrighted original game assets. A faithful port "
     "cannot load the original scenes without legally obtained assets.",
     "Info on which asset source the user is authorized to use."),
    ("No physical iPhone for verification", "CRITICAL", "OPEN",
     "No device connected to this host; iOS Simulator also requires macOS.",
     "Access to a test device on a Mac, or acceptance of simulator-only verification."),
    ("Java runtime mismatch on host", "HIGH", "OPEN",
     "Host has Java 1.8.0_401; OpenKeeper's build may require a newer JDK. "
     "iOS does not support a standard JVM at all; a native/AOT strategy is needed.",
     "Decision on target runtime strategy (native reimplementation vs AOT toolchain)."),
    ("Gradle not installed on host", "MEDIUM", "OPEN",
     "gradle is not on PATH. The repository ships gradlew, which can bootstrap Gradle if a "
     "compatible JDK is available.",
     ""),
]


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


@contextmanager
def connect():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    with _lock:
        con = sqlite3.connect(DB_PATH, timeout=10)
        con.row_factory = sqlite3.Row
        try:
            yield con
            con.commit()
        finally:
            con.close()


def init_db() -> None:
    with connect() as con:
        con.executescript(SCHEMA)
        count = con.execute("SELECT COUNT(*) FROM tasks").fetchone()[0]
        if count == 0:
            con.executemany(
                "INSERT INTO tasks(title,category,weight,status,priority,notes,updated_at) "
                "VALUES (?,?,?,?,?,?,?)",
                [(t, c, CATEGORY_WEIGHTS.get(c, 1), s, p, n, _now())
                 for t, c, s, p, n in SEED_TASKS],
            )
            con.executemany(
                "INSERT INTO problems(title,severity,status,detail,requested_from_user,updated_at) "
                "VALUES (?,?,?,?,?,?)",
                [(t, s, st, d, r, _now()) for t, s, st, d, r in SEED_PROBLEMS],
            )
            con.execute(
                "INSERT OR REPLACE INTO settings(key,value) VALUES ('agent_state','RUNNING')")
    # Log after the write transaction is committed; nested connections cannot
    # write into the same SQLite file while the seeding transaction is open.
    log("INFO", "system", "Control center database initialized with real project state.")
    log("INFO", "system", "Hard blockers recorded; no progress is fabricated.")


def log(level: str, source: str, message: str) -> None:
    with connect() as con:
        con.execute(
            "INSERT INTO activity(ts,level,source,message) VALUES (?,?,?,?)",
            (_now(), level, source, message),
        )


def rows_to_dicts(rows) -> list[dict]:
    return [dict(r) for r in rows]


def get_setting(key: str, default: str = "") -> str:
    with connect() as con:
        r = con.execute("SELECT value FROM settings WHERE key=?", (key,)).fetchone()
        return r["value"] if r else default


def set_setting(key: str, value: str) -> None:
    with connect() as con:
        con.execute("INSERT OR REPLACE INTO settings(key,value) VALUES (?,?)", (key, value))
