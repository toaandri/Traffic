from traffic.controllers.base import Observation


class AdaptiveController:
    """Durée verte bornée : files courantes et demandes piétonnes."""

    name = "adaptive"
    version = "0.2.0"

    def green_duration(self, observation: Observation) -> float:
        target = 10 + 2 * observation.vehicle_queue - observation.pedestrian_waiting
        return float(max(10, min(60, target)))
