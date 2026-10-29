from itertools import combinations

import networkx as nx

from traffic.domain.models import Network


def validate_network(network: Network) -> list[str]:
    errors = []
    ids = [node.id for node in network.nodes]
    if not ids:
        return ["Le réseau est vide."]
    if len(set(ids)) != len(ids):
        errors.append("Les identifiants des nœuds doivent être uniques.")
    road_ids = [road.id for road in network.roads]
    road_by_id = {road.id: road for road in network.roads}
    if len(set(road_ids)) != len(road_ids):
        errors.append("Les identifiants des routes doivent être uniques.")
    positions = {node.id: (node.x, node.y) for node in network.nodes}
    crossing_ids = [crossing.id for crossing in network.crossings]
    if len(set(crossing_ids)) != len(crossing_ids):
        errors.append("Les identifiants des passages doivent être uniques.")
    for crossing in network.crossings:
        if crossing.node not in positions or any(
            road not in road_by_id
            or crossing.node not in (road_by_id[road].source, road_by_id[road].target)
            for road in crossing.roads
        ):
            errors.append(f"Passage {crossing.id} : routes non reliées à son intersection.")
    if len(set(positions.values())) != len(positions):
        errors.append("Deux nœuds occupent la même position.")
    graph = nx.DiGraph()
    graph.add_nodes_from(ids)
    for road in network.roads:
        if road.source not in positions or road.target not in positions:
            errors.append(f"Route {road.id} : extrémité inconnue.")
        elif road.source == road.target or positions[road.source] == positions[road.target]:
            errors.append(f"Route {road.id} : longueur nulle.")
        else:
            if road.shape:
                start, end = road.shape[0], road.shape[-1]
                source, target = positions[road.source], positions[road.target]
                if start != source or end != target:
                    errors.append(
                        f"Route {road.id} : la géométrie doit commencer à {road.source} "
                        f"et finir à {road.target}."
                    )
            graph.add_edge(road.source, road.target)
    if not nx.is_strongly_connected(graph):
        errors.append("Le réseau contient des nœuds isolés ou des trajets inaccessibles.")

    def orientation(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])

    segments = {
        tuple(sorted((r.source, r.target)))
        for r in network.roads
        if r.source in positions and r.target in positions and r.source != r.target
    }
    for first, second in combinations(sorted(segments), 2):
        if set(first) & set(second):
            continue
        a, b = (positions[item] for item in first)
        c, d = (positions[item] for item in second)
        if (
            orientation(a, b, c) * orientation(a, b, d) < 0
            and orientation(c, d, a) * orientation(c, d, b) < 0
        ):
            errors.append(
                "Deux routes se croisent sans intersection : "
                f"{' / '.join(first)} et {' / '.join(second)}."
            )
    return errors
