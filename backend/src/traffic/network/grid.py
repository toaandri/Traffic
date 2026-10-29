import random

import networkx as nx

from traffic.domain.models import Network, Node, Road


def generate_grid(
    rows: int = 3, columns: int = 3, spacing: float = 100, density: float = 1, seed: int = 42
) -> Network:
    if rows < 2 or columns < 2 or spacing <= 0 or not 0 < density <= 1:
        raise ValueError("Il faut au moins 2 lignes, 2 colonnes et un espacement positif.")
    nodes = [
        Node(id=f"n{x}_{y}", x=x * spacing, y=y * spacing)
        for y in range(rows)
        for x in range(columns)
    ]
    roads = []
    for y in range(rows):
        for x in range(columns):
            source = f"n{x}_{y}"
            neighbors = []
            if x + 1 < columns:
                neighbors.append(f"n{x + 1}_{y}")
            if y + 1 < rows:
                neighbors.append(f"n{x}_{y + 1}")
            for target in neighbors:
                for start, end in ((source, target), (target, source)):
                    roads.append(Road(id=f"{start}__{end}", source=start, target=end))
    if density < 1:
        graph = nx.Graph()
        graph.add_edges_from((road.source, road.target) for road in roads)
        pairs = sorted(graph.edges())
        random.Random(seed).shuffle(pairs)
        target = max(len(nodes), round(len(pairs) * density))
        for first, second in pairs:
            if graph.number_of_edges() <= target:
                break
            if graph.degree(first) <= 2 or graph.degree(second) <= 2:
                continue
            graph.remove_edge(first, second)
            if not nx.is_connected(graph):
                graph.add_edge(first, second)
        roads = [road for road in roads if graph.has_edge(road.source, road.target)]
    return Network(nodes=nodes, roads=roads)
