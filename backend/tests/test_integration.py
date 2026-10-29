import asyncio
import json
from pathlib import Path

from traffic.bridge.server import serve_simulation
from traffic.domain.models import Scenario
from traffic.network.grid import generate_grid
from traffic.simulation.session import SimulationSession
from websockets.asyncio.client import connect


def test_sumo_reproducibility():
    scenario = Scenario(network=generate_grid(), vehicles=10)
    results = []
    for index in range(2):
        session = SimulationSession(scenario, Path(f"data/generated/test-repeat-{index}"))
        try:
            results.append([session.step() for _ in range(30)])
        finally:
            session.close()
    for run in results:
        for snapshot in run:
            snapshot.pop("performance", None)
    assert results[0] == results[1]
    assert results[0][-1]["vehicles"]


def test_bridge_pause_reset_and_invalid_command():
    async def next_event(socket):
        while True:
            value = json.loads(await socket.recv())
            if value.get("type") != "status":
                return value

    async def exercise():
        scenario = Scenario(network=generate_grid(), vehicles=10)
        server = asyncio.create_task(
            serve_simulation(scenario, Path("data/generated/test-bridge"), port=18765)
        )
        try:
            for _ in range(100):
                try:
                    socket = await connect("ws://127.0.0.1:18765")
                    break
                except OSError:
                    await asyncio.sleep(0.05)
            else:
                raise AssertionError("Pont indisponible")
            async with socket:
                assert (await next_event(socket))["type"] == "network"
                assert (await next_event(socket))["time"] == 0
                await socket.send(json.dumps({"protocol_version": 1, "command": "play"}))
                state = await next_event(socket)
                assert state["time"] > 0
                await socket.send(json.dumps({"protocol_version": 1, "command": "pause"}))
                await asyncio.sleep(0.2)
                while True:
                    try:
                        await asyncio.wait_for(socket.recv(), timeout=0.15)
                    except TimeoutError:
                        break
                with_pause = server.done()
                assert not with_pause
                await socket.send(json.dumps({"protocol_version": 1, "command": "reset"}))
                state = await next_event(socket)
                if state["type"] == "network":
                    state = await next_event(socket)
                assert state["time"] == 0
                assert not state["vehicles"]
                await socket.send(json.dumps({"protocol_version": 1, "command": "unknown"}))
                assert (await next_event(socket))["type"] == "error"
                invalid = scenario.model_dump()
                invalid["network"] = {"nodes": [], "roads": []}
                await socket.send(
                    json.dumps({"protocol_version": 1, "command": "configure", "scenario": invalid})
                )
                assert (await next_event(socket))["type"] == "error"
                replacement = Scenario(
                    network=generate_grid(2, 2),
                    controller="adaptive",
                    vehicles=4,
                    pedestrians=2,
                    duration=4,
                )
                await socket.send(
                    json.dumps(
                        {
                            "protocol_version": 1,
                            "command": "configure",
                            "scenario": replacement.model_dump(),
                        }
                    )
                )
                network = await next_event(socket)
                assert network["scenario"]["controller"] == "adaptive"
                assert network["geometry"]["crossings"]
                state = await next_event(socket)
                assert state["time"] == 0
                assert state["controller"] == "adaptive"
        finally:
            server.cancel()
            try:
                await server
            except asyncio.CancelledError:
                pass

    asyncio.run(asyncio.wait_for(exercise(), timeout=30))
