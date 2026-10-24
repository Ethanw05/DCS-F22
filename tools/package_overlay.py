#!/usr/bin/env python3
"""Package tested Lua plus the Windows EFM over an existing complete F-22A install."""
import argparse
import hashlib
from pathlib import Path
import struct
import subprocess
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", default="dist/f22-overhaul-overlay-win64.zip")
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
dll = root / "bin/F22.dll"
data = dll.read_bytes()
if data[:2] != b"MZ":
    raise SystemExit("bin/F22.dll is not a Windows PE binary")
offset = struct.unpack_from("<I", data, 0x3C)[0]
if data[offset:offset + 4] != b"PE\0\0" or struct.unpack_from("<H", data, offset + 4)[0] != 0x8664:
    raise SystemExit("bin/F22.dll must be an x86-64 Windows binary")
sha = subprocess.check_output(
    ["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
files = [dll, root / "LICENSE", root / "EFM/LICENSE"]
for folder, pattern in [("Cockpit/Scripts", "*.lua"), ("Input", "*.lua"),
                        ("Weapons", "*.lua"), ("UnitPayloads", "*.lua"),
                        ("FM", "*.lua"), ("docs", "*.md")]:
    files.extend((root / folder).rglob(pattern))
files.extend(root / name for name in ["entry.lua", "F-22A.lua", "Weapons.lua", "Views.lua",
    "comm.lua", "IRST Sensor.lua", "IRST Pod.lua", "VLO Fuel Tank.lua"])
output = root / args.output
output.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
    for file in sorted(set(files)):
        if file.read_bytes().startswith(b"version https://git-lfs.github.com/spec/v1"):
            raise SystemExit(f"Refusing to package an LFS pointer: {file.relative_to(root)}")
        archive.write(file, "F-22A/" + file.relative_to(root).as_posix())
    archive.write(root / "docs/TEST_BUILD.md", "INSTALL_AND_TEST.md")
    archive.writestr("F-22A/BUILD_INFO.txt",
        f"Experimental overhaul overlay\nSource commit: {sha}\n"
        f"Source: https://github.com/Ethanw05/DCS-F22/tree/{sha}\n"
        f"F22.dll SHA256: {hashlib.sha256(data).hexdigest()}\n"
        "Requires complete upstream F-22A assets and F-15 combat avionics.\n"
        "No DCS runtime validation performed by CI.\n")
print(f"Created {output}: {len(files)} source/configuration/document files plus build metadata")
