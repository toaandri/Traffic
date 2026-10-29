import math
from pathlib import Path

import pytest
from pydantic import ValidationError
from traffic.controllers.safety import validate_phase
from traffic.domain.models import DemandSurge, Node, Scenario
from traffic.experiments.compare import run_comparison
from traffic.metrics.collector import MetricsCollector
from traffic.network.grid import generate_grid
from traffic.simulation.session import SimulationSession


def test_invalid_coordinates_and_event_are_rejected():
    with pytest.raises(ValidationError):
        Node(id="unsafe", x=math.nan, y=0)
    with pytest.raises(ValidationError):
        Scenario(network=generate_grid(), duration=10, events=[DemandSurge(time=10)])


def test_metrics_distinguish_finished_and_unfinished():
    collector = MetricsCollector(1)
    collector.update(
        1, [{"id": "a", "speed": 0}, {"id": "b", "speed": 3}], [], {"a", "b"}, set(), set(), set()
    )
    collector.update(2, [{"id": "b", "speed": 0}], [], set(), set(), {"a"}, set())
    values = collector.summary(2)["vehicles"]
    assert values["arrived"] == 1
    assert values["unfinished"] == 1
    assert values["mean_waiting_time"] == 1
    assert values["mean_travel_time"] == 2
    assert values["unfinished_waiting_time"] == 1


@pytest.mark.parametrize("controller", ["fixed", "adaptive"])
def test_pedestrians_safe_phases_and_surge(controller):
    scenario = Scenario(
        network=generate_grid(2, 2),
        controller=controller,
        vehicles=4,
        pedestrians=3,
        duration=12,
        step_length=0.5,
        events=[DemandSurge(time=1, vehicles=3)],
    )
    session = SimulationSession(scenario, Path(f"data/generated/test-lab-{controller}"))
    try:
        assert session.geometry()["crossings"]
        seen_people = set()
        positions = {}
        moved = False
        while session.connection.simulation.getTime() < scenario.duration:
            snapshot = session.step()
            for person in snapshot["pedestrians"]:
                seen_people.add(person["id"])
                position = (person["x"], person["y"])
                moved |= person["id"] in positions and positions[person["id"]] != position
                positions[person["id"]] = position
            for light in snapshot["lights"]:
                plan = session.signals.plans[light["id"]]
                validate_phase(light["state"], {tuple(pair) for pair in plan["conflicts"]})
                green_pedestrians = any(
                    light["state"][int(i)] == "G" and link["pedestrian"]
                    for i, link in plan["links"].items()
                )
                if green_pedestrians:
                    assert all(
                        light["state"][int(i)] == "r"
                        for i, link in plan["links"].items()
                        if not link["pedestrian"]
                    )
        assert seen_people
        assert moved
        assert session.event_log == [
            {"time": 1.0, "scheduled_time": 1.0, "type": "demand_surge", "vehicles": 3}
        ]
        assert session.result()["collisions"] == 0
        assert session.result()["configured_vehicles"] == 7
        vehicle_decisions = [
            decision for decision in session.signals.log if decision["kind"] == "vehicle"
        ]
        expected = 30 if controller == "fixed" else 10
        assert vehicle_decisions[0]["duration"] == expected
    finally:
        session.close()


def test_comparison_exports_equal_inputs_and_honest_empty_means():
    scenario = Scenario(
        network=generate_grid(2, 2), vehicles=3, pedestrians=2, duration=2, step_length=0.5
    )
    destination = Path("data/results/test-comparison")
    report = run_comparison(scenario, [100, 101], destination)
    assert len(report["runs"]) == 4
    assert report["vehicle_wait_improvement_percent"] is None
    assert (destination / "comparison.csv").exists()
    for seed in report["seeds"]:
        fixed = destination / f"seed-{seed}" / "fixed" / "demand.rou.xml"
        adaptive = destination / f"seed-{seed}" / "adaptive" / "demand.rou.xml"
        assert fixed.read_bytes() == adaptive.read_bytes()
    with pytest.raises(ValueError):
        run_comparison(scenario, [1, 1], destination)
