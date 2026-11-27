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

con.commit()
print("DB updated: tasks =", con.execute("SELECT COUNT(*) FROM tasks").fetchone()[0])
con.close()
