from traffic.controllers.adaptive import AdaptiveController
from traffic.controllers.base import Observation
from traffic.controllers.fixed import FixedController
from traffic.controllers.max_pressure import MaxPressureController
from traffic.controllers.safety import safe_green_duration, validate_phase


class SignalRuntime:
    """Adapter la durée d'une phase à son entrée, sans jamais sauter les transitions.

    Pas de setPhase ni de setRedYellowGreenState : SUMO suit le cycle protégé.
    La décision est recalculée une fois par phase. La protection retarde la prochaine
    autorisation si des agents occupent encore l'intérieur du carrefour.
    """

    def __init__(self, connection, plans: dict, name: str):
        self.connection = connection
        self.plans = plans
        self.controller = {
            "fixed": FixedController,
            "adaptive": AdaptiveController,
            "max_pressure": MaxPressureController,
        }.get(name, FixedController)()
        self.previous = {}
        self.decisions = {}
        self.log = []

    def update(self, time: float):
        connection = self.connection
        for identifier, plan in self.plans.items():
            current = connection.trafficlight.getPhase(identifier)
            phase = plan["phases"][current]
            state = connection.trafficlight.getRedYellowGreenState(identifier)
            if state != phase["state"]:
                raise RuntimeError(f"Feu {identifier} : état modifié hors du plan protégé.")
            validate_phase(state, {tuple(pair) for pair in plan["conflicts"]})
            if self.previous.get(identifier) != current:
                self.previous[identifier] = current
                decision = {
                    "time": time,
                    "intersection": identifier,
                    "phase": current,
                    "kind": phase["kind"],
                    "duration": phase["duration"],
                }
                if phase["kind"] == "vehicle":
                    lanes = {
                        link["incoming"]
                        for index, link in plan["links"].items()
                        if phase["state"][int(index)] == "G" and not link["pedestrian"]
                    }
                    queue = sum(connection.lane.getLastStepHaltingNumber(lane) for lane in lanes)
                    outgoing = {
                        link["outgoing"]
                        for index, link in plan["links"].items()
                        if phase["state"][int(index)] == "G"
                        and not link["pedestrian"]
                        and link.get("outgoing")
                    }
                    downstream_queue = sum(
                        connection.lane.getLastStepHaltingNumber(lane)
                        for lane in outgoing
                    )
                    crossings = {
                        link["via"].rsplit("_", 1)[0]
                        for link in plan["links"].values()
                        if link["pedestrian"]
                    }
                    waiting = sum(
                        connection.person.getWaitingTime(person) > 0
                        and connection.person.getNextEdge(person) in crossings
                        for person in connection.person.getIDList()
                    )
                    observation = Observation(
                        phase_elapsed=0,
                        vehicle_queue=queue,
                        pedestrian_waiting=waiting,
                        phase_pressure=queue - downstream_queue,
                        pedestrian_pressure=waiting,
                    )
                    requested = self.controller.green_duration(observation)
                    if self.controller.name == "fixed":
                        requested = plan.get("fixed_green", 30)
                    duration = safe_green_duration(
                        requested,
                        minimum=plan.get("min_green", 10),
                        maximum=plan.get("max_green", 40),
                    )
                    connection.trafficlight.setPhaseDuration(identifier, duration)
                    decision.update(duration=duration, queue=queue, pedestrians_waiting=waiting)
                self.decisions[identifier] = decision
                self.log.append(decision)
            if phase["kind"] == "clearance":
                remaining = connection.trafficlight.getNextSwitch(identifier) - time
                if remaining <= 2 * connection.simulation.getDeltaT():
                    # Une traversée encore occupée ne peut pas être libérée pour les véhicules.
                    internal_edges = {
                        link["via"].rsplit("_", 1)[0] for link in plan["links"].values()
                    }
                    occupied = any(
                        connection.person.getRoadID(person) in internal_edges
                        for person in connection.person.getIDList()
                    )
                    occupied |= any(
                        connection.vehicle.getRoadID(vehicle).startswith(f":{identifier}_")
                        for vehicle in connection.vehicle.getIDList()
                    )
                    if occupied:
                        connection.trafficlight.setPhaseDuration(identifier, 1.0)
