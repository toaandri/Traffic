import math


def validate_phase(state: str, conflicts: set[tuple[int, int]]) -> None:
    if any(character not in "rRyYgGoOu" for character in state):
        raise ValueError("État de feu inconnu.")
    for first, second in conflicts:
        if not (0 <= first < len(state) and 0 <= second < len(state)):
            raise ValueError("Matrice de conflits incompatible avec la phase.")
        if state[first] in "gG" and state[second] in "gG":
            raise ValueError("Deux mouvements incompatibles sont autorisés.")


def safe_green_duration(requested: float, minimum: float = 10, maximum: float = 60) -> float:
    if not all(math.isfinite(value) for value in (requested, minimum, maximum)):
        raise ValueError("Durée non finie.")
    if minimum <= 0 or maximum < minimum:
        raise ValueError("Bornes de durée invalides.")
    return max(minimum, min(maximum, requested))
