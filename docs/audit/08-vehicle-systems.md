# 08 — Electrical, APU, hydraulics, ECS and oxygen

## Applicable resources

| Reference | Application | Limit |
| --- | --- | --- |
| [R09](../RESOURCES.md#r09), [R121](../RESOURCES.md#r121), [R125](../RESOURCES.md#r125) | Integrated vehicle/avionics architecture, fault tolerance and cockpit systems views. | No full wiring, hydraulic or environmental schematic. |
| [R51](../RESOURCES.md#r51) | Public investigation of oxygen/aircraft life-support issues. | An investigation, not a complete current OBOGS/ECS operating manual. |
| [R155](../RESOURCES.md#r155), [R169](../RESOURCES.md#r169) | Integrated vehicle computing and redundant actuator-control concepts. | Architecture/method evidence; no F-22 bus or pressure calibration. |

## Code scope and findings

Reviewed `Engine_System.lua`, `Electrical_System.lua`, hydraulic/oil indication in `MFD_System.lua`, warnings in `Avionics.lua` and EFM power/oxygen/APU outputs.

- **VEH01 — C:** System ownership is fragmented. `Electrical_System` mainly controls lights/refueling indications, while `Engine_System` generates main/battery/APU states and C++ also writes selected power parameters. There is no explicit bus topology, battery energy or shared load/supply model. A lit display is not evidence that its consumers have a coherent electrical state.
- **VEH02 — C:** Lua publishes some power values before deriving that update's new values. Other devices run at different periods. Establish producer/consumer timing and avoid relying on incidental callback order. Commands should request state rather than toggle an independent local copy regardless of requested value.
- **VEH03 — C/R:** [Hydraulic right-side logic](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/Cockpit/Scripts/Systems/MFD_System.lua#L947) increases pressure at RPM ≥45 even with the shared hydraulic fault set; the left increase branch explicitly excludes that fault. In isolated Lua execution with both RPMs 70, fault argument 208 equal to 1 and 900 updates, left pressure was **0**, right **3945**. The branch precedence is confirmed; actual failure injection in DCS remains to test.
- **VEH04 — C:** Hydraulic pressure is maintained inside a display device, changes by fixed increments per update and is not used to constrain EFM surfaces/nozzles. Hot-start parameter initialization also differs from local pressure state subsequently written by update. Move physical supply, leaks, accumulators and actuator demand to a systems owner, then let displays observe it.
- **VEH05 — C/I:** Oil indication is an RPM multiplier, not an oil-system state. EGT comes from a separate engine proxy. Warning thresholds and stale gaps need a documented display policy; do not infer actual F119 operating pressures/temperatures from these constants.
- **VEH06 — C:** APU RPM/readiness is a Lua timer/animation while EFM APU exports are zero. Automatic shutdown time can accumulate before interruptions because the timer is not reset for every loss of its qualifying condition. Define whether the intended delay is continuous or cumulative and share one APU state with engine-start and power consumers.
- **VEH07 — C:** [Clam-door animation](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/Cockpit/Scripts/Systems/Engine_System.lua#L619) writes arguments 610/611; C++ writes the same external arguments. Competing writers can disagree with rate/order. Choose physical state once and render it through one path.
- **VEH08 — C/I:** Oxygen supply and ventilation exports are constants (101000 and 10); warnings are simple indication conditions. No detailed oxygen generation, breathing demand, cabin pressure or ECS thermal model exists here. R51 can inform fault scenarios but cannot supply missing physiological or pneumatic equations.

## Proposed rewrite and future acceptance

Define an openly simplified vehicle model with explicit sources, consumers, units, failure states and start-state initialization. Couple hydraulic/electrical availability to actuators and equipment without inventing unsupported production wiring. Keep hazardous physiological claims out of fidelity assertions.

Later validate cold/hot/air starts, APU interruptions, one-generator operation, battery depletion, loss/restoration, symmetric hydraulic fault response, actuator starvation and agreement among EFM, animations, warnings and synoptics. The isolated checks do not emulate DCS scheduling or the real aircraft.
