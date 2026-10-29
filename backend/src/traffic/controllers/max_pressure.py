from traffic.controllers.base import Observation


class MaxPressureController:
    """Pressure-based controller constrained by the protected SUMO signal plan."""

    name = "max_pressure"
    version = "1.0.0"

    def green_duration(self, observation: Observation) -> float:
        pressure = max(0.0, observation.phase_pressure)
        pedestrian_pressure = max(0, observation.pedestrian_pressure)
        requested = 10 + 2 * pressure + pedestrian_pressure
        return float(max(10, min(60, requested)))
