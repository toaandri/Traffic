import csv
import json
from pathlib import Path


def export_snapshots(snapshots: list[dict], directory: Path):
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "snapshots.json").write_text(json.dumps(snapshots, indent=2), encoding="utf-8")
    with (directory / "metrics.csv").open("w", newline="", encoding="utf-8") as stream:
        fields = [
            "time",
            "active",
            "arrived",
            "waiting_now",
            "pedestrians_active",
            "pedestrians_arrived",
            "pedestrians_waiting",
        ]
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        for snapshot in snapshots:
            writer.writerow({"time": snapshot["time"], **snapshot["metrics"]})
