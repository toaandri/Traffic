import argparse
import asyncio
from pathlib import Path

from traffic.domain.models import Scenario
from traffic.metrics.export import export_snapshots
from traffic.network.grid import generate_grid
from traffic.simulation.session import SimulationSession
from traffic.storage.projects import load_scenario, save_scenario


def main():
    parser = argparse.ArgumentParser(description="Traffic : simulation locale SUMO")
    parser.add_argument(
        "command", choices=["generate", "run", "serve", "doctor", "compare", "stress"]
    )
    parser.add_argument("--scenario", type=Path, default=Path("data/scenarios/grid.json"))
    parser.add_argument("--output", type=Path, default=Path("data/generated/demo"))
    parser.add_argument("--steps", type=int, default=100)
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--seeds", type=int, nargs="+", default=[42, 43, 44])
    parser.add_argument("--controller", choices=["fixed", "adaptive", "max_pressure"])
    parser.add_argument("--rows", type=int, default=3)
    parser.add_argument("--columns", type=int, default=3)
    args = parser.parse_args()
    if args.command == "doctor":
        import subprocess

        import sumolib

        for executable in ("sumo", "netconvert"):
            subprocess.run([sumolib.checkBinary(executable), "--version"], check=True)
        return
    if args.command == "generate":
        save_scenario(Scenario(network=generate_grid(args.rows, args.columns)), args.scenario)
        print(f"Scénario sauvegardé : {args.scenario}")
        return
    scenario = load_scenario(args.scenario)
    if args.controller:
        scenario.controller = args.controller
    if args.command == "stress":
        from traffic.experiments.stress import run_stress

        run_stress(scenario, args.seeds, args.output)
        return
    if args.command == "compare":
        from traffic.experiments.compare import run_comparison

        report = run_comparison(scenario, args.seeds, args.output)
        print(f"Comparaison terminée : {len(report['runs'])} essais dans {args.output}")
        return
    if args.command == "serve":
        from traffic.bridge.server import serve_simulation

        try:
            asyncio.run(serve_simulation(scenario, args.output, args.port))
        except KeyboardInterrupt:
            print("Service arrêté.")
        return
    if args.steps <= 0:
        parser.error("--steps doit être positif")
    session = SimulationSession(scenario, args.output)
    try:
        snapshots = []
        for _ in range(args.steps):
            snapshot = session.step()
            snapshots.append(snapshot)
            if snapshot["time"] >= scenario.duration:
                break
        export_snapshots(snapshots, Path("data/results/demo"))
        print(
            f"Simulation vérifiée : {snapshots[-1]['time']} s, "
            f"{snapshots[-1]['metrics']['active']} véhicules actifs."
        )
    finally:
        session.close()


if __name__ == "__main__":
    main()
