import asyncio
import json
import os
import subprocess
from pathlib import Path
from uuid import uuid4

import traci
from websockets.asyncio.server import serve
from websockets.exceptions import ConnectionClosed

from traffic.domain.models import Scenario
from traffic.network.grid import generate_grid
from traffic.network.validation import validate_network
from traffic.process import cli_command
from traffic.simulation.session import SimulationSession
from traffic.storage.catalog import ProjectCatalog, list_history
from traffic.storage.projects import load_scenario, save_scenario


async def serve_simulation(scenario: Scenario, directory: Path, port: int = 8765):
    clients = set()
    revision = 0
    session = SimulationSession(scenario, directory / "live-0")
    paused = True
    speed = 1.0
    comparison_task = None
    catalog = ProjectCatalog()
    project_id = None
    shutdown = asyncio.Event()

    async def broadcast(message):
        payload = json.dumps(message)
        for client in tuple(clients):
            try:
                await client.send(payload)
            except ConnectionClosed:
                clients.discard(client)

    def network_message():
        return {
            "protocol_version": 1,
            "type": "network",
            "network": scenario.network.model_dump(),
            "scenario": scenario.model_dump(),
            "geometry": session.geometry(),
            "project_id": project_id,
        }

    def job_finished(task):
        if task.cancelled():
            return
        error = task.exception()
        if error is not None:
            asyncio.create_task(
                broadcast(
                    {
                        "type": "error",
                        "message": f"Le calcul n'a pas pu démarrer ou terminer : {error}",
                    }
                )
            )

    async def replace(candidate: Scenario):
        nonlocal paused, session, scenario, revision
        # Créer et valider le nouvel état avant de remplacer la session courante.
        next_revision = revision + 1
        replacement = SimulationSession(candidate, directory / f"live-{next_revision}")
        previous = session
        session = replacement
        scenario = candidate
        revision = next_revision
        paused = True
        previous.close()
        await broadcast(network_message())
        await broadcast(session.snapshot())

    async def compare(seeds, mode="compare"):
        destination = Path("data/results") / f"{mode}-{uuid4().hex[:12]}"
        destination.mkdir(parents=True, exist_ok=True)
        save_scenario(scenario, directory / "comparison-input.json")
        process = await asyncio.create_subprocess_exec(
            *cli_command(mode),
            "--scenario",
            str(directory / "comparison-input.json"),
            "--output",
            str(destination),
            "--seeds",
            *map(str, seeds),
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            env={
                **os.environ,
                "TRAFFIC_LOG": str((destination / "process.log").resolve()),
                "TRAFFIC_CANCEL_FILE": str((destination / "cancel.request").resolve()),
            },
        )
        try:

            async def read_progress():
                while line := await process.stdout.readline():
                    await broadcast(
                        {"type": "progress", "message": line.decode(errors="replace").strip()}
                    )

            reader = asyncio.create_task(read_progress())
            stderr = await process.stderr.read()
            await process.wait()
            await reader
            if process.returncode:
                await broadcast(
                    {
                        "type": "error",
                        "message": "Échec de comparaison : "
                        + stderr.decode(errors="replace")[-1500:],
                    }
                )
            else:
                report = json.loads(
                    (
                        destination / ("comparison.json" if mode == "compare" else "stress.json")
                    ).read_text(encoding="utf-8")
                )
                if isinstance(report, list):
                    report = report[-1]
                await broadcast(
                    {
                        "type": "comparison",
                        "aggregates": report["aggregates"],
                        "improvement": report["vehicle_wait_improvement_percent"],
                        "directory": str(destination.resolve()),
                        "seeds": seeds,
                        "report": report,
                        "mode": mode,
                    }
                )
        finally:
            if process.returncode is None:
                (destination / "cancel.request").touch()
                try:
                    await asyncio.wait_for(process.wait(), timeout=5)
                except TimeoutError:
                    process.terminate()
                    await process.wait()

    async def handler(socket):
        nonlocal paused, speed, comparison_task, project_id
        clients.add(socket)
        try:
            await socket.send(json.dumps(network_message()))
            await socket.send(json.dumps(session.snapshot()))
            async for message in socket:
                try:
                    command = json.loads(message)
                    if command.get("protocol_version") != 1:
                        raise ValueError("Version de protocole inconnue.")
                    action = command.get("command")
                    if action == "play":
                        paused = session.snapshot()["time"] >= scenario.duration
                    elif action == "shutdown":
                        token = os.environ.get("TRAFFIC_TOKEN")
                        if not token or command.get("token") != token:
                            raise ValueError("Commande réservée au lanceur de cette application.")
                        shutdown.set()
                    elif action == "pause":
                        paused = True
                    elif action == "validate":
                        candidate = Scenario.model_validate(command["scenario"])
                        errors = validate_network(candidate.network)
                        await socket.send(json.dumps({"type": "validation", "errors": errors}))
                    elif action == "catalog":
                        await socket.send(
                            json.dumps(
                                {
                                    "type": "catalog",
                                    "projects": catalog.list(),
                                    "history": list_history(),
                                }
                            )
                        )
                    elif action == "save_project":
                        candidate = Scenario.model_validate(command["scenario"])
                        errors = validate_network(candidate.network)
                        if errors:
                            raise ValueError("; ".join(errors))
                        project_id = catalog.save(candidate, command.get("id"))
                        await socket.send(
                            json.dumps(
                                {"type": "saved", "id": project_id, "projects": catalog.list()}
                            )
                        )
                    elif action == "load_project":
                        candidate = catalog.load(command["id"])
                        previous_id = project_id
                        project_id = command["id"]
                        try:
                            await replace(candidate)
                        except (ValueError, OSError, subprocess.CalledProcessError):
                            project_id = previous_id
                            raise
                    elif action == "example":
                        name = command.get("name")
                        if name not in ("grid", "crossing_lab", "congestion"):
                            raise ValueError("Exemple inconnu.")
                        project_id = None
                        await replace(load_scenario(Path("data/scenarios") / f"{name}.json"))
                    elif action == "import":
                        candidate = Scenario.model_validate(command["scenario"])
                        project_id = None
                        await replace(candidate)
                    elif action == "cancel_comparison":
                        if comparison_task and not comparison_task.done():
                            comparison_task.cancel()
                            try:
                                await comparison_task
                            except asyncio.CancelledError:
                                pass
                            await broadcast({"type": "notice", "message": "Comparaison annulée."})
                    elif action == "reset":
                        await replace(scenario)
                    elif action == "new":
                        project_id = None
                        await replace(
                            Scenario(
                                name="Nouvelle ville",
                                network=generate_grid(2, 2),
                                vehicles=30,
                                pedestrians=12,
                                duration=180,
                                step_length=0.5,
                            )
                        )
                    elif action == "speed" and command.get("value") in (0.5, 1, 2):
                        speed = float(command["value"])
                    elif action == "configure":
                        await replace(Scenario.model_validate(command["scenario"]))
                    elif action == "generate":
                        rows, columns = command.get("rows", 3), command.get("columns", 3)
                        if (
                            type(rows) is not int
                            or type(columns) is not int
                            or not (2 <= rows <= 6 and 2 <= columns <= 6)
                        ):
                            raise ValueError(
                                "La grille doit avoir entre 2 et 6 lignes et colonnes."
                            )
                        candidate = scenario.model_copy(deep=True)
                        spacing = float(command.get("spacing", 100))
                        if not 60 <= spacing <= 200:
                            raise ValueError("L'espacement doit être compris entre 60 et 200 m.")
                        candidate.network = generate_grid(
                            rows, columns, spacing, float(command.get("density", 1)), candidate.seed
                        )
                        candidate.vehicle_origins = []
                        candidate.vehicle_destinations = []
                        candidate.pedestrian_origins = []
                        candidate.pedestrian_destinations = []
                        candidate.events = [
                            event for event in candidate.events if hasattr(event, "vehicles")
                        ]
                        await replace(candidate)
                    elif action == "save":
                        save_scenario(scenario, Path("data/scenarios/saved.json"))
                        await socket.send(
                            json.dumps(
                                {
                                    "type": "notice",
                                    "message": "Projet sauvegardé dans data/scenarios/saved.json",
                                }
                            )
                        )
                    elif action == "export":
                        destination = Path("data/results") / f"export-{uuid4().hex[:12]}"
                        session.export_results(destination)
                        await socket.send(
                            json.dumps(
                                {
                                    "type": "notice",
                                    "message": f"Mesures exportées dans {destination}",
                                    "directory": str(destination.resolve()),
                                }
                            )
                        )
                    elif action == "load":
                        await replace(load_scenario(Path("data/scenarios/saved.json")))
                    elif action in ("compare", "stress"):
                        if comparison_task and not comparison_task.done():
                            raise ValueError("Une comparaison est déjà en cours.")
                        seeds = command.get(
                            "seeds", [scenario.seed, scenario.seed + 1, scenario.seed + 2]
                        )
                        if (
                            not isinstance(seeds, list)
                            or not 1 <= len(seeds) <= 10
                            or any(
                                type(seed) is not int or not 0 <= seed <= 2147483647
                                for seed in seeds
                            )
                            or len(set(seeds)) != len(seeds)
                        ):
                            raise ValueError("Fournir de 1 à 10 graines distinctes valides.")
                        paused = True
                        comparison_task = asyncio.create_task(compare(seeds, action))
                        comparison_task.add_done_callback(job_finished)
                        await broadcast(
                            {"type": "notice", "message": "Comparaison fixe/adaptatif en cours…"}
                        )
                    else:
                        raise ValueError("Commande inconnue ou valeur invalide.")
                    await broadcast(
                        {
                            "type": "status",
                            "paused": paused,
                            "speed": speed,
                            "finished": session.snapshot()["finished"],
                        }
                    )
                except (
                    ValueError,
                    TypeError,
                    AttributeError,
                    KeyError,
                    OSError,
                    subprocess.CalledProcessError,
                    traci.TraCIException,
                ) as error:
                    await socket.send(json.dumps({"type": "error", "message": str(error)}))
        except ConnectionClosed:
            pass
        finally:
            clients.discard(socket)

    try:
        async with serve(handler, "127.0.0.1", port, max_size=1024 * 1024):
            print(f"Pont prêt sur ws://127.0.0.1:{port} — démarrer depuis Godot.", flush=True)
            while not shutdown.is_set():
                if clients and not paused:
                    try:
                        snapshot = session.step()
                        snapshot["paused"] = False
                        await broadcast(snapshot)
                        if snapshot["finished"]:
                            paused = True
                            session.export_results(session.directory)
                            await broadcast(
                                {"type": "status", "paused": True, "finished": True, "speed": speed}
                            )
                    except (traci.TraCIException, RuntimeError, OSError) as error:
                        paused = True
                        await broadcast({"type": "error", "message": str(error)})
                await asyncio.sleep(scenario.step_length / speed)
    finally:
        if comparison_task and not comparison_task.done():
            comparison_task.cancel()
            try:
                await comparison_task
            except asyncio.CancelledError:
                pass
        session.close()
