# 07 — Landing gear, brakes and ground handling

## Applicable resources

| Reference | Application | Limit |
| --- | --- | --- |
| [R20](../RESOURCES.md#r20), [R125](../RESOURCES.md#r125) | Landing/refueling control modes and configuration handling. | Development-era control information and pilot presentation; not a complete landing-gear manual. |
| [R131](../RESOURCES.md#r131) | Demonstration takeoff/landing conditions and operating constraints. | Demonstration-specific guidance, not the aircraft's complete operating envelope. |
| Bundled EFM API and `FM/config.lua` | Suspension, steering, brake and gear-position interface contracts. | Host integration evidence; not a source of real F-22 limits. |

## Code scope and findings

Reviewed gear commands/position, suspension configuration, steering schedule, braking, parking, weight-on-wheels consumers and gear indications.

- **GND01 — C:** [Ground state](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/EFM/source/RAPTOR.cpp#L959) means gear position above 0.5, height below 50 m and Mach below 0.3. This includes an airborne approach and omits real wheel contact. It switches engine behavior and steering eligibility. Use actual suspension/contact state where supported; keep landing-mode configuration separate from ground contact.
- **GND02 — C:** Ground speed subtracts wind from world velocity. That is air-relative horizontal speed, so steering limits can change with wind while the aircraft has the same runway motion. Derive runway-relative speed from ground velocity and test crosswind/headwind cases.
- **GND03 — C/R:** [Lua brake processing](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/Cockpit/Scripts/Systems/Engine_System.lua#L498) thresholds either pedal axis into one common brake command. An isolated left-axis input produced command 74. EFM then returns the same `wheel_brake` to all three suspension brake channels. Independent and proportional left/right braking is therefore absent from this code path; validate which wheels should brake before rewriting the exports.
- **GND04 — C:** Anti-skid is always enabled. There is no shared brake pressure, independent wheel-slip state or failure model. Do not claim a faithfully modeled F-22 anti-skid controller from that flag alone; determine what anti-skid DCS already supplies for the EFM.
- **GND05 — C:** [Steering](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/EFM/source/RAPTOR.cpp#L1501) holds a 25° limit through 60 knots then drops directly to zero above 60. No steering-system state or documented real schedule supports that discontinuity. Separate authority, engagement and speed-dependent limits.
- **GND06 — C:** Gear-toggle lowering is gated by an airspeed minimum whereas the explicit gear-down command uses a different condition. Keyboard, joystick and clickable inputs should request the same state and pass the same actuator/permission logic. Existing 100/275-knot constants are not established real-aircraft limitations by this review.
- **GND07 — C/R:** All posts share a single gear position; physical extension advances per callback rather than elapsed time (see [04](04-thrust-vectoring.md)). Separate render smoothing from actuator dynamics. Individual jams/failures cannot be represented with a single position.
- **GND08 — C:** Main-panel gear lights reuse the nose-gear parameter for the three indicators, although left/right parameter handles exist. The common gear state currently masks much of this wiring problem. Gear-dependent weapon authorization and warning logic also need an explicit transit/unsafe state instead of retaining previous values.

## Proposed rewrite and future acceptance

Use separate ground-contact, configuration-mode and landing-gear states; independent gear actuators; proportional brake channels; and an explicit parking/anti-skid interface. Publish one truthful state to animations, warnings, controls and the DCS suspension interface.

Future checks: same motion under different wind, air approach below 50 m, runway contact/bounce, one-side braking, parking release, steering across speed boundaries, gear commands from each binding, power/hydraulic loss, individual gear faults and timestep variation. No reliable public source located here supplies the complete production steering/brake/gear hydraulic schedule; document approximations.
