"""Dungeon Keeper II - iOS Port Control Center API."""
from __future__ import annotations

import asyncio
import json
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

import collectors
import db

ROOT = Path(__file__).resolve().parents[2]
DIST = ROOT / "dashboard" / "frontend" / "dist"

clients: set[WebSocket] = set()


async def broadcast() -> None:
    if not clients:
        return
    payload = json.dumps({"type": "state", "state": build_state()})
    for ws in list(clients):
        try:
            await ws.send_text(payload)
        except Exception:  # noqa: BLE001
            clients.discard(ws)


@asynccontextmanager
async def lifespan(app: FastAPI):
    db.init_db()
    db.log("INFO", "system", "Control center started at http://localhost:8080")
    task = asyncio.create_task(heartbeat())
    yield
    task.cancel()
    db.log("INFO", "system", "Control center stopped.")


async def heartbeat() -> None:
    while True:
        await asyncio.sleep(15)
        await broadcast()


app = FastAPI(title="Dungeon Keeper II - iOS Port Control Center", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


def build_state() -> dict:
    with db.connect() as con:
        tasks = db.rows_to_dicts(con.execute(
            "SELECT * FROM tasks ORDER BY id").fetchall())
        activity = db.rows_to_dicts(con.execute(
            "SELECT * FROM activity ORDER BY id DESC LIMIT 200").fetchall())
        problems = db.rows_to_dicts(con.execute(
            "SELECT * FROM problems ORDER BY CASE severity WHEN 'CRITICAL' THEN 0 "
            "WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END, id").fetchall())
        builds = db.rows_to_dicts(con.execute(
            "SELECT * FROM builds ORDER BY id DESC LIMIT 50").fetchall())

    total_weight = sum(t["weight"] for t in tasks) or 1
    earned = sum(t["weight"] * db.STATUS_FRACTION.get(t["status"], 0) for t in tasks)
    counts = {s: 0 for s in db.STATUS_FRACTION}
    for t in tasks:
        counts[t["status"]] = counts.get(t["status"], 0) + 1

    by_category = []
    for cat, weight in db.CATEGORY_WEIGHTS.items():
        ct = [t for t in tasks if t["category"] == cat]
        cw = sum(t["weight"] for t in ct) or 1
        ce = sum(t["weight"] * db.STATUS_FRACTION.get(t["status"], 0) for t in ct)
        by_category.append({
            "category": cat,
            "weight": weight,
            "progress": round(ce / cw * 100),
            "completed": sum(1 for t in ct if t["status"] == "COMPLETED"),
            "total": len(ct),
        })

    git = collectors.git_state()
    output = collectors.output_facts()
    env = collectors.environment()
    blockers = [p for p in problems if p["status"] != "RESOLVED"]
    critical = [p for p in blockers if p["severity"] == "CRITICAL"]

    current = next((t for t in tasks if t["status"] == "IN PROGRESS"), None)
    nxt = next((t for t in tasks if t["status"] == "NOT STARTED"
                and t["priority"] in ("CRITICAL", "HIGH")), None)
    last_build = builds[0] if builds else None

    return {
        "project": "DUNGEON KEEPER II — iOS PORT",
        "overall_progress": round(earned / total_weight * 100, 1),
        "counts": counts,
        "by_category": by_category,
        "current_activity": current["title"] if current else "No active task",
        "next_task": nxt["title"] if nxt else "No queued task",
        "last_successful_build": last_build,
        "ipa": output,
        "on_iphone": False,
        "fidelity": "UNVERIFIED",
        "agent_state": db.get_setting("agent_state", "RUNNING"),
        "environment": env,
        "git": git,
        "repository": collectors.repository_facts(),
        "audit": collectors.audit_facts(),
        "legal": collectors.license_facts(),
        "tasks": tasks,
        "problems": problems,
        "critical_blockers": len(critical),
        "activity": activity,
        "builds": builds,
    }


@app.get("/api/state")
async def state():
    return build_state()


@app.get("/api/tasks")
async def tasks():
    with db.connect() as con:
        return db.rows_to_dicts(con.execute("SELECT * FROM tasks ORDER BY id").fetchall())


class TaskUpdate(BaseModel):
    status: str | None = None
    priority: str | None = None
    notes: str | None = None


@app.patch("/api/tasks/{task_id}")
async def update_task(task_id: int, update: TaskUpdate):
    with db.connect() as con:
        row = con.execute("SELECT * FROM tasks WHERE id=?", (task_id,)).fetchone()
        if not row:
            return JSONResponse({"error": "not found"}, status_code=404)
        con.execute(
            "UPDATE tasks SET status=?, priority=?, notes=?, updated_at=? WHERE id=?",
            (
                update.status or row["status"],
                update.priority or row["priority"],
                update.notes if update.notes is not None else row["notes"],
                db._now(),
                task_id,
            ),
        )
    db.log("INFO", "task-manager",
           f"Task #{task_id} updated: {update.model_dump(exclude_none=True)}")
    await broadcast()
    return {"ok": True}


@app.get("/api/activity")
async def activity(level: str | None = None):
    with db.connect() as con:
        if level and level.upper() in ("ALL",):
            rows = con.execute("SELECT * FROM activity ORDER BY id DESC LIMIT 200").fetchall()
        elif level:
            rows = con.execute(
                "SELECT * FROM activity WHERE level=? ORDER BY id DESC LIMIT 200",
                (level.upper(),)).fetchall()
        else:
            rows = con.execute("SELECT * FROM activity ORDER BY id DESC LIMIT 200").fetchall()
        return db.rows_to_dicts(rows)


@app.get("/api/problems")
async def problems():
    with db.connect() as con:
        return db.rows_to_dicts(con.execute("SELECT * FROM problems").fetchall())


class ProblemUpdate(BaseModel):
    status: str | None = None
    detail: str | None = None


@app.patch("/api/problems/{problem_id}")
async def update_problem(problem_id: int, update: ProblemUpdate):
    with db.connect() as con:
        row = con.execute("SELECT * FROM problems WHERE id=?", (problem_id,)).fetchone()
        if not row:
            return JSONResponse({"error": "not found"}, status_code=404)
        con.execute(
            "UPDATE problems SET status=?, detail=?, updated_at=? WHERE id=?",
            (update.status or row["status"],
             update.detail if update.detail is not None else row["detail"],
             db._now(), problem_id),
        )
    db.log("INFO", "problems", f"Problem #{problem_id} updated: {update.model_dump(exclude_none=True)}")
    await broadcast()
    return {"ok": True}


@app.get("/api/builds")
async def builds():
    with db.connect() as con:
        return db.rows_to_dicts(con.execute(
            "SELECT * FROM builds ORDER BY id DESC LIMIT 50").fetchall())


@app.post("/api/agent/{action}")
async def agent_action(action: str):
    if action not in ("pause", "resume"):
        return JSONResponse({"error": "unknown action"}, status_code=400)
    value = "PAUSED" if action == "pause" else "RUNNING"
    db.set_setting("agent_state", value)
    db.log("INFO", "agent", f"Agent {action}d via control center.")
    await broadcast()
    return {"agent_state": value}


@app.get("/api/report/html", response_class=HTMLResponse)
async def report_html():
    s = build_state()
    rows = "".join(
        f"<tr><td>{t['category']}</td><td>{t['title']}</td><td>{t['status']}</td></tr>"
        for t in s["tasks"])
    return (f"<html><head><meta charset='utf-8'><title>Port Status Report</title></head>"
            f"<body><h1>Dungeon Keeper II — iOS Port</h1>"
            f"<p>Progress: {s['overall_progress']}% (verified)</p>"
            f"<p>Critical blockers: {s['critical_blockers']}</p>"
            f"<p>IPA: {'present' if s['ipa']['ipa_exists'] else 'absent'}</p>"
            f"<table border='1'><tr><th>Category</th><th>Task</th><th>Status</th></tr>{rows}</table>"
            f"</body></html>")


@app.websocket("/ws")
async def ws_endpoint(ws: WebSocket):
    await ws.accept()
    clients.add(ws)
    try:
        await ws.send_text(json.dumps({"type": "state", "state": build_state()}))
        while True:
            await ws.receive_text()
    except WebSocketDisconnect:
        clients.discard(ws)


if DIST.exists():
    app.mount("/assets", StaticFiles(directory=DIST / "assets"), name="assets")


@app.get("/{full_path:path}")
async def spa(full_path: str):
    index = DIST / "index.html"
    if index.exists():
        return FileResponse(index)
    return HTMLResponse(
        "<html><body><h1>Dashboard frontend not built</h1>"
        "<p>Run: cd dashboard/frontend && npm install && npm run build</p></body></html>",
        status_code=503,
    )


if __name__ == "__main__":
    import os
    import uvicorn
    uvicorn.run(app, host="127.0.0.1",
                port=int(os.getenv("CONTROL_CENTER_PORT", "8080")), log_level="info")
