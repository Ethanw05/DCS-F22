# F-22 in-game validation matrix — active main development branch

**This document is for the first player test after the 24 October 2026 commits.** Lua syntax/EFM build checks have passed, but no real DCS cockpit or VR validation has been performed from this session. A passing CI build is not a verified Raptor simulation.

## Getting the test build

1. Back up your currently working F-22 mod before swapping anything.
2. Checkout the GitHub `main` branch using Git LFS and submodules. `git clone --recurse-submodules https://github.com/Ethanw05/DCS-F22.git` and `git lfs pull`.
3. In GitHub [Actions → EFM Build Check](https://github.com/Ethanw05/DCS-F22/actions/workflows/check.yaml), open the latest **successful** run for the current main commit. Download `f22-efm-experimental`; place `f22.dll` in the mod's `bin` directory.
4. Install the working-copy mod in DCS Saved Games `Mods/aircraft` under the folder name used by your current install. Keep F-15C/FC3 dependency available: standalone native radar/missile integration has **not** been implemented.
5. After testing a failure, save `Saved Games/DCS/Logs/dcs.log` (or your DCS variant's log) and a screenshot or short capture in 2D/VR.

## Priority A: HUD startup/geometry

| Procedure | Expected / failure classification |
| --- | --- |
| Hot ramp start, open cockpit view | Custom F-22-style circular speed and altitude dials, horizon, flight path and C-130-inspired heading ribbon visible on glass. **If missing:** EDM connector/indicator registration or cockpit rendering path. |
| Cold start, battery on then generators/main power | HUD and displays follow modeled availability; no phantom values while unpowered. |
| 10°, 30°, 90° bank upright/inverted, climb and descent | Pitch ladder/horizon and FPM move in aircraft frame, no inverted symbols or unreasonable snapping. |
| Head translation in TrackIR/2D and both VR eyes | Symbol collimation and combiner alignment. **Known unverified**: `HUD-CENTER/HUD-DOWN/HUD-RIGHT` connector mapping. |
| IAS crossing 99→100 kt and 199→200 kt; altitude crossing 999→1000 ft | Counter pointer wraps smoothly while numeric values remain continuous. |
| Heading right/left through 359→000 degrees | No wrapping jumps beyond normal tick rollover; compare HUD to DCS instruments. |
| Turn brightness to 0; switch day/night; introduce a simulated caution | Display dims without clearing caution/failure source. No negative opacity. |

## Priority B: NAV mode

Create a simple mission with at least three waypoints, including a waypoint 10 km due north of takeoff and another due east.

- Select NAV (native PlaneModeNAV). The HUD should show `NAV`, selected `STPT` index, true/world `BRG` and range in nautical miles.
- Fly waypoint north from heading 000°; test east waypoint from heading 090°. Steering diamond appears only if the point is in the provisional ±15°/±12.5° HUD FOV.
- Use native next waypoint and existing previous-ICP bind. Verify range/bearing refer to the selected real mission point. A point behind should keep range but hide the conformal cue.
- **Note**: true heading vs magnetic and host API sign conventions need calibration; do not treat an unverified 90° offset as a flight-model error.

## Priority C: air-to-air and radar UI

| Mode | HUD requested | What is *not* promised |
| --- | --- | --- |
| BVR | `AIM-120`, selected RWS/TWS request, `NO TRACK` when no valid target | No independent APG-77 track/WEZ, AIM-120 midcourse cue or SHOOT |
| VS | `AIM-9`, generic boresight seeker-ring reference | No authenticated off-boresight cue or seeker tone/lock data |
| BORE | `AIM-9` and boresight reference | No independent radar lock/slew model |
| FLOOD | `AIM-9` and FLOOD request | No authenticated actual F-22 seeker presentation |
| CANNON | Gun boresight circular reference and `GUN NO RNG` | No lead-computing gunsight or authenticated ammo counter |

- Toggle Radar OSB15 and native mode-change keys; check PMFD selection RWS vs TWS and HUD `RWS REQ/TWS REQ`. **Selection ≠ measured radar scan state.**
- Toggle radar power; PMFD indicator should switch on/off appropriately. Actual detection still uses inherited FC3/F-15C implementation.
- Change master arm, wheel contact and electrical power: locally dispatched gun/pickle commands must not stay latched.
- Check gun first/second detent, door open/close, ammunition behavior and no unintended firing with gear down in flight vs actual WOW.

## Priority D: air-to-ground

- Select A/G mode. Expected `A/G` and initially `NO DESIGNATION`.
- Point nose downward toward visible terrain within ~40 km. Press enabled ICP `MARK` once. Expected local terrain intersection and `MARKPOINT` with distance, a diamond when visible. Press again to clear.
- Turn nose away: range remains but the diamond hides when offscreen. Switch modes/power: no valid displayed A/G designation outside its mode.
- Step the simulated MAN/CCIP/CCRP requests. **CCIP N/A and CCRP N/A are intentional**: no false ballistic impact point or release authorizations have been invented.
- JDAM target coordinate handoff, aircraft attack radar and native INS/GPS weapons delivery remain unimplemented.

## Priority E: engines, bays, fuel and lifecycle

- Cold/hot/air starts: battery should toggle only once on hot initialization; APU should spool with elapsed time and stop after an uninterrupted local 60-second auto-off qualification.
- Mixed cutoff: common throttle axis must animate only the engine with cutoff released, not freeze both.
- Switch left/right generator independently; test presence/absence of `MAIN_POWER` and degraded warnings against actual modeled supply.
- Ground GPU with bays: left crew service animation must not open unpowered center/right bay. Test main and side bay station selections 1/2/3/4; no door overshoot.
- Hold pickle while opening bay: native command should be sent only once bay is ≥98% open; cancel/ground/arm off must release command and close door if powered.
- Refuel partially filled internal/external tanks; check quantity and mass conservation, repeated reload callbacks, engine starvation at low fuel.
- Repair damage, respawn, repeat engine failure; no old destruction event should leak into the next aircraft.

## If something is wrong

Record DCS version, loadout, mission, weight/fuel, start type, input device and DCS log. Classify failure separately as **HUD rendering/EDM**, **sensor-data projection**, **combat host integration**, **actuator**, **engine/electrical**, **fuel ledger** or **DCS parameter bridge**. Screenshot alone cannot verify missile target support or an aircraft handling-quality curve.

See [the research and outstanding-work matrix](../resources/research/IMPLEMENTATION_STATUS.md); all changes are on `main`, not a separate release branch.


## Optional host-native GBU-32 compatibility experiment

The original `Weapons/GBU_32.lua` defines an alleged JDAM as `CAT_AIR_TO_AIR` and missile `wsTypeOfWeapon`, with a whole-bomb explosive fill. This is **not a valid JDAM simulation**. The legacy CLSID remains for existing mission compatibility, with its defective semantics plainly documented.

The two internal GBU-32 positions in `F-22A.lua` now also offer `{GBU_32_V_2B}`, identified by the widely used [pydcs DCS weapon database](https://github.com/pydcs/dcs/blob/master/dcs/weapons_data.py) as the stock GBU-32(V)2/B, approximately 467 kg total. [USAF F-22 fact sheet](https://www.af.mil/About-Us/Fact-Sheets/Display/Article/104506/f-22-raptor/) explicitly identifies **two internal 1,000-pound GBU-32 JDAMs** as a supported A/G fit.

The custom CLSID and stock CLSID are *alternatives* at each pylon. The **old preset remains untouched**; this is a test option, not a guaranteed usable JDAM. There is no integrated F-15C native coordinate-entry/INS weapon computer. In DCS test whether stock GBU-32 is loadable, whether actual released object is a bomb, whether host provides proper guidance (likely absent), weapon employment interlocks, and visual/physics agreement. Never display CCIP/CCRP release solutions without valid store/target data.
