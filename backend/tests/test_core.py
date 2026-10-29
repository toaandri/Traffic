import pytest
from traffic.controllers.base import Observation
from traffic.controllers.max_pressure import MaxPressureController
from traffic.controllers.safety import safe_green_duration, validate_phase
from traffic.domain.models import Node, Road
from traffic.network.grid import generate_grid
from traffic.network.validation import validate_network


def test_grid_is_connected_and_stable():
    first = generate_grid()
    assert first == generate_grid()
    assert len(first.nodes) == 9
    assert validate_network(first) == []


def test_isolated_node_blocks_simulation():
    network = generate_grid()
    network.nodes.append(Node(id="isolated", x=1000, y=1000))
    assert validate_network(network)


def test_unconnected_geometric_crossing_is_rejected():
    network = generate_grid(2, 2)
    network.roads.extend(
        [
            Road(id="diagonal_a", source="n0_0", target="n1_1"),
            Road(id="diagonal_b", source="n1_0", target="n0_1"),
        ]
    )
    assert any("sans intersection" in error for error in validate_network(network))


def test_curved_road_shape_requires_network_endpoints():
    network = generate_grid(2, 2)
    road = next(road for road in network.roads if road.id == "n0_0__n1_0")
    road.shape = [(0, 0), (50, 20), (100, 0)]
    assert validate_network(network) == []
    road.shape[0] = (1, 0)
    assert any("géométrie doit commencer" in error for error in validate_network(network))


def test_conflicting_green_is_rejected():
    with pytest.raises(ValueError, match="incompatibles"):
        validate_phase("GG", {(0, 1)})
    validate_phase("Gr", {(0, 1)})


def test_duration_is_bounded_and_nan_rejected():
    assert safe_green_duration(1000) == 60
    assert safe_green_duration(-1) == 10
    with pytest.raises(ValueError):
        safe_green_duration(float("nan"))


def test_max_pressure_responds_to_vehicle_and_pedestrian_pressure():
    controller = MaxPressureController()
    low = controller.green_duration(Observation(0, 0, 0))
    high = controller.green_duration(Observation(0, 8, 3, phase_pressure=8, pedestrian_pressure=3))
    assert controller.name == "max_pressure"
    assert high > low
    assert high <= 60
