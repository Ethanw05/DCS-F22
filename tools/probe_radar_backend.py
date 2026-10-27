"""Read-only PE/archived-telemetry probe. Never loads DLLs or starts DCS."""
from pathlib import Path
import argparse
import csv
import hashlib
import json
import math
import struct


def binary_profile(path):
    data = path.read_bytes()
    if data[:2] != b"MZ":
        raise ValueError("Expected PE image")
    offset = struct.unpack_from("<I", data, 0x3C)[0]
    if offset > len(data) - 0x100 or data[offset:offset + 4] != b"PE\0\0":
        raise ValueError("Invalid PE header")
    stamp = struct.unpack_from("<I", data, offset + 8)[0]
    size = struct.unpack_from("<I", data, offset + 24 + 56)[0]
    return {"path": str(path.resolve()), "sha256": hashlib.sha256(data).hexdigest(),
            "timestamp": hex(stamp), "image_size": hex(size),
            "matches_existing_adapter_profile": stamp == 0x6AC12468 and size == 0x59A000}


def telemetry(path):
    schema, count, phase_changes, beam_changes = None, 0, 0, 0
    previous = None
    phases, angles, modes = [], [], set()
    with path.open(encoding="utf-8", errors="replace") as source:
        for index, line in enumerate(source):
            if index >= 1_000_000:
                raise ValueError("Probe line limit exceeded")
            if "F22_RADAR_TEST" not in line or "): v1," not in line:
                continue
            values = next(csv.reader([line.split("): ", 1)[1]]))
            if values[1] == "avionics_schema":
                schema = values[2:]
            if values[1] != "avionics_sample" or schema is None:
                continue
            if len(values[2:]) != len(schema):
                continue
            row = dict(zip(schema, map(float, values[2:])))
            if row.get("F22_RADAR_NATIVE_SCAN_REF_BEAM_VALID") != 1:
                continue
            phase = row["F22_RADAR_NATIVE_SCAN_PHASE"]
            angle = row["F22_RADAR_NATIVE_SCAN_REF_BEAM_AZ"]
            center = row["F22_RADAR_NATIVE_PATTERN_AZ"]
            time = row["t_model_s"]
            if not all(math.isfinite(v) for v in (phase, angle, center, time)):
                continue
            count += 1
            modes.add(row.get("F22_RADAR_MODE_CODE", -1))
            phases.append(phase)
            angles.append(math.degrees(angle))
            if previous and time > previous[0] and abs(center - previous[3]) < 1e-6:
                phase_changes += abs(phase - previous[1]) > 1e-5
                beam_changes += abs(angle - previous[2]) > math.radians(0.05)
            previous = time, phase, angle, center
    return {"path": str(path.resolve()), "valid_beam_samples": count,
            "phase_changes_at_fixed_command": phase_changes,
            "beam_changes_at_fixed_command": beam_changes,
            "scan_phase_range": [min(phases), max(phases)] if phases else None,
            "scan_reference_azimuth_deg": [min(angles), max(angles)] if angles else None,
            "display_mode_codes": sorted(modes),
            "qualification": "Archived native motion evidence; not a test of current source or electronic step response"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dll", type=Path)
    parser.add_argument("--log", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = {"binary": binary_profile(args.dll) if args.dll else None,
              "telemetry": telemetry(args.log) if args.log else None}
    encoded = json.dumps(result, indent=2)
    if args.output:
        args.output.write_text(encoded + "\n", encoding="utf-8")
    print(encoded)


if __name__ == "__main__":
    main()
