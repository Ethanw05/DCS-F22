"""Run with IDA -A -S to preserve targeted SAR interface decompilations.

Reads out/sar-research/ida/<input-stem>-targets.json. This is offline analysis;
it never loads a DCS DLL for execution or modifies the simulator installation.
"""
from pathlib import Path
import hashlib
import json
import time

import ida_auto
import ida_hexrays
import ida_kernwin
import ida_loader
import ida_nalt
import idautils
import idc


def run():
    output = Path(__file__).resolve().parents[1] / "out/sar-research/ida"
    binary = Path(ida_nalt.get_input_file_path())
    label = binary.stem
    targets = json.loads((output / (label + "-targets.json")).read_text())
    started = time.perf_counter()
    ida_auto.auto_wait()
    available = ida_hexrays.init_hexrays_plugin()
    if not available:
        ida_loader.load_plugin("hexx64")
        available = ida_hexrays.init_hexrays_plugin()
    report = {
        "input": str(binary),
        "sha256": hashlib.sha256(binary.read_bytes()).hexdigest(),
        "image_base": hex(ida_nalt.get_imagebase()),
        "hexrays": available,
        "targets": [],
    }
    for target in targets:
        address = ida_nalt.get_imagebase() + int(target["rva"], 0)
        entry = dict(target, address=hex(address))
        try:
            if not available:
                raise RuntimeError("Hex-Rays initialization failed")
            text = str(ida_hexrays.decompile(address))
            path = output / (label + "-" + target["rva"] + ".c")
            path.write_text(text, encoding="utf-8")
            entry["decompilation"] = path.name
            entry["xrefs"] = [hex(x.frm) for x in idautils.XrefsTo(address)][:64]
        except Exception as error:
            entry["error"] = str(error)
        report["targets"].append(entry)
    report["elapsed_s"] = time.perf_counter() - started
    (output / (label + "-analysis.json")).write_text(json.dumps(report, indent=2))
    ida_kernwin.msg("SAR interface research: %s\n" % json.dumps(report))


if __name__ == "__main__":
    try:
        run()
    finally:
        idc.qexit(0)
