"""Lanceur GUI local : un moteur privé par application, arrêt à la fermeture."""

import ctypes
import json
import os
import socket
import subprocess
import sys
import time
import traceback
from pathlib import Path
from uuid import uuid4

from websockets.sync.client import connect

from traffic.process import cli_command


def main():
    frozen = getattr(sys, "frozen", False)
    root = Path(sys.executable).parent if frozen else Path(__file__).resolve().parents[3]
    os.chdir(root)
    (root / "data/logs").mkdir(parents=True, exist_ok=True)
    if frozen:
        os.environ["SUMO_HOME"] = str(root / "sumo")
    if len(sys.argv) > 1 and sys.argv[1] == "--backend":
        sys.argv = [sys.argv[0], *sys.argv[2:]]
        if frozen:
            log = Path(os.environ.get("TRAFFIC_LOG", str(root / "data/logs/backend.log")))
            log.parent.mkdir(parents=True, exist_ok=True)
            sys.stdout = sys.stderr = log.open("w", encoding="utf-8", buffering=1)
        from traffic.cli import main as backend_main

        try:
            backend_main()
        except Exception:  # noqa: BLE001 -- frontière du processus : journaliser toute panne
            traceback.print_exc()
            raise SystemExit(1) from None
        return
    if frozen:
        os.environ["SUMO_HOME"] = str(root / "sumo")
    else:
        # Source : .venv dépend du Python installé sur cette machine.
        root = Path(__file__).resolve().parents[3]
    engine = root / (
        "runtime/GodotRuntime.exe" if frozen else ".tools/godot/Godot_v4.7.2-stable_win64.exe"
    )
    if not engine.is_file():
        raise RuntimeError(
            "Moteur 3D absent. Réinstaller Traffic ou exécuter scripts/install-godot.ps1."
        )
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    environment = {
        **os.environ,
        "TRAFFIC_PORT": str(port),
        "SUMO_HOME": os.environ.get("SUMO_HOME", ""),
        "APPDATA": str(root / "data/profile"),
        "LOCALAPPDATA": str(root / "data/profile"),
        "TRAFFIC_TOKEN": uuid4().hex,
    }
    if not environment["SUMO_HOME"]:
        environment.pop("SUMO_HOME")
    logs = root / "data/logs"
    run_id = uuid4().hex[:12]
    output = root / f"data/generated/desktop-{run_id}"
    environment["TRAFFIC_LOG"] = str(logs / f"backend-{run_id}.log")
    backend = None
    try:
        with (logs / f"backend-{run_id}.log").open("w", encoding="utf-8") as backend_log:
            backend = subprocess.Popen(
                cli_command(
                    "serve",
                    "--scenario",
                    "data/scenarios/crossing_lab.json",
                    "--port",
                    str(port),
                    "--output",
                    str(output),
                ),
                env=environment,
                stdout=backend_log,
                stderr=subprocess.STDOUT,
                creationflags=subprocess.CREATE_NO_WINDOW,
            )
            deadline = time.monotonic() + 40
            while time.monotonic() < deadline:
                if backend.poll() is not None:
                    raise RuntimeError(f"Le moteur de simulation ne démarre pas. Journal : {logs}")
                try:
                    with connect(f"ws://127.0.0.1:{port}", open_timeout=0.5, close_timeout=0.2):
                        break
                except OSError:
                    time.sleep(0.2)
            else:
                raise RuntimeError("Démarrage du moteur trop long. Consulter data/logs.")
            command = (
                [str(engine), "--main-pack", str(root / "runtime/traffic.pck")]
                if frozen
                else [str(engine), "--path", str(root / "frontend/godot")]
            )
            if "--self-test" in sys.argv:
                command.extend(["--headless", "--quit-after", "180"])
            with (logs / f"frontend-{run_id}.log").open("w", encoding="utf-8") as frontend_log:
                frontend = subprocess.Popen(
                    command, env=environment, stdout=frontend_log, stderr=subprocess.STDOUT
                )
                frontend.wait()
    finally:
        if backend and backend.poll() is None:
            try:
                with connect(f"ws://127.0.0.1:{port}", open_timeout=2, close_timeout=1) as channel:
                    channel.send(
                        json.dumps(
                            {
                                "protocol_version": 1,
                                "command": "shutdown",
                                "token": environment["TRAFFIC_TOKEN"],
                            }
                        )
                    )
                backend.wait(timeout=8)
            except (OSError, TimeoutError, subprocess.TimeoutExpired):
                backend.kill()
                backend.wait()


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        if sys.platform == "win32":
            ctypes.windll.user32.MessageBoxW(
                None, str(error), "Traffic — démarrage impossible", 0x10
            )
        else:
            raise
