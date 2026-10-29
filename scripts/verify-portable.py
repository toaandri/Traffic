"""Vérification du backend et du pack Godot distribués, sans imports du backend source."""

import json
import os
import subprocess
import time
from pathlib import Path
from uuid import uuid4

from websockets.sync.client import connect

root = Path(__file__).resolve().parents[1]
release = root / "dist/Traffic"
port = 18766
environment = {**os.environ, "TRAFFIC_PORT": str(port), "TRAFFIC_TOKEN": uuid4().hex,
               "APPDATA": str(release / "data/profile"), "LOCALAPPDATA": str(release / "data/profile")}
backend = subprocess.Popen([str(release / "Traffic.exe"), "--backend", "serve", "--port", str(port)],
                           cwd=release, env=environment, creationflags=subprocess.CREATE_NO_WINDOW)
try:
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        try:
            with connect(f"ws://127.0.0.1:{port}", open_timeout=0.5, close_timeout=0.2):
                break
        except OSError:
            time.sleep(0.2)
    result = subprocess.run([str(release / "runtime/GodotRuntime.exe"), "--headless",
        "--main-pack", str(release / "runtime/traffic.pck"), "--script",
        str(root / "frontend/godot/tests/workflow.gd")], cwd=release, env=environment,
        capture_output=True, text=True, encoding="utf-8", timeout=55)
    print(result.stdout)
    print(result.stderr)
    if result.returncode or "TRAFFIC_WORKFLOW_OK" not in result.stdout:
        raise RuntimeError("Le parcours de la version portable a échoué.")
    print("TRAFFIC_PORTABLE_OK")
finally:
    try:
        with connect(f"ws://127.0.0.1:{port}", open_timeout=1, close_timeout=1) as channel:
            channel.send(json.dumps({"protocol_version": 1, "command": "shutdown", "token": environment["TRAFFIC_TOKEN"]}))
        backend.wait(timeout=8)
    except (OSError, TimeoutError, subprocess.TimeoutExpired):
        backend.kill()
        backend.wait()
