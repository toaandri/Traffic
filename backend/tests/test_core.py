import pytest
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


def test_conflicting_green_is_rejected():
    with pytest.raises(ValueError, match="incompatibles"):
        validate_phase("GG", {(0, 1)})
    validate_phase("Gr", {(0, 1)})


def test_duration_is_bounded_and_nan_rejected():
    assert safe_green_duration(1000) == 60
    assert safe_green_duration(-1) == 10
    with pytest.raises(ValueError):
        safe_green_duration(float("nan"))
