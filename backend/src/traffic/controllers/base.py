from dataclasses import dataclass
from typing import Protocol


@dataclass(frozen=True)
class Observation:
    phase_elapsed: float
    vehicle_queue: int
    pedestrian_waiting: int


class Controller(Protocol):
    name: str
    version: str

    def green_duration(self, observation: Observation) -> float: ...
