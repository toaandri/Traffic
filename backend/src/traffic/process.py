import sys


def cli_command(*args: str) -> list[str]:
    if getattr(sys, "frozen", False):
        return [sys.executable, "--backend", *args]
    return [sys.executable, "-m", "traffic.cli", *args]
