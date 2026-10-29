import json
import random
import time as clock
import xml.etree.ElementTree as ET
from pathlib import Path
from uuid import uuid4

import sumolib
import traci
from traci import constants as tc

from traffic import __version__
from traffic.controllers.runtime import SignalRuntime
from traffic.domain.models import DemandSurge, RoadClosure, Scenario
from traffic.metrics.collector import MetricsCollector
from traffic.metrics.export import export_snapshots
from traffic.network.sumo_export import export_scenario


class SimulationSession:
    def __init__(self, scenario: Scenario, directory: Path):
        self.scenario = scenario.model_copy(deep=True)
        self.directory = directory
        self.completed = 0
        self.connection = None
        self.events = sorted(enumerate(scenario.events), key=lambda item: (item[1].time, item[0]))
        self.event_log = []
        self.history = []
        self.closures = {}
        self.step_costs = []
        self.collector = MetricsCollector(scenario.step_length)
        self.subscribed_vehicles = set()
        self.subscribed_people = set()
        config = export_scenario(scenario, directory)
        plans = json.loads((directory / "signals.json").read_text(encoding="utf-8"))
        label = f"traffic-{uuid4()}"
        traci.start(
            [
                sumolib.checkBinary("sumo"),
                "-c",
                str(config.resolve()),
                "--seed",
                str(scenario.seed),
                "--step-length",
                str(scenario.step_length),
                "--no-step-log",
                "true",
                "--duration-log.disable",
                "true",
                "--time-to-teleport",
                "-1",
                "--collision.action",
                "warn",
                "--tripinfo-output",
                str((directory / "tripinfo.xml").resolve()),
                "--tripinfo-output.write-unfinished",
                "true",
                "--error-log",
                str((directory / "sumo.log").resolve()),
            ],
            label=label,
        )
        self.connection = traci.getConnection(label)
        self.signals = SignalRuntime(self.connection, plans, scenario.controller)
        self.signals.update(0)
        self.collisions = 0
        self.last_snapshot = self.snapshot()
        self.raw_stream = (directory / "raw.jsonl").open("w", encoding="utf-8")
        self.previous_roads = {}
        self.throughput = {identifier: 0 for identifier in plans}

    def geometry(self) -> dict:
        root = ET.parse(self.directory / "network.net.xml").getroot()
        crossings = []
        for edge in root.findall("edge"):
            if edge.get("function") == "crossing":
                lane = edge.find("lane")
                shape = [
                    [float(value) for value in point.split(",")[:2]]
                    for point in lane.get("shape").split()
                ]
                crossings.append({"id": edge.get("id"), "shape": shape})
        return {
            "crossings": crossings,
            "lights": [
                {"id": identifier, "x": plan["x"], "y": plan["y"], "links": plan["links"]}
                for identifier, plan in self.signals.plans.items()
            ],
        }

    def snapshot(self) -> dict:
        connection = self.connection
        vehicles = []
        for identifier in connection.vehicle.getIDList():
            if identifier not in self.subscribed_vehicles:
                connection.vehicle.subscribe(
                    identifier,
                    [
                        tc.VAR_POSITION,
                        tc.VAR_ANGLE,
                        tc.VAR_SPEED,
                        tc.VAR_WAITING_TIME,
                        tc.VAR_ROAD_ID,
                    ],
                )
                self.subscribed_vehicles.add(identifier)
            state = connection.vehicle.getSubscriptionResults(identifier)
            x, y = state[tc.VAR_POSITION]
            vehicles.append(
                {
                    "id": identifier,
                    "x": x,
                    "y": y,
                    "angle": state[tc.VAR_ANGLE],
                    "speed": state[tc.VAR_SPEED],
                    "waiting": state[tc.VAR_WAITING_TIME],
                    "road": state[tc.VAR_ROAD_ID],
                }
            )
        pedestrians = []
        for identifier in connection.person.getIDList():
            if identifier not in self.subscribed_people:
                connection.person.subscribe(
                    identifier, [tc.VAR_POSITION, tc.VAR_SPEED, tc.VAR_WAITING_TIME, tc.VAR_ROAD_ID]
                )
                self.subscribed_people.add(identifier)
            state = connection.person.getSubscriptionResults(identifier)
            x, y = state[tc.VAR_POSITION]
            pedestrians.append(
                {
                    "id": identifier,
                    "x": x,
                    "y": y,
                    "speed": state[tc.VAR_SPEED],
                    "waiting": state[tc.VAR_WAITING_TIME],
                    "road": state[tc.VAR_ROAD_ID],
                }
            )
        lights = [
            {
                "id": identifier,
                "state": connection.trafficlight.getRedYellowGreenState(identifier),
                "phase": connection.trafficlight.getPhase(identifier),
                "decision": self.signals.decisions.get(identifier, {}),
            }
            for identifier in connection.trafficlight.getIDList()
        ]
        time = connection.simulation.getTime()
        return {
            "protocol_version": 1,
            "type": "snapshot",
            "time": time,
            "finished": time >= self.scenario.duration,
            "controller": self.scenario.controller,
            "vehicles": vehicles,
            "pedestrians": pedestrians,
            "lights": lights,
            "metrics": {
                "active": len(vehicles),
                "arrived": self.completed,
                "waiting_now": sum(v["waiting"] > 0 for v in vehicles),
                "pedestrians_active": len(pedestrians),
                "pedestrians_arrived": len(self.collector.finished["pedestrians"]),
                "pedestrians_waiting": sum(p["waiting"] > 0 for p in pedestrians),
            },
            "summary": self.collector.summary(time),
            "events": self.event_log,
            "closed_roads": list(self.closures),
            "congestion": {
                road.id: connection.edge.getLastStepHaltingNumber(road.id)
                for road in self.scenario.network.roads
            },
        }

    def _apply_events(self):
        time = self.connection.simulation.getTime()
        for road, closure in list(self.closures.items()):
            if time >= closure["until"]:
                for lane, allowed in closure["allowed"].items():
                    self.connection.lane.setAllowed(lane, allowed)
                self.connection.edge.adaptTraveltime(road, closure["travel_time"])
                for vehicle in closure["stopped"]:
                    if vehicle in self.connection.vehicle.getIDList():
                        self.connection.vehicle.setSpeed(vehicle, -1)
                self.event_log.append({"time": time, "type": "reopened", "road": road})
                del self.closures[road]
        while self.events and self.events[0][1].time <= time + 1e-9:
            index, event = self.events.pop(0)
            if isinstance(event, RoadClosure):
                current = self.closures.get(event.road)
                if current is None:
                    current = {
                        "allowed": {
                            f"{event.road}_{index}": list(
                                self.connection.lane.getAllowed(f"{event.road}_{index}")
                            )
                            for index in range(self.connection.edge.getLaneNumber(event.road))
                        },
                        "travel_time": self.connection.edge.getTraveltime(event.road),
                        "stopped": [],
                        "until": time + event.duration,
                    }
                    self.closures[event.road] = current
                current["until"] = max(current["until"], time + event.duration)
                for lane, allowed in current["allowed"].items():
                    if allowed:
                        self.connection.lane.setAllowed(
                            lane, [item for item in allowed if item != "passenger"]
                        )
                    else:
                        self.connection.lane.setDisallowed(lane, ["passenger"])
                self.connection.edge.adaptTraveltime(event.road, 1000000)
                failed = 0
                for vehicle in self.connection.vehicle.getIDList():
                    if (
                        event.type == "accident"
                        and self.connection.vehicle.getRoadID(vehicle) == event.road
                    ):
                        self.connection.vehicle.setSpeed(vehicle, 0)
                        current["stopped"].append(vehicle)
                    if event.road in self.connection.vehicle.getRoute(vehicle):
                        try:
                            self.connection.vehicle.rerouteTraveltime(vehicle)
                        except traci.TraCIException:
                            failed += 1
                self.event_log.append(
                    {
                        "time": time,
                        "scheduled_time": event.time,
                        "type": event.type,
                        "road": event.road,
                        "duration": event.duration,
                        "unroutable": failed,
                    }
                )
                continue
            rng = random.Random(self.scenario.seed + 1000 + index)
            routes = sorted(self.connection.route.getIDList())
            for number in range(event.vehicles):
                self.connection.vehicle.add(
                    f"surge{index}_{number}", rng.choice(routes), typeID="car", depart="now"
                )
            roads = sorted(road.id for road in self.scenario.network.roads)
            for number in range(event.pedestrians):
                origin = rng.choice(self.scenario.pedestrian_origins or roads)
                destination = rng.choice(
                    self.scenario.pedestrian_destinations
                    or [road for road in roads if road != origin]
                )
                stages = self.connection.simulation.findIntermodalRoute(
                    origin, destination, modes=""
                )
                identifier = f"surge_p{index}_{number}"
                self.connection.person.add(identifier, origin, pos=5)
                for stage in stages:
                    self.connection.person.appendWalkingStage(
                        identifier, stage.edges, arrivalPos=5, speed=1.3
                    )
            self.event_log.append(
                {
                    "time": time,
                    "scheduled_time": event.time,
                    "type": "demand_surge",
                    "vehicles": event.vehicles,
                }
            )
            if event.pedestrians:
                self.event_log[-1]["pedestrians"] = event.pedestrians

    def step(self) -> dict:
        started = clock.perf_counter()
        if self.connection.simulation.getTime() >= self.scenario.duration:
            return self.last_snapshot
        self._apply_events()
        self.connection.simulationStep()
        time = self.connection.simulation.getTime()
        self.signals.update(time)
        self.completed += self.connection.simulation.getArrivedNumber()
        self.collisions += self.connection.simulation.getCollidingVehiclesNumber()
        snapshot = self.snapshot()
        self.collector.teleports += self.connection.simulation.getStartingTeleportNumber()
        departed_vehicles = set(self.connection.simulation.getDepartedIDList())
        departed_people = set(self.connection.simulation.getDepartedPersonIDList())
        arrived_vehicles = set(self.connection.simulation.getArrivedIDList())
        arrived_people = set(self.connection.simulation.getArrivedPersonIDList())
        self.collector.update(
            time,
            snapshot["vehicles"],
            snapshot["pedestrians"],
            departed_vehicles,
            departed_people,
            arrived_vehicles,
            arrived_people,
        )
        for vehicle in snapshot["vehicles"]:
            road = vehicle["road"]
            if road != self.previous_roads.get(vehicle["id"]) and road.startswith(":"):
                for identifier in self.throughput:
                    if road.startswith(f":{identifier}_") and not self.previous_roads.get(
                        vehicle["id"], ""
                    ).startswith(f":{identifier}_"):
                        self.throughput[identifier] += 1
                        break
            self.previous_roads[vehicle["id"]] = road
        for identifier in arrived_vehicles:
            self.previous_roads.pop(identifier, None)
        self.raw_stream.write(
            json.dumps(
                {
                    "time": time,
                    "step_length": self.scenario.step_length,
                    "vehicles": snapshot["vehicles"],
                    "pedestrians": snapshot["pedestrians"],
                    "departed_vehicles": sorted(departed_vehicles),
                    "departed_pedestrians": sorted(departed_people),
                    "arrived_vehicles": sorted(arrived_vehicles),
                    "arrived_pedestrians": sorted(arrived_people),
                }
            )
            + "\n"
        )
        snapshot["summary"] = self.collector.summary(time)
        snapshot["metrics"]["pedestrians_arrived"] = len(self.collector.finished["pedestrians"])
        self.last_snapshot = snapshot
        self.step_costs.append((clock.perf_counter() - started) * 1000)
        snapshot["performance"] = {"step_ms": self.step_costs[-1]}
        self.history.append({"time": time, "metrics": snapshot["metrics"].copy()})
        return snapshot

    def export_results(self, destination: Path):
        self.raw_stream.flush()
        export_snapshots(self.history, destination)
        for name, value in (
            ("summary", self.result()),
            ("decisions", self.signals.log),
            ("journeys", self.collector.finished),
            ("scenario", self.scenario.model_dump()),
        ):
            (destination / f"{name}.json").write_text(json.dumps(value, indent=2), encoding="utf-8")

    def result(self) -> dict:
        summary = self.collector.summary(self.connection.simulation.getTime())
        summary.update(
            traffic_version=__version__,
            controller=self.scenario.controller,
            seed=self.scenario.seed,
            collisions=self.collisions,
            events=self.event_log,
            configured_vehicles=self.scenario.vehicles
            + sum(
                event.vehicles for event in self.scenario.events if isinstance(event, DemandSurge)
            ),
            configured_pedestrians=self.scenario.pedestrians
            + sum(
                event.pedestrians
                for event in self.scenario.events
                if isinstance(event, DemandSurge)
            ),
            controller_version=self.signals.controller.version,
        )
        summary["mean_step_ms"] = sum(self.step_costs) / max(1, len(self.step_costs))
        summary["intersection_throughput_observed"] = self.throughput
        summary["blocked"] = sum(
            journey.waiting >= 60 for journey in self.collector.active["vehicles"].values()
        )
        for kind in ("vehicles", "pedestrians"):
            configured = summary[f"configured_{kind}"]
            summary[kind]["not_departed"] = configured - self.collector.started[kind]
        return summary

    def close(self):
        if self.connection is not None:
            try:
                export_snapshots(self.history, self.directory)
                (self.directory / "summary.json").write_text(
                    json.dumps(self.result(), indent=2), encoding="utf-8"
                )
                (self.directory / "decisions.json").write_text(
                    json.dumps(self.signals.log, indent=2), encoding="utf-8"
                )
                (self.directory / "journeys.json").write_text(
                    json.dumps(self.collector.finished, indent=2), encoding="utf-8"
                )
            finally:
                self.raw_stream.close()
                self.connection.close()
                self.connection = None
