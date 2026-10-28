"""Run with IDA -A -S to preserve targeted SAR interface decompilations.

Reads out/sar-research/ida/<input-stem>-targets.json. This is offline analysis;
it never loads a DCS DLL for execution or modifies the simulator installation.
"""
from pathlib import Path
import hashlib
import json
import struct
import time
from itertools import islice

import ida_auto
import ida_hexrays
import ida_kernwin
import ida_loader
import ida_nalt
import idautils
import idc


def file_backed_code(data, rva):
    pe = struct.unpack_from("<I", data, 0x3c)[0]
    if data[pe:pe + 4] != b"PE\0\0":
        raise ValueError("Input is not a PE image")
    count = struct.unpack_from("<H", data, pe + 6)[0]
    optional_size = struct.unpack_from("<H", data, pe + 20)[0]
    section_table = pe + 24 + optional_size
    for index in range(count):
        section = section_table + index * 40
        virtual = struct.unpack_from("<I", data, section + 12)[0]
        raw_size, raw_offset = struct.unpack_from("<II", data, section + 16)
        if virtual <= rva < virtual + raw_size:
            return raw_offset + rva - virtual < len(data)
    return False


def run():
    output = Path(__file__).resolve().parents[1] / "out/sar-research/ida"
    binary = Path(ida_nalt.get_input_file_path())
    label = binary.stem
    targets = json.loads((output / (label + "-targets.json")).read_text())
    started = time.perf_counter()
    data = binary.read_bytes()
    usable = any(file_backed_code(data, int(target["rva"], 0)) for target in targets)
    available = False
    if usable:
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
            if not file_backed_code(data, int(target["rva"], 0)):
                raise RuntimeError("No file-backed code; packed implementation is unqualified")
            if not available:
                raise RuntimeError("Hex-Rays initialization failed")
            function = ida_hexrays.decompile(address)
            if function is None:
                raise RuntimeError("Hex-Rays returned no function")
            text = str(function)
            path = output / (label + "-" + target["rva"] + ".c")
            path.write_text(text, encoding="utf-8")
            entry["decompilation"] = path.name
            entry["xrefs"] = [hex(x.frm) for x in islice(idautils.XrefsTo(address), 64)]
        except Exception as error:
            entry["error"] = str(error)
        report["targets"].append(entry)
    report["elapsed_s"] = time.perf_counter() - started
    (output / (label + "-analysis.json")).write_text(json.dumps(report, indent=2))
    ida_kernwin.msg("SAR interface research: %s\n" % json.dumps(report))


if __name__ == "__main__":
    status = 1
    try:
        run()
        status = 0
    finally:
        idc.qexit(status)
