# 04 — Thrust vectoring and actuators

## Applicable resources

| Reference | Application | Limit |
| --- | --- | --- |
| [R25](../RESOURCES.md#r25), [R81](../RESOURCES.md#r81), [R129](../RESOURCES.md#r129) | F119 pitch vectoring, integrated engine/flight controls and nozzle/inlet integration. | No complete installed-engine or nozzle-loss deck. |
| [R126, Fig. 9-12](../RESOURCES.md#r126) | Historical nozzle travel/rate and surface bounds. | No-load, historical data; not a full production scheduling law. |
| [R65](../RESOURCES.md#r65), [R174](../RESOURCES.md#r174) | Original-paper text and later first-person handling testimony; access updated in the [addendum](RESEARCH_ADDENDUM.md). | Preserve prototype/production distinctions; no complete production schedule. |
| [R159–R161](../RESOURCES.md#r159), [R168–R169](../RESOURCES.md#r168) | Allocation, failed-effector handling and distinction between throat area and vector control. | Chinese studies supply methods, not F119 calibration; fluidic-nozzle research is not a substitute for the F119 mechanical nozzle. |

## Code scope and findings

Reviewed `tv_sensitivity`, Mach schedules, nozzle slew limits, force application, animation mapping, `Utility.h` and MFD nozzle indication.

- **TVC01 — C/R:** [Force application](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/EFM/source/RAPTOR.cpp#L655) rotates forward thrust with `cos(theta)` but multiplies vertical thrust by throttle output again. At a 20° nozzle command the expressions produce a 13.7047° resultant at output 0.67 and 21.8195° at 1.1, with magnitudes 0.96723T and 1.01221T respectively. This is not a pure rotation of the computed net thrust. Model losses separately if intended.
- **TVC02 — C/I:** A single `tv_angle` drives both engines. Independent engine forces exist, but nozzle state/health does not. Represent each physical actuator independently, even if the first normal allocator commands equal angles.
- **TVC03 — C/I:** [Schedules](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/EFM/source/RAPTOR.h#L69) reduce TV command sensitivity with Mach and also reduce allowed travel/rate. At high Mach rates become zero. A nozzle at nonzero angle can remain there when rate is zero while animation later shows zero because permitted deflection is zero. Check transition history, return-to-neutral authority and physical schedules separately.
- **TVC04 — C / reference mismatch:** The low-Mach nozzle rate begins near 80°/s; R126's historical figure labels nozzle rate 40°/s no-load. Investigate and document the selected bound; neither the mismatch nor a manufacturer ±20° travel statement reveals the complete production rate schedule.
- **TVC05 — C:** [Animation](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/EFM/source/RAPTOR.cpp#L1282) scales angle by the current Mach-dependent maximum and 1.25. This changes visual meaning with Mach. Map actual degrees to fixed EDM calibration, with separate area and pitch-vector arguments.
- **TVC06 — C:** [`L_NOZZLE_POS`/`R_NOZZLE_POS`](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/Cockpit/Scripts/Systems/MFD_System.lua#L801) are derived from RPM. They are not measured vector angle or nozzle area. Select the intended quantity and publish it from engine/actuator state.
- **TVC07 — C/R:** Gear/slat/flap/airbrake helpers use per-call increments. The gear travel took 667 calls: 2.001/4.002/8.004 seconds at dt 0.003/0.006/0.012. Physical actuator rates must use elapsed simulation time; separately smoothed render positions cannot be the authoritative actuator state.

## Proposed rewrite and future acceptance

Resolve pitch-plane net thrust consistently at each engine location and compute moments about current CG. Two pitch-vectoring nozzles do not imply direct nozzle yaw-vector capability. Surface and thrust contributions should meet one commanded moment/response request within actual effector limits.

Validate thrust-vector magnitude/direction, command signs, independent engine/nozzle failures, Mach transitions with a deflected nozzle, gear/airborne transitions, rate limits across timesteps and agreement among forces, animations and synoptics. R169 is particularly useful for keeping throat-area control, exit area and vector angle conceptually separate, but its numerical values do not transfer to F119.
