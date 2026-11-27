"""Collectors that read real state from the host and the Git repository."""
from __future__ import annotations

import json
import os
import platform
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPO = ROOT / "OpenKeeper"


def _run(args: list[str], cwd: Path | None = None, timeout: int = 20) -> str:
    try:
        p = subprocess.run(args, cwd=cwd, capture_output=True, text=True,
                           timeout=timeout, errors="replace")
        return (p.stdout or p.stderr).strip()
    except Exception as exc:  # noqa: BLE001 - reported honestly
        return f"ERROR: {exc}"


def tool_version(cmd: str, args: list[str]) -> str:
    path = shutil.which(cmd)
    if not path:
        return "NOT FOUND"
    out = _run([cmd] + args)
    return out.splitlines()[0] if out else path


def environment() -> dict:
    return {
        "os": platform.platform(),
        "machine": platform.machine(),
        "processor": platform.processor() or "unknown",
        "hostname": platform.node(),
        "python": platform.python_version(),
        "git": tool_version("git", ["--version"]),
        "java": tool_version("java", ["-version"]),
        "gradle": "NOT FOUND" if not shutil.which("gradle") else tool_version("gradle", ["--version"]),
        "xcodebuild": "NOT FOUND" if not shutil.which("xcodebuild") else "AVAILABLE",
        "swift": "NOT FOUND" if not shutil.which("swift") else tool_version("swift", ["--version"]),
        "xcode_expected": platform.system() != "Darwin",
        "disk_free_gb": round(shutil.disk_usage(ROOT).free / (1024 ** 3), 1),
    }


def git_state() -> dict:
    if not (REPO / ".git").exists():
        return {"available": False, "reason": "OpenKeeper repository not cloned"}
    return {
        "available": True,
        "branch": _run(["git", "rev-parse", "--abbrev-ref", "HEAD"], REPO),
        "head": _run(["git", "rev-parse", "--short", "HEAD"], REPO),
        "commit_message": _run(["git", "log", "-1", "--pretty=%s"], REPO),
        "commit_date": _run(["git", "log", "-1", "--pretty=%ci"], REPO),
        "dirty_files": [l for l in _run(["git", "status", "--porcelain"], REPO).splitlines() if l],
        "remote": _run(["git", "remote", "get-url", "origin"], REPO),
    }


def repository_facts() -> dict:
    files = list(REPO.rglob("*")) if REPO.exists() else []
    java = [f for f in files if f.suffix == ".java"]
    assets = REPO / "assets"
    asset_size = 0
    asset_count = 0
    if assets.exists():
        for p in assets.rglob("*"):
            if p.is_file():
                asset_count += 1
                asset_size += p.stat().st_size
    return {
        "total_files": len([f for f in files if f.is_file()]),
        "java_files": len(java),
        "asset_files": asset_count,
        "asset_size_mb": round(asset_size / (1024 ** 2), 1),
        "has_gradlew": (REPO / "gradlew").exists(),
        "license_files": [p.name for p in REPO.glob("*LICENSE*")] + [p.name for p in REPO.glob("*license*")],
    }


def audit_facts() -> dict:
    """Read the technical audit report if it exists, never synthesize it."""
    path = ROOT / "IOS_PORT_TECHNICAL_AUDIT.md"
    if not path.exists():
        return {"available": False}
    return {
        "available": True,
        "path": str(path.relative_to(ROOT)).replace("\\", "/"),
        "bytes": path.stat().st_size,
        "modified": __import__("datetime").datetime.fromtimestamp(
            path.stat().st_mtime).isoformat(timespec="seconds"),
    }


def output_facts() -> dict:
    out = ROOT / "output"
    ipa = out / "DungeonKeeperII.ipa"
    report = out / "BUILD_REPORT.md"
    return {
        "ipa_exists": ipa.exists(),
        "ipa_bytes": ipa.stat().st_size if ipa.exists() else 0,
        "build_report_exists": report.exists(),
    }


def license_facts() -> dict:
    path = ROOT / "LEGAL_AND_LICENSE_REPORT.md"
    return {"available": path.exists()}
