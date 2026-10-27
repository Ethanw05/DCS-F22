"""Check the focused physical helpers; legacy callback exceptions are separate."""

import argparse
import hashlib
import importlib.metadata
import json
from pathlib import Path

import lizard


HEADERS = (
    "AirData.h", "VehicleLedger.h", "FuelSystem.h", "VehiclePower.h",
    "EngineController.h", "EngineStart.h", "VehicleSystems.h", "VehicleConfiguration.h",
    "VehicleEnvironment.h", "BrakeEnergy.h", "VehicleContext.h",
    "VehicleSignals.h", "VehicleFaults.h", "VehicleIntegration.h", "ThrustDeck.h",
)


def measure(root):
    functions = []
    hashes = {}
    for name in HEADERS:
        path = root / "EFM" / "source" / name
        hashes[name] = hashlib.sha256(path.read_bytes()).hexdigest()
        for function in lizard.analyze_file(str(path)).function_list:
            functions.append({
                "file": name, "name": function.name, "line": function.start_line,
                "ccn": function.cyclomatic_complexity, "nloc": function.nloc,
            })
    return {
        "tool": "lizard", "version": importlib.metadata.version("lizard"),
        "scope": "focused physical headers; excludes retained legacy force callback",
        "functions": len(functions),
        "maximum_ccn": max(item["ccn"] for item in functions),
        "maximum_nloc": max(item["nloc"] for item in functions),
        "above_preferred_ccn_10": [item for item in functions if item["ccn"] > 10],
        "violations": [item for item in functions
                       if item["ccn"] > 15 or item["nloc"] > 60],
        "source_sha256": hashes,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    report = measure(root)
    serialized = json.dumps(report, indent=2) + "\n"
    if args.report:
        args.report.write_text(serialized, encoding="utf-8")
    print(serialized, end="")
    return bool(report["violations"])


if __name__ == "__main__":
    raise SystemExit(main())
