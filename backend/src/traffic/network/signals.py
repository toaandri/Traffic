"""Plans protégés construits avec les conflits calculés par netconvert.

Les véhicules et les piétons ont des phases distinctes. Les algorithmes ne
peuvent changer que les durées vertes, jamais les états ni les transitions.
"""

import itertools
import json
import math
import xml.etree.ElementTree as ET
from pathlib import Path

from traffic.controllers.safety import validate_phase


def protect_signals(path: Path, durations: dict | None = None, bounds: dict | None = None) -> dict:
    tree = ET.parse(path)
    root = tree.getroot()
    junctions = {item.get("id"): item for item in root.findall("junction")}
    crossing_lanes = {
        lane.get("id"): lane
        for edge in root.findall("edge")
        if edge.get("function") == "crossing"
        for lane in edge.findall("lane")
    }
    plans = {}
    for logic in root.findall("tlLogic"):
        identifier = logic.get("id")
        junction = junctions[identifier]
        internals = junction.get("intLanes", "").split()
        requests = {
            int(item.get("index")): item.get("foes")[::-1] for item in junction.findall("request")
        }
        links = {}
        for connection in root.findall("connection"):
            if connection.get("tl") == identifier:
                index = int(connection.get("linkIndex"))
                via = connection.get("via", "")
                pedestrian_lane = f"{connection.get('to')}_{connection.get('toLane')}"
                if pedestrian_lane in crossing_lanes:
                    via = pedestrian_lane
                links[index] = {
                    "via": via,
                    "incoming": f"{connection.get('from')}_{connection.get('fromLane')}",
                    "pedestrian": via in crossing_lanes,
                }
        size = len(logic.find("phase").get("state"))
        if set(links) != set(range(size)):
            raise ValueError(f"Feu {identifier} : indices non couverts par le plan de sécurité.")
        conflicts = set()
        for first, second in itertools.combinations(range(size), 2):
            a, b = links[first], links[second]
            if a["pedestrian"] or b["pedestrian"]:
                conflict = a["pedestrian"] != b["pedestrian"]
            elif a["via"] in internals and b["via"] in internals:
                ia, ib = internals.index(a["via"]), internals.index(b["via"])
                conflict = (
                    ib >= len(requests.get(ia, ""))
                    or ia >= len(requests.get(ib, ""))
                    or requests[ia][ib] == "1"
                    or requests[ib][ia] == "1"
                )
            else:
                conflict = True  # Géométrie inconnue : ne jamais autoriser ensemble.
            if conflict:
                conflicts.add((first, second))
        groups = []
        for index in range(size):
            if links[index]["pedestrian"]:
                continue
            for group in groups:
                if all(tuple(sorted((index, other))) not in conflicts for other in group):
                    group.append(index)
                    break
            else:
                groups.append([index])
        pedestrian_indices = [i for i in range(size) if links[i]["pedestrian"]]
        if pedestrian_indices:
            groups.append(pedestrian_indices)
        phases = []
        for group in groups:
            state = "".join("G" if index in group else "r" for index in range(size))
            validate_phase(state, conflicts)
            pedestrian = links[group[0]]["pedestrian"]
            phases.append(
                {
                    "state": state,
                    "duration": 12.0 if pedestrian else 20.0,
                    "kind": "pedestrian" if pedestrian else "vehicle",
                }
            )
            if not pedestrian:
                phases.append({"state": state.replace("G", "y"), "duration": 3.0, "kind": "yellow"})
            clearance = 8.0
            if pedestrian:
                clearance = (
                    max(float(crossing_lanes[links[i]["via"]].get("length")) for i in group) / 1.0
                    + 2
                )
            phases.append(
                {"state": "r" * size, "duration": float(math.ceil(clearance)), "kind": "clearance"}
            )
        for phase in list(logic):
            logic.remove(phase)
        logic.set("programID", "traffic-safe-v1")
        logic.set("type", "static")
        for phase in phases:
            ET.SubElement(logic, "phase", duration=str(phase["duration"]), state=phase["state"])
        plans[identifier] = {
            "fixed_green": (durations or {}).get(identifier, 30),
            "min_green": (bounds or {}).get(identifier, (10, 40))[0],
            "max_green": (bounds or {}).get(identifier, (10, 40))[1],
            "phases": phases,
            "links": links,
            "conflicts": sorted(conflicts),
            "x": float(junction.get("x")),
            "y": float(junction.get("y")),
        }
    tree.write(path, encoding="utf-8", xml_declaration=True)
    (path.parent / "signals.json").write_text(json.dumps(plans, indent=2), encoding="utf-8")
    return plans
