import json
import re
from datetime import UTC, datetime
from pathlib import Path
from uuid import uuid4

from traffic.domain.models import Scenario
from traffic.storage.projects import load_scenario, save_scenario


class ProjectCatalog:
    def __init__(self, directory: Path = Path("data/projects")):
        self.directory = directory
        directory.mkdir(parents=True, exist_ok=True)

    def list(self) -> list[dict]:
        projects = []
        for path in sorted(
            self.directory.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True
        ):
            try:
                scenario = load_scenario(path)
                projects.append(
                    {
                        "id": path.stem,
                        "name": scenario.name,
                        "description": scenario.description,
                        "modified": datetime.fromtimestamp(path.stat().st_mtime, UTC).isoformat(),
                        "nodes": len(scenario.network.nodes),
                    }
                )
            except (OSError, ValueError):
                projects.append({"id": path.stem, "name": path.stem, "corrupted": True})
        return projects

    def path(self, identifier: str) -> Path:
        if not re.fullmatch(r"[a-f0-9]{32}", identifier):
            raise ValueError("Identifiant de projet invalide.")
        return self.directory / f"{identifier}.json"

    def save(self, scenario: Scenario, identifier: str | None = None) -> str:
        identifier = identifier or uuid4().hex
        save_scenario(scenario, self.path(identifier))
        return identifier

    def load(self, identifier: str) -> Scenario:
        return load_scenario(self.path(identifier))


def list_history(directory: Path = Path("data/results")) -> list[dict]:
    entries = []
    for path in sorted(
        directory.rglob("comparison.json"), key=lambda p: p.stat().st_mtime, reverse=True
    )[:30]:
        try:
            report = json.loads(path.read_text(encoding="utf-8"))
            entries.append(
                {
                    "name": report["scenario"]["name"],
                    "directory": str(path.parent),
                    "seeds": report["seeds"],
                    "aggregates": report["aggregates"],
                    "improvement": report.get("vehicle_wait_improvement_percent"),
                }
            )
        except (OSError, ValueError, KeyError):
            continue
    return entries
