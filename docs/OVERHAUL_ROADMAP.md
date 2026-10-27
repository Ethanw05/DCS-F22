# F-22 overhaul roadmap

Proposed 24 October 2026. Findings refer to [F01–F23 in the assessment](audit/README.md#retired-report-a20). The design and critical integration experiment are in [STANDALONE_DESIGN.md](STANDALONE_DESIGN.md).

## Working decisions

Build toward a standalone aircraft, using the current EFM/assets as a migration base. Preserve a known-working legacy combat build until independent host weapon integration is proven. First target a documented production F-22A approximation, with supported 3.2B-era capabilities identified individually. Keep speculative systems and later upgrades in optional profiles. These are recommended engineering defaults; aircraft configuration should be recorded before implementation changes make it ambiguous.

No audit framework or new audit tooling is part of this roadmap. Focused engineering checks and small reproducible missions should verify behavior as systems are implemented. Automated tests are useful for numerical invariants and state transitions; avoid tests that merely repeat implementation formulas.

## Milestones and completion gates

| Stage | Deliverable | Completion gate |
| --- | --- | --- |
| 0 — Reproducible baseline | Windows Release DLL, pinned DCS build, clean Saved Games install and a short baseline flight/weapon record. | Build/load succeeds; current dependency is reproduced; input and asset paths work. Record actual behavior before changing it. |
| 1 — Standalone integration proof | Independent boot, HUD, power, basic radio, weapon and radar devices. | Complete the [standalone experiment](STANDALONE_DESIGN.md#the-decisive-standalone-experiment). Resolve STT/TWS/missile support limitations explicitly. |
| 2 — Correct vehicle foundation | Fix F01–F09; establish canonical fuel/engine/contact state and time-based actuators. | Mass and quantity conserve; no overfill or restored fuel; constant elapsed-time responses across step sizes; physically consistent nozzle forces and WOW. |
| 3 — Independent flight cockpit | Own HUD, air-data/navigation service, ICP interactions, warnings and core MFD pages. | Fly a complete cold-start, departure, waypoint, instrument approach and shutdown without inherited avionics. Power/invalid-data states display correctly in 2D/VR. |
| 4 — Controlled flight-model overhaul | New control stages, coefficient model, surfaces, TVC and continuous approximate engine model. | Trim, step response, transitions and performance checks pass at declared mass/configuration/atmosphere; no unexplained energy gain or numerical instability. |
| 5 — Integrated combat aircraft | Shared tracks, radar/EW approximations, stores/bay sequencing and weapon cues. | End-to-end supported engagements and countermeasures work within the demonstrated host capability, with the same state driving release and displays. |
| 6 — Release hardening | Damage/repair, AI parity, multiplayer, packaging, settings and documentation. | Clean install works on a machine/profile without FC; clients/server agree; all advertised capabilities have evidence; unsupported features are disclosed. |

Stage 1 is a prerequisite for committing to a feature-complete independent combat release. Stage 2 numerical repairs can proceed while integration work is being validated. Stage 4 must follow fuel/thrust bookkeeping corrections; otherwise performance tuning absorbs defects and must be redone. Stages describe dependency order, not a calendar or a claim that one person can complete the project in a few weeks.

## Progress checkpoint — 24 October 2026

This repository's `main` branch is the user's development branch. Initial targeted repairs and experimental NAV/A-A/A-G HUD rendering now exist. **This does not close stages 1–6**; end-to-end completion gates still need DCS runtime tests, especially the borrowed FC3 radar/weapon host interface. See [the actual implementation status matrix](resources/research/IMPLEMENTATION_STATUS.md).

Verified on GitHub Actions only: Windows EFM compile, modified Lua parsing, and independent Lua 5.1 geometry test. No complete mission flight has been executed on the modified code.

## First implementation backlog

| Item | Work | Acceptance evidence |
| --- | --- | --- |
| O01 | Baseline Windows build and minimal mission record. | Release build log, installed file list, cold/hot/air start observations, DCS version. |
| O02 | Minimal standalone registration and own flight HUD. | Fresh process, no FC preload; flyable controls and aligned symbols. |
| O03 | Core power/radio/weapon/radar compatibility spike. | Gate-by-gate results, especially actual missile support and two-target behavior. |
| O04 | Fuel inventory and mass callbacks (F01–F05). | Partial tank initialization; empty/full boundary cases; internal/external burn; refuel; tank jettison; rearm/respawn. Quantity and host mass changes reconcile. |
| O05 | Time-based actuator primitive and physical nozzle force (F06/F08). | Same elapsed-time motion at dt 0.003/0.006/0.012; thrust direction and magnitude invariant checks; correct engine-out moments. |
| O06 | Contact/ground-speed state (F09). | Airborne gear-down pass below 50 m stays airborne; taxi/touchdown follows suspension contact; stationary aircraft in wind reports zero ground speed. |
| O07 | State/interface contract and display conversions (F14/F17–F19). | Documented producer, units, frame and validity; fuel/nozzle/surface synoptics agree with actual state. |
| O08 | Weapon permissions and lifecycle resets (F20–F22). | Trigger release through power/arm changes, gear transitions, failed bay, repair, restart and repeated destruction; bounded host-array writes. |
| O09 | Control-law and aerodynamic replacement specification (F10–F15). | Mode diagrams, command definitions, reference/assumption table and response targets before gain fitting. |
| O10 | AI/configuration cleanup (F16/F23). | Consistent geometry, explicit sensor/weapon profiles and no unsupported range/signature claims. |

The first useful code change should fix the fuel ledger or establish the standalone boot prototype. A texture refresh or a large page rewrite would not resolve either foundational problem.

## Validation conditions to record

Every flight result needs mass, internal/external fuel, stores, CG/configuration, altitude definition, temperature/pressure, wind, speed definition, thrust setting, input sequence and DCS build. Keep the measurement separate from any inferred aerodynamic coefficient.

| Group | Minimum useful cases |
| --- | --- |
| Numerical behavior | Finite force/moment outputs at zero speed, alpha/beta extremes and reversed flow; fuel/mass conservation; bounded state; step-size convergence; reset independence. |
| Handling qualities | Trim and doublets; neutral-stick behavior; maximum-command limiting; roll reversals; gear/approach/refueling transitions; saturation recovery; engine-out and reduced-hydraulic authority. |
| Performance | Takeoff/landing under stated conditions; level dry/AB acceleration at several altitudes; climb; sustained/instantaneous turns; deceleration and configuration drag. Keep empirical observations separate from public specification bounds. |
| High-alpha/TVC | Low-speed nose pointing, recovery, pedal turn and power-loop-type trajectories at stated energy/weight. Use [R131](RESOURCES.md#r131) demo profiles as conditioned checkpoints, not exact aircraft-identification data. |
| Display behavior | HUD projection with head translation/rotation; VR stereo; unusual attitudes; caging/clipping; day/night brightness; invalid sensors; MFD power and reversion. |
| Combat/network | Friendly/unknown distinction, passive-only observations, terrain masking, track drop/reacquisition, failed/aborted release, emission on/off, supported missiles, human targets, dedicated server and rejoin. |

## Research that would most reduce uncertainty

1. Obtain the complete Bailey and Greeley/Schwartz cockpit papers ([R06/R07](RESOURCES.md#r06)) through a legitimate library/publisher path. Their abstracts do not define every page or HUD mode.
2. Create a dated visual evidence sheet from the manufacturer HUD footage and the published USAF illustration ([R01–R03](RESOURCES.md#r01)), identifying exactly which symbols/modes each frame supports.
3. Review the complete Gordon lecture ([R125](RESOURCES.md#r125)); the slide deck alone cannot establish verbal qualifications or complete controller behavior.
4. Seek additional publicly released, conditioned flight-test data. Prioritize matching configuration and measurement definitions over collecting more repeated headline figures.
5. Reproduce the community radar/weapon-device observations on the chosen DCS build. The engine integration uncertainty cannot be removed by more aircraft photographs or brochures.

Maintain a per-feature record: claim; source/page/frame; airframe/configuration/date; source access; implementation approximation; confidence; and measured validation result. The project can be substantially more coherent and credible without pretending unavailable production data has become public.
