from traffic.controllers.base import Observation


class FixedController:
    name = "fixed"
    version = "0.1.0"

    def green_duration(self, observation: Observation) -> float:
        return 30.0
