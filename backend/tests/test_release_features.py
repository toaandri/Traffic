import json
from pathlib import Path

import pytest
from traffic.domain.models import Crossing, DemandSurge, RoadClosure, Scenario
from traffic.network.grid import generate_grid
from traffic.network.validation import validate_network
from traffic.simulation.session import SimulationSession
from traffic.storage.catalog import ProjectCatalog


def test_density_is_connected_seeded_and_reduced():
    first = generate_grid(4, 4, density=0.6, seed=9)
    assert first == generate_grid(4, 4, density=0.6, seed=9)
    assert len(first.roads) < len(generate_grid(4, 4).roads)
    assert not validate_network(first)


def test_catalog_roundtrip_and_path_rejection():
    catalog = ProjectCatalog(Path("data/generated/test-catalog"))
    scenario = Scenario(
        name="Projet de recette", description="Sauvegarde locale", network=generate_grid()
    )
    identifier = catalog.save(scenario)
    assert catalog.load(identifier) == scenario
    assert any(item["id"] == identifier for item in catalog.list())
    with pytest.raises(ValueError):
        catalog.load("../scenario")


def test_manual_crossing_fixed_timing_and_od():
    network = generate_grid(2, 2)
    network.auto_crossings = False
    network.nodes[0].fixed_green = 18
    network.crossings = [Crossing(id="cross", node="n0_0", roads=["n0_0__n0_1", "n0_1__n0_0"])]
    scenario = Scenario(
        network=network,
        vehicles=4,
        pedestrians=2,
        vehicle_origins=["n0_0__n1_0"],
        vehicle_destinations=["n1_1__n0_1"],
        duration=5,
        step_length=0.5,
    )
    session = SimulationSession(scenario, Path("data/generated/test-manual"))
    try:
        assert session.geometry()["crossings"]
        assert session.signals.decisions["n0_0"]["duration"] == 18
        for _ in range(10):
            session.step()
    finally:
        session.close()


def test_pedestrian_surge_and_explicit_injection_rates():
    scenario = Scenario(
        network=generate_grid(2, 2),
        vehicles=4,
        pedestrians=2,
        duration=6,
        step_length=0.5,
        vehicle_rate=3600,
        pedestrian_rate=1800,
        events=[DemandSurge(time=1, vehicles=0, pedestrians=3)],
    )
    session = SimulationSession(scenario, Path("data/generated/test-ped-surge"))
    try:
        for _ in range(12):
            session.step()
        assert session.result()["configured_pedestrians"] == 5
        assert session.collector.started["pedestrians"] == 5
        assert session.event_log[0]["pedestrians"] == 3
        assert session.result()["collisions"] == 0
    finally:
        session.close()


def test_closure_reopens_and_raw_log_matches_arrival_metrics():
    scenario = Scenario(
        network=generate_grid(2, 2),
        vehicles=4,
        pedestrians=2,
        duration=150,
        step_length=0.5,
        events=[RoadClosure(time=2, road="n0_0__n1_0", duration=3)],
    )
    destination = Path("data/generated/test-raw-closure")
    session = SimulationSession(scenario, destination)
    try:
        sidewalk_permissions = session.connection.lane.getAllowed("n0_0__n1_0_0")
        while session.connection.simulation.getTime() < scenario.duration:
            session.step()
        result = session.result()
        assert [entry["type"] for entry in session.event_log] == ["closure", "reopened"]
        assert not session.closures
        assert session.connection.lane.getAllowed("n0_0__n1_0_0") == sidewalk_permissions
        assert result["collisions"] == 0
    finally:
        session.close()
    arrivals = {}
    for line in (destination / "raw.jsonl").read_text(encoding="utf-8").splitlines():
        record = json.loads(line)
        for identifier in record["departed_vehicles"]:
            arrivals[identifier] = {"start": record["time"] - record["step_length"], "wait": 0}
        for vehicle in record["vehicles"]:
            if vehicle["speed"] < 0.1:
                arrivals[vehicle["id"]]["wait"] += record["step_length"]
        for identifier in record["arrived_vehicles"]:
            arrivals[identifier]["end"] = record["time"]
    finished = [value for value in arrivals.values() if "end" in value]
    assert finished
    assert result["vehicles"]["mean_waiting_time"] == pytest.approx(
        sum(v["wait"] for v in finished) / len(finished)
    )
    assert result["vehicles"]["mean_travel_time"] == pytest.approx(
        sum(v["end"] - v["start"] for v in finished) / len(finished)
    )
