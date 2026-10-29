import json
from pathlib import Path

from traffic.domain.models import DemandSurge, Scenario
from traffic.experiments.compare import run_comparison
from traffic.network.grid import generate_grid
from traffic.storage.projects import save_scenario


def run_stress(scenario: Scenario, seeds: list[int], directory: Path):
    reports = []
    for index, (size, vehicles) in enumerate(((2, 30), (3, 100), (3, 250))):
        candidate = Scenario.model_validate(
            {
                **scenario.model_dump(),
                "name": f"Stress {size}x{size} / {vehicles} véhicules",
                "network": generate_grid(size, size).model_dump(),
                "vehicles": vehicles,
                "vehicle_origins": [],
                "vehicle_destinations": [],
                "pedestrian_origins": [],
                "pedestrian_destinations": [],
                "pedestrians": vehicles // 3,
                "events": [DemandSurge(time=scenario.duration * 0.4, vehicles=20).model_dump()],
            }
        )
        report = run_comparison(candidate, seeds, directory / f"case-{index}")
        reports.append(report)
    worst = max(
        reports,
        key=lambda report: sum(r["vehicles"]["unfinished_waiting_time"] for r in report["runs"]),
    )
    save_scenario(Scenario.model_validate(worst["scenario"]), directory / "worst-scenario.json")
    (directory / "stress.json").write_text(json.dumps(reports, indent=2), encoding="utf-8")
    return reports
