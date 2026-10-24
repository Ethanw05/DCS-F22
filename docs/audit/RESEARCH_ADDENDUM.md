# Research addendum — Chinese forum and citation trails

Date: **24 October 2026**, after the initial 16-system review. This records evidence updates only. The audited implementation remains unchanged from baseline `9c5d03ee822323591dbf259d09b5022ced3e3d4f`; the main review was committed as `ed7ac4917306dda6fbe56eda2f0d298a4bbc0bca`.

Search provenance, access failures and 22 community leads are in [CHINESE_FORUM_RESEARCH.md](../CHINESE_FORUM_RESEARCH.md). Four new numbered source records are [R173–R176](../RESOURCES.md#r173); [R65](../RESOURCES.md#r65) has improved text access. These are not four new aircraft manuals.

## System evidence updates

| System | Applicable material | Audit implication and limit |
| --- | --- | --- |
| [02 Aerodynamics/performance](02-aerodynamics.md) | R65; R174; R173 pending original presentation review | Broaden validation scenarios; pilot accounts cannot identify a full coefficient or engine map. Preserve mass, atmosphere, stores, configuration and aircraft era before any fit. |
| [03 Flight controls](03-flight-controls.md) | R65; R174 | Original prototype text links TVC to pitch authority and control allocation; Brown describes automatic TVC involvement. Revisit coupled pitch/roll behavior, with prototype and production evidence kept separate. |
| [04 Thrust vectoring](04-thrust-vectoring.md) | R65 | Historical actuator/control scheduling evidence is stronger than the previous title-only access. Use it to examine TVC02–TVC04, not to replace production schedules without validation. |
| [05 Engines](05-engines.md) | R174; R173 pending | Pilot testimony suggests useful transient/handling cases, but does not justify altering thrust/fuel tables directly. Retain ENG01/ENG02 API-contract findings independently. |
| [08 Vehicle systems](08-vehicle-systems.md) | R174 | Bleed-air recollection provides a fault-scenario lead, not a verified failure tree or current checklist. Do not invent automatic shutdown/cross-bleed behavior from an anecdote. |
| [09 Mission avionics](09-avionics.md) | R175–R176 | Define ownership, validity and permitted transitions explicitly. General methods support later validation of power/warning/page consistency; they do not authenticate F-22 fusion logic. |
| [10 Radar/IRST](10-radar-irst.md), [11 EW](11-ew-datalink.md) | Community claims and generic nozzle-study bibliography | No new verified APG-77/ALR-94 range, actual signature or IRST fit was established. Keep SEN03–SEN06 and EW interface questions unresolved. |
| [13 HUD](13-hud.md), [14 displays](14-displays.md) | Forum image/video/manual screening | No new authenticated Raptor tactical-symbol set found. Aircraft named as the target is not necessarily the HUD's host aircraft; rendered/simulator pages remain simulation comparisons. |
| [01 integration](01-integration.md), [06 fuel](06-fuel.md), [07 ground](07-ground-handling.md), [12 weapons](12-weapons.md), [15 navigation](15-navigation.md), [16 lifecycle](16-lifecycle-release.md) | No new verified implementation-specific aircraft evidence in this pass | Existing code findings stand. Reposts do not resolve DCS interface contracts or establish an independent native guided-weapon/radio path. |

## What changes in future validation

R65's aircraft is the YF-22, including different prototype engines/configurations. Numeric labels in OCR and reused figures need clean originals. Its normal command arrangement does not establish deliberately differential production nozzle commands or direct yaw-vector authority.

For the mod, this strengthens the need to distinguish **requested aircraft response, control allocation, per-engine nozzle state, delivered forces and displayed animation**. Those are different quantities. A single Mach cutoff, a visually moving nozzle or a throttle-scaled vertical force should not be treated as a verified aircraft law.

R175/R176 support analyzing the existing shared-state problems as interface/state-model issues. Any later implementation should define explicit requests, availability, measured state and presentation. This remains a design direction; no formal verification or new audit tooling is included.

The major standalone feasibility gate is unchanged: demonstrate independent native target acquisition and guided-weapon support in DCS with inherited FC avionics disabled. Forum performance claims cannot resolve that host interface.

## Claims deliberately left open

- Brown's 2022 presentation acceleration intervals: original video/slide review, conditions and numeric transcription still pending.
- Complete HUD mode/declutter/tactical cue semantics and installed optical calibration.
- Exact original records/full texts for the nozzle studies cited by community articles; no measured F119 signature data obtained.
- Exact production F-22 gains, nozzle schedules, engine deck and full-envelope aerodynamic coefficients.

No new finding is labelled reproduced merely because a forum agrees with it. No source-based code finding from the original review was fixed or withdrawn in this research-only pass.
