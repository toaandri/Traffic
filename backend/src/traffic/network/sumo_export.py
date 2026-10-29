import random
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

import sumolib

from traffic.domain.models import Scenario
from traffic.network.signals import protect_signals
from traffic.network.validation import validate_network


def export_scenario(scenario: Scenario, directory: Path) -> Path:
    errors = validate_network(scenario.network)
    if errors:
        raise ValueError("; ".join(errors))
    directory.mkdir(parents=True, exist_ok=True)
    nodes = ET.Element("nodes")
    for node in scenario.network.nodes:
        ET.SubElement(nodes, "node", id=node.id, x=str(node.x), y=str(node.y), type="traffic_light")
    edges = ET.Element("edges")
    for road in scenario.network.roads:
        attributes = {
            "id": road.id,
            "from": road.source,
            "to": road.target,
            "numLanes": str(road.lanes),
            "speed": str(road.speed),
            "sidewalkWidth": "2",
        }
        if road.shape:
            attributes["shape"] = " ".join(f"{x},{y}" for x, y in road.shape)
        ET.SubElement(edges, "edge", attributes)
    ET.ElementTree(nodes).write(directory / "nodes.nod.xml", encoding="utf-8")
    ET.ElementTree(edges).write(directory / "edges.edg.xml", encoding="utf-8")
    connections = ET.Element("connections")
    for crossing in scenario.network.crossings:
        ET.SubElement(
            connections,
            "crossing",
            node=crossing.node,
            edges=" ".join(crossing.roads),
            priority="true",
            width="3",
        )
    ET.ElementTree(connections).write(directory / "connections.con.xml", encoding="utf-8")
    subprocess.run(
        [
            sumolib.checkBinary("netconvert"),
            "--node-files",
            str(directory / "nodes.nod.xml"),
            "--edge-files",
            str(directory / "edges.edg.xml"),
            "--connection-files",
            str(directory / "connections.con.xml"),
            "--output-file",
            str(directory / "network.net.xml"),
            "--no-turnarounds",
            "true",
            "--crossings.guess",
            str(scenario.network.auto_crossings).lower(),
            "--offset.disable-normalization",
            "true",
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    protect_signals(
        directory / "network.net.xml",
        {node.id: node.fixed_green for node in scenario.network.nodes},
        {node.id: (node.min_green, node.max_green) for node in scenario.network.nodes},
    )
    # Lire les connexions réelles SUMO évite de créer des itinéraires à virages interdits.
    net = sumolib.net.readNet(str(directory / "network.net.xml"))
    rng = random.Random(scenario.seed)
    routes = ET.Element("routes")
    vehicle_profiles = {
        "standard": {"accel": "2.6", "decel": "4.5", "sigma": "0.2"},
        "cautious": {"accel": "1.8", "decel": "5.5", "sigma": "0.4"},
        "aggressive": {"accel": "3.2", "decel": "4.0", "sigma": "0.1"},
    }
    ET.SubElement(
        routes,
        "vType",
        id="car",
        **vehicle_profiles[scenario.vehicle_profile],
    )
    candidates = sorted(
        (edge for edge in net.getEdges() if edge.allows("passenger")), key=lambda edge: edge.getID()
    )
    demand = []
    by_id = {edge.getID(): edge for edge in candidates}
    origins = [by_id[item] for item in scenario.vehicle_origins] or candidates
    destinations = [by_id[item] for item in scenario.vehicle_destinations]
    for index in range(scenario.vehicles):
        path = [rng.choice(origins)]
        if destinations:
            target = rng.choice(destinations)
            route, _cost = net.getShortestPath(path[0], target, vClass="passenger")
            if not route:
                raise ValueError(
                    f"Destination inaccessible : {path[0].getID()} vers {target.getID()}"
                )
            path = list(route)
        for _ in range(0 if destinations else 2):
            outgoing = sorted(path[-1].getOutgoing(), key=lambda edge: edge.getID())
            if not outgoing:
                break
            path.append(rng.choice(outgoing))
        route_id = f"route{index}"
        ET.SubElement(routes, "route", id=route_id, edges=" ".join(edge.getID() for edge in path))
        vehicle = ET.Element(
            "vehicle",
            id=f"v{index}",
            type="car",
            depart=str(
                scenario.duration
                * (
                    (0.35 + 0.2 * index / max(1, scenario.vehicles))
                    if scenario.demand_profile == "peak"
                    else (index * 0.5 / max(1, scenario.vehicles))
                )
            ),
            route=route_id,
        )
        if scenario.vehicle_rate is not None:
            vehicle.set(
                "depart",
                str(
                    index * 3600 / scenario.vehicle_rate
                    + (scenario.duration * 0.35 if scenario.demand_profile == "peak" else 0)
                ),
            )
        demand.append(vehicle)
    if not scenario.vehicles:
        # Un itinéraire de référence sert aussi aux hausses de demande.
        source = candidates[0]
        ET.SubElement(routes, "route", id="route0", edges=source.getID())
    pedestrian_rng = random.Random(scenario.seed + 1)
    for index in range(scenario.pedestrians):
        start = pedestrian_rng.choice(
            [by_id[item] for item in scenario.pedestrian_origins] or candidates
        )
        end = pedestrian_rng.choice(
            [by_id[item] for item in scenario.pedestrian_destinations]
            or [edge for edge in candidates if edge != start]
        )
        person = ET.Element(
            "person",
            id=f"p{index}",
            departPos=str(min(10, start.getLength() * 0.2)),
            depart=str(index * scenario.duration * 0.35 / max(1, scenario.pedestrians)),
        )
        if scenario.pedestrian_rate is not None:
            person.set("depart", str(index * 3600 / scenario.pedestrian_rate))
        ET.SubElement(
            person,
            "walk",
            {
                "from": start.getID(),
                "to": end.getID(),
                "speed": str(scenario.pedestrian_speed),
                "arrivalPos": str(min(20, end.getLength() * 0.8)),
            },
        )
        demand.append(person)
    routes.extend(
        sorted(demand, key=lambda element: (float(element.get("depart")), element.get("id")))
    )
    ET.ElementTree(routes).write(directory / "demand.rou.xml", encoding="utf-8")
    config = ET.Element("configuration")
    inputs = ET.SubElement(config, "input")
    ET.SubElement(inputs, "net-file", value="network.net.xml")
    ET.SubElement(inputs, "route-files", value="demand.rou.xml")
    path = directory / "simulation.sumocfg"
    ET.ElementTree(config).write(path, encoding="utf-8")
    (directory / "scenario.json").write_text(scenario.model_dump_json(indent=2), encoding="utf-8")
    return path
