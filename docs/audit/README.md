# System-by-system research and code audit

Date: **24 October 2026**. Code baseline: [`9c5d03ee822323591dbf259d09b5022ced3e3d4f`](https://github.com/Ethanw05/DCS-F22/tree/9c5d03ee822323591dbf259d09b5022ced3e3d4f). **Research and documentation only: implementation is deliberately deferred until every system has been reviewed.**

This second pass expands the [first assessment](../OVERHAUL_ASSESSMENT.md). It inventories **132 tracked source/configuration files, 46,267 lines**, including **117 Lua/SDEF files**. Core logic was traced across producers, commands, callbacks and consumers. Repeated display pages were inspected through their data/controller structure and comparison, including isolated construction of all 38 page scripts. [Coverage](COVERAGE.md) lists every file and the nature of its review; no claim is made to have exercised every possible branch in DCS.

## Reading order

| Order | System | Review record |
| --- | --- | --- |
| 01 | Module boundary, API, build and input routing | [01-integration.md](01-integration.md) |
| 02 | Aerodynamics, air data and performance | [02-aerodynamics.md](02-aerodynamics.md) |
| 03 | Flight controls and control allocation | [03-flight-controls.md](03-flight-controls.md) |
| 04 | Thrust vectoring and physical actuators | [04-thrust-vectoring.md](04-thrust-vectoring.md) |
| 05 | Engines and FADEC approximation | [05-engines.md](05-engines.md) |
| 06 | Fuel, mass, tanks and refueling | [06-fuel.md](06-fuel.md) |
| 07 | Landing gear, brakes and ground handling | [07-ground-handling.md](07-ground-handling.md) |
| 08 | Electrical, APU, hydraulics, ECS and oxygen | [08-vehicle-systems.md](08-vehicle-systems.md) |
| 09 | Mission avionics, air-data presentation and state ownership | [09-avionics.md](09-avionics.md) |
| 10 | Radar, IRST and sensor controls | [10-radar-irst.md](10-radar-irst.md) |
| 11 | EW, countermeasures and datalink | [11-ew-datalink.md](11-ew-datalink.md) |
| 12 | Stores, weapon bays, gun and ordnance definitions | [12-weapons.md](12-weapons.md) |
| 13 | HUD and symbology evidence | [13-hud.md](13-hud.md) |
| 14 | Head-down displays, ICP, fonts and lighting | [14-displays.md](14-displays.md) |
| 15 | Navigation, autopilot and communications | [15-navigation.md](15-navigation.md) |
| 16 | Damage, lifecycle, effects, assets and distribution | [16-lifecycle-release.md](16-lifecycle-release.md) |

Each record gives applicable resources, code scope, findings, proposed changes, unknowns and future acceptance checks. Finding IDs are local to each record. Earlier F01–F23 remain valid historical identifiers; this pass does not silently renumber them. The [Chinese-language search report](../CHINESE_RESEARCH.md) distinguishes actual aircraft evidence, third-party modeling and general engineering methods.

There are **113 finding records** across these reviews, including overlapping system concerns, confirmed defects, fidelity gaps and unresolved interface questions. This is not a claim of 113 distinct reproduced bugs.

The subsequent [Chinese forum follow-up](../CHINESE_FORUM_RESEARCH.md) and [research addendum](RESEARCH_ADDENDUM.md) update source access and applicable system evidence without changing the audited implementation or treating forum agreement as a reproduced defect.

## Findings that affect the overhaul plan

- Flight physics: high-alpha force discontinuity, thrust-vector direction/magnitude inconsistency, inert roll/yaw trim and timestep-dependent actuator motion.
- Vehicle state: nonconservative fuel callbacks, inconsistent engine RPM/combustion exports, collapsed left/right brakes and asymmetric hydraulic-fault indications.
- Cockpit/release logic: negative night opacity, competing state writers, a gun-fire dispatch that survives power loss/release, and bay/release sequencing gaps.
- Lifecycle: repair fails to restore derived health, a destruction-event guard persists across resets and pending mass changes survive reset.
- Independence: own EFM exists, but own HUD, radar/ESM, navigation, radio and native stores integration are incomplete or absent. Independent radar-to-guided-weapon support must be demonstrated before promising feature parity with inherited avionics.

These findings justify substantial refactoring and selected rewrites. They do not justify copying unvalidated F-22-like CFD coefficients, speculative weapon performance or generic Chinese HUD symbols into a purportedly exact aircraft model. Each system record states what evidence would support its next stage.

## Evidence labels

- **C — code-confirmed:** directly visible in the active implementation or data declarations.
- **R — reproduced:** behavior observed in isolated execution of unchanged source or its extracted callbacks, with stated host substitutes.
- **I — improvement/fidelity gap:** a design recommendation or unsupported approximation, rather than a demonstrated software failure.
- **U — unresolved:** depends on DCS runtime behavior, unavailable data, provenance or interface semantics.

The review used an independently built **Lua 5.1.5** parser: all 117 Lua/SDEF files passed syntax checking after removal of a leading UTF-8 BOM only. Syntax success does not establish correct DCS API usage. The 38 display-page construction checks used minimal substitutes for common DCS drawing helpers and checked parameter-index bounds and repeated insertion of the same object; they do not validate rendering, collimation or VR.

The numerical experiments use extracted C++ baseline functions with a no-op cockpit bridge, or Lua baseline systems with explicit synthetic sensor/parameter inputs. Results and conditions are recorded in the individual reviews. They are not in-simulator flight tests. Temporary analysis programs were kept outside the repo, following the request not to add audit tooling.

## Review conclusion

All 16 system scopes now have a written review. The highest-confidence problems are conservation/reset errors, discontinuous or time-step-dependent model behavior, unused controls, mismatched state/animation ownership, release-state handling, and inconsistent display values. The largest unresolved overhaul dependency is independent radar-to-native-weapon support, especially concurrent engagements. The public references support a better documented simulation, but do not supply a complete verified production F-22 aerodynamic database, F119 deck, software tape or HUD mode manual.

The review pass is complete as a **source-based assessment**. The listed runtime questions remain explicit implementation/validation gates. No fixes, system rewrites, new avionics or aircraft-performance changes are included in this pass.

## Implementation follow-up

The audit above remains a historical review. The flight-model replacement is in [FLIGHT_MODEL.md](../FLIGHT_MODEL.md). The subsequent seven-device/HUD overhaul, per-system evidence, checks and unresolved limitations are in [OVERNIGHT_OVERHAUL.md](../OVERNIGHT_OVERHAUL.md). Use [TEST_BUILD.md](../TEST_BUILD.md) for the experimental overlay; old line links do not describe the replacement implementation.
