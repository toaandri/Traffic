import csv
import hashlib
import json
import os
import platform
from importlib.metadata import version
from math import sqrt
from pathlib import Path
from statistics import mean, stdev

from traffic import __version__
from traffic.domain.models import Scenario
from traffic.experiments.report import export_html
from traffic.simulation.session import SimulationSession

CONTROLLERS = ("fixed", "adaptive", "max_pressure")


def run_comparison(scenario: Scenario, seeds: list[int], directory: Path) -> dict:
    if not seeds or len(set(seeds)) != len(seeds):
        raise ValueError("Fournir au moins une graine, sans doublons.")
    directory.mkdir(parents=True, exist_ok=True)
    rows = []
    for seed in seeds:
        pair = []
        for controller in CONTROLLERS:
            print(f"Essai graine {seed} / {controller}…", flush=True)
            trial = Scenario.model_validate(
                {**scenario.model_dump(), "seed": seed, "controller": controller}
            )
            destination = directory / f"seed-{seed}" / controller
            session = SimulationSession(trial, destination)
            try:
                while session.connection.simulation.getTime() < trial.duration:
                    cancellation = os.environ.get("TRAFFIC_CANCEL_FILE")
                    if cancellation and Path(cancellation).exists():
                        raise InterruptedError("Campagne annulée par l'utilisateur.")
                    session.step()
                result = session.result()
                rows.append(result)
            finally:
                session.close()
            pair.append(hashlib.sha256((destination / "demand.rou.xml").read_bytes()).hexdigest())
        if pair[0] != pair[1]:
            raise RuntimeError("Comparaison refusée : les demandes ne sont pas identiques.")
    aggregates = {}
    for controller in CONTROLLERS:
        selected = [row for row in rows if row["controller"] == controller]
        values = [
            row["vehicles"]["mean_waiting_time"]
            for row in selected
            if row["vehicles"]["mean_waiting_time"] is not None
        ]
        aggregates[controller] = {
            "mean_vehicle_wait": mean(values) if values else None,
            "sample_stddev": stdev(values) if len(values) > 1 else None,
            "runs_with_arrivals": len(values),
            "mean_vehicle_arrivals": mean(r["vehicles"]["arrived"] for r in selected),
            "mean_pedestrian_arrivals": mean(r["pedestrians"]["arrived"] for r in selected),
            "mean_pedestrian_wait": mean(v)
            if (
                v := [
                    r["pedestrians"]["mean_waiting_time"]
                    for r in selected
                    if r["pedestrians"]["mean_waiting_time"] is not None
                ]
            )
            else None,
            "mean_vehicle_unfinished": mean(r["vehicles"]["unfinished"] for r in selected),
            "normal_95_interval": [
                mean(values) - 1.96 * stdev(values) / sqrt(len(values)),
                mean(values) + 1.96 * stdev(values) / sqrt(len(values)),
            ]
            if len(values) >= 3
            else None,
        }
    baseline = aggregates["fixed"]["mean_vehicle_wait"]
    adaptive = aggregates["adaptive"]["mean_vehicle_wait"]
    improvement = (
        (baseline - adaptive) / baseline * 100
        if baseline is not None and baseline > 0 and adaptive is not None
        else None
    )
    report = {
        "scenario": scenario.model_dump(),
        "seeds": seeds,
        "runs": rows,
        "aggregates": aggregates,
        "vehicle_wait_improvement_percent": improvement,
        "versions": {
            "traffic": __version__,
            "python": platform.python_version(),
            "sumo": version("eclipse-sumo"),
            "traci": version("traci"),
        },
        "interpretation": "Moyennes sur arrivés uniquement : comparer aussi arrivées, "
        "non partis, non arrivés et attente des agents non arrivés.",
    }
    (directory / "comparison.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    export_html(report, directory)
    with (directory / "comparison.csv").open("w", encoding="utf-8", newline="") as stream:
        fields = [
            "seed",
            "controller",
            "kind",
            "started",
            "arrived",
            "unfinished",
            "not_departed",
            "mean_waiting_time",
            "mean_travel_time",
            "stops",
            "unfinished_waiting_time",
        ]
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        for row in rows:
            for kind in ("vehicles", "pedestrians"):
                writer.writerow(
                    {
                        "seed": row["seed"],
                        "controller": row["controller"],
                        "kind": kind,
                        **row[kind],
                    }
                )
    return report
