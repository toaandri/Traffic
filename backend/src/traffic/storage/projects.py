from pathlib import Path

from traffic.domain.models import Scenario


def load_scenario(path: Path) -> Scenario:
    return Scenario.model_validate_json(path.read_text(encoding="utf-8"))


def save_scenario(scenario: Scenario, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(scenario.model_dump_json(indent=2), encoding="utf-8")
    temporary.replace(path)
