"""Store the Assets repository token as an encrypted Actions secret.

Uses the user's already configured Git credential manager. The token is never
printed or written to disk.
"""
from __future__ import annotations

import base64
import json
import subprocess
import urllib.request

OWNER_REPO = "Lolicks/dungeonkeeperii-ios-port"
SECRET_NAME = "ASSETS_TOKEN"


def github_token() -> str:
    out = subprocess.run(
        ["git", "credential", "fill"],
        input="protocol=https\nhost=github.com\n\n",
        capture_output=True, text=True, timeout=15,
    ).stdout
    return next((line[9:] for line in out.splitlines()
                 if line.startswith("password=")), "")


def api(url: str, token: str, method: str = "GET", payload: dict | None = None):
    data = json.dumps(payload).encode() if payload else None
    req = urllib.request.Request(
        url, data=data, method=method,
        headers={
            "Authorization": f"token {token}",
            "Accept": "application/vnd.github+json",
            "User-Agent": "dk2-ios-control-center",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read().decode()
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode()
        raise SystemExit(f"{exc.code} {method} {url}: {detail}") from exc


def main() -> None:
    from nacl.public import PublicKey, SealedBox

    token = github_token()
    if not token:
        raise SystemExit("No cached GitHub credential")
    key_info = api(
        f"https://api.github.com/repos/{OWNER_REPO}/actions/secrets/public-key", token)
    public_key = PublicKey(base64.b64decode(key_info["key"]))
    encrypted = SealedBox(public_key).encrypt(token.encode("utf-8"))
    api(
        f"https://api.github.com/repos/{OWNER_REPO}/actions/secrets/{SECRET_NAME}",
        token, method="PUT",
        payload={"key_id": key_info["key_id"],
                 "encrypted_value": base64.b64encode(encrypted).decode("utf-8")},
    )
    print(f"SECRET {SECRET_NAME} stored in {OWNER_REPO}")


if __name__ == "__main__":
    main()
