# Overhaul implementation change log — 24 October 2026

Changes are committed to **`main`**, the repository's active development branch. This is not an independent release or fully in-game-tested build.

## Implemented (build verified, DCS runtime unverified)

- Historical counter-pointer HUD with synthesized analog pointers, pitch ladder, flight-path marker and intentionally C-130-inspired heading tape. Model HUD connectors/VR optics and inherited HUD conflict still open.
- Actor/actuator rate update now uses `dt`; approximate old tuning normalized from 0.006-s expectation, not measured hardware schedules.
- EFM thrust vector now rotates the full net engine thrust with sine/cosine, and uses current frame force rather than stale engine values.
- Fixed damage array size/index bound through enumerator index 136.
- Tank callbacks store supplied actual fuel and coordinates. During burn, tank map and total remain synchronized; mass callback represents actual removed/added fuel only. External-first feed and per-station refuel limits are open approximations.
- Engine combustion feedback represents RUNNING vs stopped state.
- Ground speed uses earth-relative velocity, not air-relative wind subtraction.
- Cockpit quantity data sourced from EFM state, not inferred from a fixed 18,078 lb internal full quantity. Barometric and radar altitude intended in feet. Symmetric hydraulic fault inhibit restored to both displayed circuits.
- Pinned Visual Studio 2022 runner instead of `windows-latest`, which migrated to VS 2026.

## HUD / radar / missile / A-G follow-up — current main

These changes improve the **presentation and data adapters** and are suitable for desktop DCS testing; they are not an independently complete APG-77/AIM-9/AIM-120/JDAM combat model:

| Area | Implemented code path | DCS proof still needed |
| --- | --- | --- |
| NAV HUD | F-22 historical counter-pointers, C-130-inspired heading bar, waypoint bearing/range/steering | Real HUD EDM connector, collimation, duplicate FC3 HUD |
| Radar RWS | Native-return-only B-scope plots for up to 12 `RADAR_CONTACT_nn_` handles, current-return freshness and radar power gates | Whether inherited FC3 exports any of these avSimpleRadar parameters |
| Radar STT | Native `RADAR_STT_*` telemetry bridge to HUD/PMFD: range, angular LOS, IFF, stale-data removal | Presence/accuracy of source parameters, actual lock/transition |
| Radar mode selection | RWS/TWS requested via native FC3 and synchronized with PMFD; VS, BORE, FLOOD request modes | True host mode readback and association with DCS weapon guidance |
| AIM-9 / AIM-120 HUD | Distinct mode presentations, live radar range/closure when provided, IR lock explicitly unavailable | Actual station ID/count and seeker/rocket status; no claimed shot-envelope validation |
| Gun HUD | Published M61A2 muzzle speed drives clearly marked **SIM** lead from changing STT range and LOS; gun trigger/bay interlocks | Full ballistics, cannon selected/ammunition actual, ED host command loop |
| A/G MAN / CCIP / CCRP | Real terrain-markpoint/visual designator, gravity-only `CCIP SIM` predicted point, `CCRP SIM` time-to-release | True DCS weapon selection, flight-model ballistic drag, native bombs/JDAM target data and release |
| Stock GBU-32 | Optional native GBU-32 entry for two internal bays; old custom weapon preserved for mission compatibility | Whether current FC3 host can release/guide it |

**Do not claim full radar or missile implementation.** Research confirms [avSimpleRadar provides RWS/STT only](https://modding.caffeinesimulations.com/Aircraft/Lua/Devices/avSimpleRadar/) and needs a simple-electric system, while [ED community examples warn of conflicts with FC3 guidance](https://forum.dcs.world/topic/188347-basic-radar-example-code/). Replacing the native stack requires an integrated sensor/electrical/SMS/weapon rewrite and in-simulator tests, not a Lua label change.

**Source trail**: [primary F-22 HUD evidence](HUD_SYMBOL_LEDGER.md), [native-radar bridge](RADAR_STT_DATA_BRIDGE.md), [tactical mode reference](TACTICAL_HUD_RADAR_EVIDENCE.md), [A/G ballistic estimate](AG_POINT_MASS_ESTIMATOR.md), [CCRP approximation](AG_CCRP_ESTIMATOR.md), [existing overall system audit](../../docs/audit/README.md).

## HUD, navigation, radar, weapons and avionics pass (main, 24 October 2026)

| Subsystem | Changed implementation | Evidence and follow-on |
| --- | --- | --- |
| **13 HUD** | Seven requested layers: NAV, BVR/AIM-120, VS/AIM-9, BORE/AIM-9, gun, FLOOD/AIM-9, A/G; target cues explicitly validity gated; historical counter-pointer flight layer preserved | [Tactical evidence](TACTICAL_HUD_RADAR_EVIDENCE.md), [HUD target contract](HUD_TARGET_INTERFACE.md). Exact combat symbols and EDM optical alignment still unverified |
| **15 NAV** | Standalone mission-route waypoint reader, current waypoint index, range and true bearing, forward body-frame cue with provisional FOV clipping | [NAV computer](NAV_HUD_COMPUTER.md); DCS heading convention and waypoint loading need in-game verification |
| **A/G markpoint** | ICP MARK computes terrain LOS intersection and tracks it as a visual mark; separate from actual guided bomb delivery | [Markpoint source/limitations](AG_MARKPOINT.md). No CCIP/CCRP ballistic computation, JDAM targeting or release handoff |
| **10 Radar** | HUD scan mode **requests** and PMFD `RWS SELECTED/TWS SELECTED` readouts; no fake tracks or ranges | [Radar/weapon integration](RADAR_WEAPON_INTEGRATION.md). FC3 inherited radar still required; no independent APG-77 model |
| **12 Stores/gun/bays** | Momentary pickle input, cancellation on master-arm/power/WOW changes, deferred native command until selected bay visually open, single timed main/left/right actuator and independent gun door | [Door research](WEAPON_BAY_ACTUATOR_REWRITE.md), [input edges](WEAPON_INPUT_EDGE_SEMANTICS.md). Native release proof, hydraulics, station/munition authority still unverified |
| **09 Avionics & 14 displays** | Nonnegative day/night brightness gain; dimming no longer clears alert/fault state; radar page selection labels | [Display evidence](AVIONICS_BRIGHTNESS_AND_WARNINGS.md). Multi-owner power/fault and display reversion remain incomplete |

**CI evidence:** [Run 40090211659](https://github.com/Ethanw05/DCS-F22/actions/runs/40090211659) passed Windows VS2022 EFM compile, Lua syntax checks, Lua 5.1 NAV geometry tests and experimental DLL upload for commit `d56555d`. The earlier test failed on a malformed invalid-input return signature and was corrected in the next commit. These checks validate code execution/syntax, not actual DCS missions or rendering.

**Important limitations:** the project is **not** a fully independent F-22 combat module. It still inherits FC3 F-15C radar/weapon/radio behavior and retains undocumented airframe coefficients, TVC allocations, subsystem approximations, and unavailable tactical targeting cues. Nothing new has been tested in the DCS cockpit/VR. No CFD.

### Remaining work by the original 16-system audit

| Original audit | Progress | Still needed |
| --- | --- | --- |
| 01 Integration | Partial | Full ED HUD EDM connector/VR registration, standalone device prototype, native weapons/AI and radio host contracts |
| 02 Aerodynamics/performance | Audited only | Public conditioned performance checks, mass-dependent coefficient validation, no CFD |
| 03 Flight controls | Partial primitives | Control-law/saturation/handling development, failure transitions |
| 04 Thrust vectoring | Partial force correction | Authentic allocator/rate envelope, nozzle asymmetry, testing |
| 05 Engines | Partial combustion state | RPM/shaft exports, thermal transients, installed engine/fuel deck |
| 06 Fuel | Partial conservation/ledger | Refill boundary cases, DCS host mass ownership, transfer calibration |
| 07 Ground | Partial suspension/WOW | Host feedback validation, tire/brake/taxi model |
| 08 Vehicle | Partial hydraulic display | Powered buses, reservoirs, ECS, oil, APU ownership |
| 09 Mission avionics | Partial sensor/power/display states | Canonical state ownership, track store, validity & fault propagation |
| 10 Radar/IRST | Requested mode labels only | Actual sensor feed/track manager and FC3-independent STT/TWS support |
| 11 EW/datalink | Audited only | Readback of native RWR/ECM and inventory, passive uncertainty model |
| 12 Stores/weapons | Partial door interlocks | True station selection, native launch state, ballistics, targeting |
| 13 HUD | Experimental layers | F-22 tactical reference verification, calibration, DCS display/load tests |
| 14 Displays | Partial warning/PMFD | Integrated source data and page states, failure modes |
| 15 Navigation/radios | Partial waypoint steering | INS/communication/engaged autopilot and field-of-view calibration |
| 16 Lifecycle/release | Partial damage/CI | Flight regressions, mission packages, multiplayer and release validation |

## Still not implemented or authenticated

- Standalone radar, weapon launch and external guided-weapon integration (F-15C/FC3 remains required).
- Verified cockpit EDM HUD connector, VR conformality, brightness/clipping and suppression of inherited HUD.
- Suspension feedback wired to on-ground state, **but** callback availability, sign conventions and wheel compression must be checked inside DCS; 2-m fallback remains when no feedback is supplied.
- Fully integrated vehicle buses/hydraulics/ECS, engine spool/temperature and calibrated flight-control gain maps.
- Exact late-service HUD tactical cues, F119 engine deck, APG-77 fusion and aircraft aerodynamic coefficients.

## Validation record

GitHub Windows build, modified Lua parsing, and experimental DLL upload passed at [Actions run 40087211369](https://github.com/Ethanw05/DCS-F22/actions/runs/40087211369). In-game and VR verification are still outstanding. Build alone does not validate runtime behavior.

## First in-game tests

1. Run cold, hot, and air starts. Check HUD appears on glass, no doubled inherited HUD, and no error in `dcs.log`.
2. Smooth 90°, 180°, 359° -> 000° turns; verify heading tape continues/wraps and attitude ladder rotates correctly.
3. IAS 99->100 knots and altitude 999->1000 ft pointer rotations; compare moving readouts vs FC/mission sensors.
4. Station partial fill, two tanks, burner consumption and aerial refueling; compare fuel visual state and mass/performance.
5. Hydraulic fault on both engines and battery/generator transitions. EFM still has no physical hydraulic constraints, so instruments are not proof of physical failure handling.

**No CFD or geometry-based aerodynamic fitting was performed.**
