from dataclasses import dataclass
from typing import Protocol


@dataclass(frozen=True)
class Observation:
    phase_elapsed: float
    vehicle_queue: int
    pedestrian_waiting: int
    phase_pressure: float = 0
    pedestrian_pressure: int = 0


class Controller(Protocol):
    name: str
    version: str

    def green_duration(self, observation: Observation) -> float: ...
