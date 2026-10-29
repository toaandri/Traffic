from dataclasses import dataclass


@dataclass
class Journey:
    departure: float
    waiting: float = 0.0
    stops: int = 0
    stopped: bool = False


class MetricsCollector:
    """Temps d'attente intégrés aux pas ; moyennes des trajets arrivés seulement."""

    def __init__(self, step_length: float):
        self.step_length = step_length
        self.active = {"vehicles": {}, "pedestrians": {}}
        self.finished = {"vehicles": [], "pedestrians": []}
        self.started = {"vehicles": 0, "pedestrians": 0}
        self.teleports = 0

    def update(
        self,
        time: float,
        vehicles: list[dict],
        pedestrians: list[dict],
        departed_vehicles: set[str],
        departed_pedestrians: set[str],
        arrived_vehicles: set[str],
        arrived_pedestrians: set[str],
    ):
        for kind, states, departed, arrived in (
            ("vehicles", vehicles, departed_vehicles, arrived_vehicles),
            ("pedestrians", pedestrians, departed_pedestrians, arrived_pedestrians),
        ):
            for identifier in departed:
                if identifier not in self.active[kind]:
                    self.active[kind][identifier] = Journey(time - self.step_length)
                    self.started[kind] += 1
            for state in states:
                identifier = state["id"]
                journey = self.active[kind].get(identifier)
                if journey is None:
                    journey = Journey(time - self.step_length)
                    self.active[kind][identifier] = journey
                    self.started[kind] += 1
                stopped = state["speed"] < 0.1
                if stopped:
                    journey.waiting += self.step_length
                    if not journey.stopped:
                        journey.stops += 1
                journey.stopped = stopped
            for identifier in arrived:
                journey = self.active[kind].pop(identifier, None)
                if journey is not None:
                    self.finished[kind].append(
                        {
                            "id": identifier,
                            "travel_time": time - journey.departure,
                            "waiting_time": journey.waiting,
                            "stops": journey.stops,
                        }
                    )

    def summary(self, time: float) -> dict:
        result = {"time": time, "teleports": self.teleports}
        for kind in ("vehicles", "pedestrians"):
            completed = self.finished[kind]
            result[kind] = {
                "started": self.started[kind],
                "arrived": len(completed),
                "unfinished": len(self.active[kind]),
                "mean_waiting_time": (sum(j["waiting_time"] for j in completed) / len(completed))
                if completed
                else None,
                "mean_travel_time": (sum(j["travel_time"] for j in completed) / len(completed))
                if completed
                else None,
                "stops": sum(j["stops"] for j in completed)
                + sum(j.stops for j in self.active[kind].values()),
                "unfinished_waiting_time": sum(j.waiting for j in self.active[kind].values()),
            }
        return result
