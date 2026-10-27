# F-22A stores, delivery and CCIP implementation handoff

Updated: 2026-10-26. The original overhaul was source-only. A later explicitly owned controlled slot ran three SAFE pre-employment attempts and exposed queued native dispatch; no bomb release occurred. Its controls/logs/replays were restored and its simulator slot released. The asynchronous repair below is an isolated-build candidate, awaiting native flight qualification and a separately owned installation checkpoint.

## Implemented behavior

`Store_Capabilities.lua` supplies one numeric label table for the complete station diagram and the A/G class keys. It explicitly classifies the offered AIM-9, AIM-120, AIM-260 and MAKO A/A launchers instead of relying on missile-name substring matching. Defensive missiles, tanks, IRST, training stores and unknown stores remain visible in inventory. Ground employment lists bombs and the offered MAKO A/G; the latter is visibly unavailable because a verified ground-missile targeting/launch adapter does not exist. Recognizing AIM-260/MAKO A/A as MRM stores does not establish their aerodynamic/seeker performance as a real F-22 capability.

Every loaded A/G type retains two separate profiles. A profile stores delivery mode, total physical store quantity, one/two stores per pulse, time interval and impact spacing. `quantity = pulses * stores per pulse`; quantity is 1–8 and cannot exceed the selected usable inventory. A pair consists of two separately requested and acknowledged physical releases, rather than an unsupported claim of simultaneous release. Guided bombs default to AUTO and 200 ms; conventional bombs default to CCIP and 200 feet of impact spacing. These are mod defaults and limits.

Impact spacing compares the current terrain-corrected predicted impact with the preceding acknowledged pulse's impact along its captured ground-velocity axis. It does not rename a time interval as feet. It rejects a large cross-track turn and still requires current solution, achieved bay clearance, power, master arm and airborne state for every release. The 20 ms controller and time needed to obtain/acknowledge the next station's solution limit the smallest achievable physical spacing.

Each release hold freezes its type/profile, quantity, pulse definition, spacing/time and station target assignments. A launch function return is a request, including a nonzero return. A matching native launch event with real weapon ID or a matching station inventory decrease is required before advancing the program or incrementing `F22_AG_RELEASE_SEQUENCE`. The request freezes station, CLSID, count, weapon type, model time, native launch-sequence baseline and predicted impact. Native evidence must match mode 7, zero-based station, weapon type and a new event sequence/ID in the request's 0.8-second observation window. Timestamp tolerance is 20 ms. Rewind and timeout are rejected before interpreting evidence.

Native shot acknowledgement can precede the inventory update. That station is withheld until its count reconciles, preventing the prior shot's delayed decrement from acknowledging a new request. Cancellation, timeout and an exception also retain an unresolved station barrier; new consent cannot reuse an ambiguous physical request. Status is **RELEASE UNCONFIRMED** until a real decrement or changed store identity reconciles it. Other reconciled stations remain usable. A truly unsuccessful request may consequently leave the station unavailable until loadout/device reconciliation. Re-arming the identical CLSID/count does not establish that reconciliation: no verified rearm-complete reset event is implemented; recovery requires an observed decrement, removing/changing the payload identity, or a new device/session. The controller deliberately does not silently retry an unknown physical outcome.

SET TARGET copies the existing designation into a fixed coordinate for the selected loaded station; CLEAR removes that station assignment and returns to the live designation workflow. Two bombs can retain different coordinates. STN STEP also works in NAV without selecting an employment station. Returning to A/G prefers the programmed station. Stored coordinates do not follow a moving radar designation and do not provide moving-target lead. Changing the designation sequence during AUTO consent ends the hold. A live coordinate is captured at consent. Guided release waits for a native preparation acknowledgement matching station, target source/sequence/coordinates and the consumed ballistic solution sequence. Availability alone is insufficient. Preparation is separate from actual physical launch acknowledgement and inventory quarantine; cancellation/edit/SAFE while waiting cannot launch later when preparation arrives.

Guided AUTO now uses a separately identified **estimated LAR**, rather than the unguided CCIP/AUTO timing gate. It evaluates a correction ellipse around the selected native bomb's free-flight impact, target forward geometry, height and speed. The ellipse factors, 300–13,716 m height window, 100–360 m/s horizontal-speed window, 30-degree bank gate and 500 m minimum are mod estimates awaiting flight qualification. The nominal public 15-mile range ceiling is 24,140 m, not an assertion that every release condition achieves it. No alignment timer, classified F-22 envelope, GPS quality simulation, laser/moving-target guidance, PP coordinate keypad or fuze programmability is invented.

## CCIP and physical consumers

Real DCS timing disproved the old same-tick assumption: immediately after dispatch, request 1 still had response 0; the following native frame returned response 1 at request time +1 ms. The repaired owner retains one frozen request across activities, consumes the matching response before issuing its successor, and validates schema, station, type, sequence, source timestamp and current target context. A device recreation uses an identity above retained request/response counters, so an old response cannot be mistaken for a new same-time request. A queued command delayed beyond its predicted callback interval withholds a cue rather than restamping the measurement.

The request predicts release position and velocity one measured activity interval ahead, with bounded observed world acceleration (30 m/s² per component), plus remaining achieved bay travel. Bay travel already occurring during the callback wait is not counted twice. Frozen native request inputs, raw native response buffers and stable consumed impact/origin fields have separate namespaces. This estimates future aircraft-origin state; a qualified launcher/ejection displacement is still unavailable.

For conventional bombs, `NativeAGWeapons` returns 17 native trajectory vertices. Sixteen BombSight plane solves use the selected frozen native type and ownship wind proxy; quadratic height spacing approximates uniform descent-time sampling. Lua samples terrain every 50 m or less between vertices and refines the first crossing, so an intervening ridge can replace the final-plane impact. A final plane above a descending valley is refined below actual terrain in a subsequent real request; an unbracketed endpoint is not presented as impact. Work is bounded to 17 vertices, 256 subdivisions per span and 2,048 terrain subdivisions plus crossing refinement. Native trajectory failure suppresses the cue. Upward release velocity above 5 m/s currently withholds this descent-path cue rather than inventing the climb/apex segment. Missing/incompatible asynchronous native schema fails closed; the new Lua/native/weapon set must be integrated together.

Bay and gun door motion consume `EFM_ACTUATOR_AVAILABLE` when `EFM_VEHICLE_VALID > 0.5`; authority scales achieved movement rate. Zero supply holds actual door positions. Ground power and ground-crew requests do not bypass failed hydraulic supply. Readiness continues to use achieved door position; zero gun drive authority also stops an already firing native cannon with the door open. Native gun rate remains binary; no variable rounds-per-second adapter is claimed. Invalid EFM vehicle data selects the explicit legacy startup fallback. CCIP uses the same pressure-scaled bay rate; a closed door without supply or a predicted delay beyond one second withholds an unqualified future-state cue. An already open bay has zero opening delay.

`F22_AG_SOLUTION` logs ordinary-flight solution time, station/type/mode, measured aircraft position, predicted release origin, impact, time of flight, pitch/bank and terrain/LAR quality once per second. `F22_AG_RELEASE` logs each request's predicted impact/release origin, measured actual aircraft position, velocity/wind, pitch/bank, delay, solution age, remaining program quantity and selected target coordinates/source/identity. `F22_AG_RELEASE_ACK` separately logs actual accepted/failed evidence, request time, observed time, native-versus-inventory evidence and native event ID/sequence/time when available. An inventory acknowledgement alone does not supply an exact native launch timestamp. These records allow release-timing and HUD/ballistics investigations; they do not provide an observed bomb-impact detector.

Asynchronous fields: `F22_AG_SOLUTION_SCHEMA=2`, `TIME`/`REQUEST_TIME` (original source observation), `PUBLICATION_TIME`, `NATIVE_TIME`, `SEQUENCE`, `MEASUREMENT_AGE_SEC`, `NATIVE_LATENCY_SEC`, `PREDICTION_SEC`, `DELAY`, `FALL_TIME`, `IMPACT_{N,U,E}` and frozen `TARGET_{VALID,SOURCE,SEQUENCE,N,U,E}`. The full prefix is `F22_AG_SOLUTION_`. `F22_AG_OWN_{N,U,E}` and `F22_AG_RELEASE_V{N,U,E}` describe the consumed solution origin/velocity. Native-owned `F22_AG_BOMB_IMPACT_*` is a raw response buffer and is no longer release authority. `F22_AG_SOLUTION_TIME` remains the source request time; current publication does not erase its age. Native execution latency and observation freshness are checked separately: a result processed at +20 ms and observed at +50 ms is acceptable, while a result timestamp >10 ms ahead of its observation is rejected.

Native request schema 2 freezes `F22_AG_BOMB_REQUEST_{TIME,SEQUENCE,STATION,TYPE3,TYPE4,N,U,E,VN,VU,VE,WN,WU,WE,GROUND_LEVEL,TRAJECTORY}`. `VALID` is cleared before replacement and set last; it stays valid while waiting. `F22_AG_BOMB_ASYNC_SUPPORTED=2` is required. Native captures identity before solver work and rechecks validity/sequence before publishing. Guidance preparation publishes `F22_AG_GUIDANCE_CACHE_{VALID,TIME,STATION,SOLUTION_SEQUENCE,TARGET_SOURCE,TARGET_SEQUENCE,TARGET_N,TARGET_U,TARGET_E}`. The staged native payload hook rechecks current safety, consent and frozen identities using prebound immutable cockpit handles, without accessing its update thread's mutable handle map.

## Public display and input contract

All backend-owned SMS parameters receive an invalid/empty snapshot during source construction, before native indicators bind. Parent owns stores artwork, MFD page/menu routing, `F22_SMS_UI_PAGE`, ICP routing and HUD presentation.

| Command | Value / action |
| --- | --- |
| 10970 / 10971 | Previous / next loaded A/G class |
| 10972 / 10973 / 10974 | Quantity decrement / increment / time interval cycle |
| 10975 / 10976 | Begin quantity / time interval entry |
| 10977 / 10978 / 10979 / 10980 | Raw digit 0–9 / backspace / commit / cancel entry |
| 10981 | Direct one-based loaded A/G group index; `STORE_i_INDEX` exposes a displayed row's real index |
| 10982 / 10983 / 10984 | Profile 1/2 cycle / spacing-time unit toggle / single-pair toggle |
| 10985 / 10986 | Begin spacing feet / pulse count entry |
| 10987 / 10988 | Capture current designation for active station / clear that assignment |
| 10804 | Existing station step; NAV cycles the program station only |
| 10807 / 10808 / 10809 | Compatible GUN / CCIP / AUTO selection, also safe to program in NAV |

Entry fields: 1 total stores, 2 milliseconds (50–2000), 3 impact spacing feet (10–9999), 4 pulses. Entry errors: 1 quantity/pair/inventory, 2 time bounds, 3 empty, 4 overflow, 5 spacing bounds. Invalid entries retain the previous committed program. Entry requires powered bottom stores/program context. Profile/type/mode/station/target edits terminate held A/G consent. Master SAFE permits programming.

`Store_Capabilities.labels` and `.short_labels` are the universal label contract; `AG_Stores` exports the same arrays:

| Code | Label | Short |
| --- | --- | --- |
| 1 / 2 / 3 / 4 | MK-83 TRAINING / GBU-32 JDAM / GBU-32 LEGACY / BOMB | MK83 / GB32 / GB32 / BOMB |
| 5 / 6 | AIM-9M / AIM-9X | 9M / 9X |
| 7 / 8 / 9 | AIM-120 / AIM-120D / AIM-260 | 120 / 120D / 260 |
| 10 / 11 | MAKO A/A / MAKO A/G | MAKO / MAKO |
| 12 / 13 / 14 / 15 | FUEL / IRST / OTHER / CATM-9M | TANK / IRST / OTHER / CATM |

`F22_SMS_STATION_00..10_{LABEL,COUNT,PRESENT,SELECTED,ACTIVE,TARGET_VALID}` uses the native zero-based station indices. SELECTED marks stations of the selected ground class; ACTIVE identifies its one program/target station. `F22_SMS_STORE_1..5_{LABEL,COUNT,SELECTED,INDEX}` lists ground classes. Inventory retains defensive A/A stations regardless of master mode.

Scalar `F22_SMS_` fields: `LABEL`, `TYPE4`, `SELECTED_INDEX`, `WEAPON_TEXT`, `MODE_TEXT`, `AVAILABLE` (reported inventory), `READY_COUNT` (currently reconciled/requestable inventory), `PROFILE`, `QUANTITY`, `PULSES`, `PAIR` (1/2 stores), `INTERVAL_MODE` (0 ms / 1 impact feet), `INTERVAL_MS`, `SPACING_FT`, `REMAINING`, `RELEASE_PENDING`, `RELEASE_FAILED`, `FUZE_TEXT=STORE DEFAULT`, `FUZE_PROGRAMMABLE=0`, entry fields and `STATUS`/`STATUS_TEXT`. `MODE_AVAILABLE_1/2/3` is the compatibility mask for GUN/CCIP/AUTO. The cannon is independent of selected stores; guided bombs do not offer CCIP; MAKO A/G offers no unsupported bomb delivery mode.

Status codes: 1 RELEASING, 2 NO STORE, 3 QTY EXCEEDS LOAD, 4 MODE UNAVAILABLE, 5 PROGRAM SET, 6 RELEASE PENDING, 7 RELEASE UNCONFIRMED, 8 BACKEND UNAVAILABLE, 9 CHECK PAIR QTY.

Target fields: `F22_SMS_TARGET_{STATION,STATION_DISPLAY,VALID,SOURCE,SEQUENCE,N,U,E}`. STATION is zero-based or -1; STATION_DISPLAY is one-based or 0. SOURCE is 0 none, 1 live/captured designation, 2 explicit stored station coordinate. SEQUENCE is local coordinate identity, not a classified sensor track ID. Sole delivery target owner is Weapon_System: `F22_AG_DELIVERY_TARGET_{VALID,SOURCE,SEQUENCE,N,U,E}`. The radar's existing `HUD_AG_MARK_*` and `F22_AG_TARGET_SEQUENCE` contracts are preserved.

LAR fields: `F22_AG_LAR_{ESTIMATED,READY,REASON,MIN_M,MAX_M,RANGE_M}`; reason 0 in estimate, 2 height, 3 speed/vertical geometry, 4 behind, 5 outside estimate. Gate display of retained numbers with ESTIMATED/solution validity. Additional quality: `F22_AG_TERRAIN_PATH_VALID`, `F22_AG_BAY_PREDICTION_VALID`, `F22_BAY_ACTUATOR_{AUTHORITY,VALID}`.

## Files and verification

Owned implementation: `Cockpit/Scripts/Systems/{Store_Capabilities,AG_Stores,Weapon_System,AG_Ballistic_Computer,AG_Delivery}.lua`, `EFM/source/NativeAGWeapons.cpp`. No MFD, ICP, Raptor, CMake, engine, ground-radar or shared NativeSidewinder file was directly edited by this lane.

The narrow NativeSidewinder target-input/solution-station patch is in `docs/resources/research/patches/stores_native_ground_target.patch` with its baseline SHA256. Parent confirmed clean integration after tactical-owner coordination. Parent owns that combined native test/build integration; the stored baseline hash describes the source before integration, not the final file.

The subsequent asynchronous guidance-cache patch and test are staged separately at `D:/Codex-F22-Overhaul-2026-10-25/stores-controlled-flight-20261026-0525/async-stage/native-guidance-cache.patch`, with exact baseline/candidate hashes in its adjacent manifest. This lane did not directly modify shared `NativeSidewinder.cpp`. The isolated candidate source/build/artifacts, targeted Python output and 15/15 CTest result are under the same `async-stage` folder. The preceding real SAFE attempts and exact owned PID/mission/restoration evidence are in `RUN_REVIEW.md` and episode subfolders of the enclosing run folder.

Meaningful source checks passed:

- `test_overhaul_stores.py`: explicit capabilities, mode masks, profile retention, pair/pulse semantics, actual predicted-impact spacing, ridge crossing, guided estimate, SAFE NAV entry, two station targets and a function-return-without-physical-release failure.
- `test_overhaul_ballistics.py`: actual activity uses queued native dispatch, frozen input/output namespaces, distinct source/native/publication clocks, delayed/dropped/mismatched responses, reset ABA prevention, ridge/valley refinement, bounded prediction, stored targets and physical bay supply.
- `test_overhaul_guidance_cache.py`: the actual weapon owner waits for preparation, rejects wrong station/point/solve/old target, and preserves release/edit/SAFE cancellation while an acknowledgement is delayed. Actual inventory acknowledgement remains separate.
- `test_overhaul_stores_actuators.py`: failed supply freezes bay/gun doors, partial supply scales rates, achieved clearance gates release/fire, restored supply moves doors, GPU cannot bypass failed pressure, and invalid backend fallback is explicit.
- `test_overhaul_release_contract.py` (independent reviewer): all native identity/time predicates, count path, duplicate prevention, rewind/timeout, native-before-inventory quarantine, cancel/failure unresolved barriers and edit cancellation.
- `test_ag_delivery.py`, `test_ag_usability.py` (including parent-updated bezel/ICP integration), `test_combat_controls.py`, Lua parse validation; parent updates the changed bezel/menu fixture.
- Standalone expanded `test_native_ag_weapons.cpp` compiled and ran using installed VS 18: selected type/axes/wind, stale request rejection, balanced BombSight lifetime, 17 monotonic trajectory vertices and unsupported climbing trajectory. Parent subsequently reported the combined Debug DLL build and 14/14 CTest checks passing.

Audit disposition: WPN-01/02 receive concrete selection/transaction fixes; WPN-03 has station coordinates and an openly estimated guided envelope; WPN-04 has two profiles, total stores/pulses/pairs and real impact spacing while fuzing remains store default. BAL-02 has bounded native trajectory/terrain interception. BAL-01/03 gain release-state prediction and ordinary-flight instrumentation; **actual maneuvering-flight accuracy is still unqualified**.

## Resources and remaining acceptance

The implementation follows the audit's public-reference/adaptation boundary:

- [NAVAIR Direct Attack Weapons](https://www.navair.navy.mil/product/Direct-Attack-Weapons): unguided versus GPS/INS JDAM operation, independent single/multiple target coordinates, and functional fuze distinction. It does not supply this mod's ellipse factors or F-22 procedure.
- [USAF Joint Direct Attack Munition fact sheet](https://www.af.mil/About-Us/Fact-Sheets/Display/Article/104572/joint-direct-attack-munition-gbu-313238/joint-direct-attack-munition-gbu-313238/): public nominal range ceiling; no complete flight-condition LAR is published here.
- [National Museum of the USAF GBU-31/32](https://www.nationalmuseum.af.mil/Visit/Museum-Exhibits/Fact-Sheets/Display/Article/197589/gbu-3132-joint-direct-attack-munitions-jdam/): coordinate guidance and nominal reach, rather than moving-target homing.
- [Eagle Dynamics F/A-18C guide](https://www.digitalcombatsimulator.com/en/downloads/documentation/dcs-fa-18c_early_access_guide_en/) and [F-16C guide](https://www.digitalcombatsimulator.com/en/downloads/documentation/dcs-viper_early_access_manual_en/): program/quantity/interval workflow references already recorded in the parent audit. The bottom F-22 inventory diagram is preserved by the parent's visual lane.

Native acceptance still needs ordinary unpaused level/dive/banked drops, opening/open bays, winds, representative height/speed, separate predicted and observed impact measurements, two actual coordinate-guided bombs with distinct targets, timeout/refusal scenarios and pressure-loss/restoration. Measure along/cross error and HUD projection separately. The current wind proxy is one ownship wind vector at all trajectory heights. Aircraft-origin prediction does not establish launcher/ejection offsets. The descending trajectory is piecewise and finite, not a full time-step terrain collider; terrain features narrower than the sample spacing may be missed. Private BombSight ABI/build support, repeated plane-solve performance and real guided outcomes require host qualification. No synthetic regression is reported as proof that CCIP is now accurate in flight.
