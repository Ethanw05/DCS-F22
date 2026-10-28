"""Build the playable Caucasus EW strike mission using stock DCS ground units.

Run from the primary checkout with Python 3 and --lua pointing to DCS/bin/luae.exe.
The optional --install path is the user's Saved Games/DCS directory.
"""

from __future__ import annotations

import argparse
import hashlib
import math
from pathlib import Path
import re
import shutil
import subprocess
import zipfile


ROOT = Path(__file__).resolve().parents[1]
NAME = "F22-EW-Gauntlet.miz"
ALPHA = (-277100.0, 659228.57)
BRAVO = (-280514.57, 700581.43)
START = (-315000.0, 590000.0)
BATUMI = (-355396.8125, 616600.5)
PBU = "Ural-375 PBU"
S300 = ["S-300PS 54K6 cp", "S-300PS 64H6E sr", "S-300PS 40B6M tr"]
S300 += ["S-300PS 5P85C ln"] * 2 + ["S-300PS 5P85D ln"] * 4
BUK = ["SA-11 Buk CC 9S470M1", "SA-11 Buk SR 9S18M1"]
BUK += ["SA-11 Buk LN 9A310M1"] * 2

BRIEFING = """F-22A / EW GAUNTLET
Caucasus: Senaki - Lanchkhuti - Kutaisi valley. Daylight, clear weather.

MISSION
Destroy the command truck at ALPHA (steerpoint 3) and the fuel tanker at BRAVO
(steerpoint 4), then recover to Batumi. Each objective has supporting vehicles.
Six armed convoys patrol the valley roads; attack them as secondary targets.
You may choose your own ingress, attack order and altitude. No friendly ground
forces are in the target area.

THREATS
An S-300PS battery covers the eastern area, with two Buk batteries to the west
and centre. Tor and Osa protect the approaches. Tunguska, Strela-10, Igla-S,
Shilka and ZU-23 teams defend objectives and patrol routes. All hostile ground
units have EXCELLENT skill and are active from the start.

Use the aircraft's defensive controls, jammer and countermeasures as needed.
The jammer is not a shield; IR missiles and gunfire require separate avoidance.

AIRCRAFT
Airborne over the sea southwest of the threat area, 13,800 ft MSL, 447 KTAS.
Two GBU-32 JDAMs, two AIM-120C, two AIM-9X, full gun, 8,200 kg fuel,
120 chaff and 120 flares. Select A/G, arm, select AUTO, and designate the
selected target steerpoint or a ground-radar target. Hold release through the
release cue; release the button between bombs. The gun can attack remaining
vehicles. Ground radar GMT can help locate moving convoys.

ROUTE / RECOVERY
1 START; 2 INGRESS; 3 ALPHA command truck; 4 BRAVO fuel tanker;
5 EGRESS; 6 BATUMI overhead. Batumi is friendly and available for rearming.
ATC 131.000 AM / 260.000 AM; TACAN BTM 16X; ILS ILU 110.30.
Land manually. You can continue attacking and rearm rather than end the sortie.
"""


def combo(tasks: list[dict] | None = None) -> dict:
    return {"id": "ComboTask", "params": {"tasks": tasks or []}}


def action(number: int, action_id: str, params: dict) -> dict:
    return {"number": number, "auto": False, "enabled": True,
            "id": "WrappedAction", "params": {"action": {
                "id": action_id, "params": params}}}


def waypoint(name: str, position: tuple, altitude: float, speed: float) -> dict:
    return {"name": name, "x": position[0], "y": position[1], "alt": altitude,
            "alt_type": "BARO", "type": "Turning Point", "action": "Turning Point",
            "speed": speed, "speed_locked": True, "ETA_locked": False,
            "task": combo()}


def set_route_timing(points: list[dict]) -> None:
    """Match me_mission.lua: time-lock waypoint 1, speed-lock later legs."""
    elapsed = 0.0
    for index, point in enumerate(points):
        if index:
            previous = points[index - 1]
            elapsed += math.hypot(point["x"] - previous["x"],
                                  point["y"] - previous["y"]) / point["speed"]
        point["ETA"] = elapsed
        point["ETA_locked"] = index == 0


def player_country() -> dict:
    route = [waypoint("START", START, 4200, 230),
             waypoint("INGRESS", (-300000, 630000), 3000, 230),
             waypoint("ALPHA COMMAND", ALPHA, 3500, 230),
             waypoint("BRAVO FUEL", BRAVO, 4500, 230),
             waypoint("EGRESS", (-305000, 650000), 4000, 230),
             waypoint("BATUMI OVERHEAD", BATUMI, 1000, 150)]
    set_route_timing(route)
    heading = math.atan2(route[1]["y"] - START[1], route[1]["x"] - START[0])
    payload = {"fuel": 8200, "flare": 120, "chaff": 120, "gun": 100,
               "pylons": {1: {"CLSID": "{AIM9X-BLKII}"},
                          3: {"CLSID": "{40EF17B7-F508-45de-8566-6FFECC0C1AB8}"},
                          5: {"CLSID": "{GBU_32_V_2B}"},
                          7: {"CLSID": "{GBU_32_V_2B}"},
                          9: {"CLSID": "{40EF17B7-F508-45de-8566-6FFECC0C1AB8}"},
                          11: {"CLSID": "{AIM9X-BLKII}"}}}
    unit = {"name": "Raptor EW Gauntlet", "unitId": 1, "type": "F-22A",
            "skill": "Player", "x": START[0], "y": START[1], "alt": 4200,
            "alt_type": "BARO", "speed": 230, "heading": heading, "psi": -heading,
            "livery_id": "default", "onboard_num": "022", "payload": payload,
            "AddPropAircraft": {"BAY_DOOR_OPTION": False},
            "callsign": {1: 1, 2: 1, 3: 1, "name": "Enfield11"}}
    group = {"name": "Raptor EW Strike", "groupId": 1, "task": "Ground Attack",
             "tasks": [], "units": [unit], "route": {"points": route},
             "x": START[0], "y": START[1], "start_time": 0, "hidden": False,
             "lateActivation": False, "uncontrolled": False, "uncontrollable": False,
             "communication": True, "radioSet": True, "frequency": 131,
             "modulation": 0, "dynSpawnTemplate": False}
    return {"id": 2, "name": "USA", "plane": {"group": [group]}}


def ground_group(index: int, name: str, types: list[str], position: tuple,
                 destination: tuple | None = None, spacing: float = 85) -> dict:
    x, y = position
    heading = math.atan2(destination[1] - y, destination[0] - x) if destination else 0
    units = []
    for offset, unit_type in enumerate(types):
        # Convoys start in column; stationary batteries have a dispersed grid.
        dx = -offset * spacing * math.cos(heading) if destination else (offset % 3) * spacing
        dy = -offset * spacing * math.sin(heading) if destination else (offset // 3) * spacing
        units.append({"name": f"{name} {offset + 1}", "unitId": 1000 + index * 20 + offset,
                      "type": unit_type, "skill": "Excellent", "x": x + dx, "y": y + dy,
                      "heading": heading, "playerCanDrive": False, "coldAtStart": False})
    # Installed me_action_db.lua: 9 ALARM_STATE/2 RED; 0 ROE/0 WEAPON_FREE.
    ready = [action(1, "Option", {"name": 9, "value": 2}),
             action(2, "Option", {"name": 0, "value": 0})]
    point = {"x": x, "y": y, "type": "Turning Point", "action": "On Road" if destination else "Off Road",
             "speed": 10 if destination else 0, "speed_locked": True, "ETA_locked": False,
             "task": combo(ready)}
    route = [point]
    if destination:
        route.append({"x": destination[0], "y": destination[1], "type": "Turning Point",
                      "action": "On Road", "speed": 10, "speed_locked": True,
                      "ETA_locked": False, "task": combo([action(1, "SwitchWaypoint", {
                          "fromWaypointIndex": 2, "goToWaypointIndex": 1})])})
    set_route_timing(route)
    return {"name": name, "groupId": 100 + index, "x": x, "y": y,
            "units": units, "route": {"points": route}, "task": "Ground Nothing",
            "tasks": [], "start_time": 0, "lateActivation": False, "uncontrolled": False,
            "hidden": False, "visible": False, "hiddenOnPlanner": False}


def ground_forces() -> list[dict]:
    sites = [
        ("ALPHA COMMAND", [PBU, "SKP-11", "Ural-375", "MTLB", "Ural-375"], ALPHA, 55),
        ("BRAVO FUEL", ["ATZ-10", "ATZ-10", "Ural-375", "Ural-375", PBU], BRAVO, 55),
        ("S300 EAST", S300, (-274500, 706000), 220),
        ("BUK WEST", BUK, (-282471, 643971), 180),
        ("BUK CENTRAL", BUK, (-284414, 684710), 180),
        ("TOR ALPHA", ["Tor 9A331"], (-278100, 658400), 85),
        ("TOR BRAVO", ["Tor 9A331"], (-279500, 699400), 85),
        ("TOR VALLEY", ["Tor 9A331"], (-288800, 672228), 85),
        ("OSA WEST", ["Osa 9A33 ln"], (-273400, 635521), 85),
        ("OSA SOUTH", ["Osa 9A33 ln"], (-296428, 655921), 85),
    ]
    # Four local defence rings cover the two objectives and central approaches.
    rings = [(-277850, 660000), (-281300, 701000),
             (-289500, 671400), (-295700, 656800)]
    for index, (x, y) in enumerate(rings, 1):
        sites.extend([
            (f"TUNGUSKA {index}", ["2S6 Tunguska"], (x, y), 85),
            (f"STRELA {index}", ["Strela-10M3"], (x + 480, y + 350), 85),
            (f"SHILKA {index}", ["ZSU-23-4 Shilka"], (x - 380, y + 420), 85),
            (f"IGLA {index}", ["SA-18 Igla-S comm"] + ["SA-18 Igla-S manpad"] * 2,
             (x + 280, y - 400), 25),
            (f"ZU23 {index}", ["ZU-23 Emplacement Closed"], (x - 500, y - 300), 85),
        ])
    sites += [("ZU23 WEST", ["ZU-23 Emplacement"], (-282900, 644600), 85),
              ("ZU23 EAST", ["ZU-23 Emplacement"], (-283800, 685500), 85)]
    groups = [ground_group(i, name, types, pos, spacing=spacing)
              for i, (name, types, pos, spacing) in enumerate(sites, 1)]
    legs = [((-281800, 644800), (-277600, 658500)),
            ((-288300, 672600), (-284900, 684200)),
            ((-272900, 636000), (-277600, 658000)),
            ((-302800, 669000), (-296900, 656400)),
            ((-283900, 685000), (-281000, 699900)),
            ((-297200, 633400), (-296900, 655000))]
    for index, (start, end) in enumerate(legs, 1):
        escort = "Strela-10M3" if index % 2 else "2S6 Tunguska"
        types = ["T-72B3", "BMP-2", "Ural-375", "ATZ-10", "Ural-375 ZU-23", escort]
        groups.append(ground_group(len(groups) + 1, f"CONVOY {index}", types, start, end, 35))
    return groups


def coalition(name: str, countries: list[dict]) -> dict:
    return {"name": name, "bullseye": {"x": ALPHA[0], "y": ALPHA[1]},
            "nav_points": [], "country": countries}


def mission_overrides(groups: list[dict]) -> dict:
    return {"sortie": "F-22A - EW Gauntlet", "descriptionText": BRIEFING,
            "descriptionBlueTask": BRIEFING, "descriptionRedTask": "",
            "date": {"Year": 2020, "Month": 6, "Day": 15}, "start_time": 36000,
            "coalitions": {"blue": [2], "red": [0], "neutrals": []},
            "coalition": {"blue": coalition("blue", [player_country()]),
                          "red": coalition("red", [{"id": 0, "name": "Russia",
                                                     "vehicle": {"group": groups}}]),
                          "neutrals": coalition("neutrals", [])},
            "map": {"centerX": -294000, "centerY": 658000, "zoom": 150000},
            "forcedOptions": {"immortal": False, "unlimitedWeapons": False,
                              "unlimitedFuel": False}, "currentKey": 3000}


def lua(value: object, level: int = 0) -> str:
    """Serialize our bounded, acyclic mission plan (maximum depth 20)."""
    if level > 20:
        raise ValueError("Mission plan nesting exceeds 20")
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        if not math.isfinite(value):
            raise ValueError("Non-finite mission value")
        return repr(value)
    if isinstance(value, str):
        return '"' + value.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n') + '"'
    items = enumerate(value, 1) if isinstance(value, list) else value.items()
    indent = "    " * level
    return "{\n" + "".join(f"{indent}    [{lua(k, level + 1)}] = {lua(v, level + 1)},\n"
                          for k, v in items) + indent + "}"


def validate_plan(groups: list[dict], dcs_root: Path) -> None:
    database = (dcs_root / "Scripts/Database/db_countries.lua").read_text(encoding="utf-8-sig")
    available = set(re.findall(r'cnt_unit\(\s*units\.Cars\.Car,\s*"([^"]+)"', database))
    units = [unit for group in groups for unit in group["units"]]
    for unit in units:
        assert unit["type"] in available, f"Unknown DCS ground type: {unit['type']}"
        assert unit["skill"] == "Excellent"
    assert len(units) < 150
    assert len({u["unitId"] for u in units}) == len(units)
    assert len({u["name"] for u in units}) == len(units)
    assert len({g["groupId"] for g in groups}) == len(groups)
    convoys = [g for g in groups if g["name"].startswith("CONVOY ")]
    assert len(convoys) == 6
    assert all(len(g["units"]) == 6 for g in convoys)
    print(f"Plan: {len(groups)} hostile groups, {len(units)} Excellent ground units, 6 looping convoys")


def stage_route_verifier(stage: Path, dcs_root: Path) -> None:
    # Execute the installed Mission Editor's actual timing validator offline.
    # Its small dependency-free section needs only the translation identity.
    source = (dcs_root / "MissionEditor/modules/me_route.lua").read_text(encoding="utf-8-sig")
    start = source.index("local function getWptWithFlags(")
    end = source.index("\nfunction verifyWptTasks(", start)
    verifier = source[start:end] + "\nreturn verifyRoute\n"
    (stage / "route_verifier.lua").write_text(verifier, encoding="utf-8")


def build(lua_exe: Path, install: Path | None) -> None:
    dcs_root = lua_exe.parent.parent
    groups = ground_forces()
    validate_plan(groups, dcs_root)
    stage = ROOT / "out/ew-gauntlet"
    stage.mkdir(parents=True, exist_ok=True)
    stage_route_verifier(stage, dcs_root)
    template = ROOT / "Missions/Ground Attack/F-22A - Ground Attack - JDAM AUTO.miz"
    with zipfile.ZipFile(template) as archive:
        for name in archive.namelist():
            target = stage / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.read(name))
    (stage / "overrides.lua").write_text("return " + lua(mission_overrides(groups)), encoding="utf-8")
    subprocess.run([str(lua_exe), str(ROOT / "tools/compose_ew_gauntlet.lua"),
                    str(stage)], cwd=ROOT, check=True)
    output = ROOT / "Missions/Ground Attack" / NAME
    names = ["mission", "warehouses", "options", "theatre",
             "l10n/DEFAULT/dictionary", "l10n/DEFAULT/mapResource"]
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for name in names:
            archive.write(stage / name, name)
    with zipfile.ZipFile(output) as archive:
        assert archive.testzip() is None, "Corrupt mission archive"
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    print(f"Built {output} / SHA256 {digest}")
    if install:
        destinations = [install / "Missions" / NAME,
                        install / "Mods/aircraft/F-22A/Missions/Ground Attack" / NAME]
        for target in destinations:
            if not target.parent.is_dir():
                raise FileNotFoundError(f"Install directory not found: {target.parent}")
            shutil.copy2(output, target)
            assert hashlib.sha256(target.read_bytes()).hexdigest() == digest
            print(f"Installed and hash-verified: {target}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lua", type=Path, required=True)
    parser.add_argument("--install", type=Path)
    args = parser.parse_args()
    build(args.lua.resolve(), args.install.resolve() if args.install else None)
