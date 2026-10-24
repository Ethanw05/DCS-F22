# 09 — Mission avionics and shared state

## Applicable resources

| Reference | Application | Limit |
| --- | --- | --- |
| [R06–R09](../RESOURCES.md#r06), [R104](../RESOURCES.md#r104), [R121](../RESOURCES.md#r121) | Display roles, integrated processing, CNI and fault-tolerant architecture. | Several cockpit papers are abstract-only; no production software interfaces or complete symbol dictionary. |
| [R154–R155](../RESOURCES.md#r154) | Chinese-language analysis of core processing and integrated flight/vehicle computing. | Secondary aircraft architecture analysis, not recovered F-22 source code. |
| [R170–R171](../RESOURCES.md#r170) | Timestamping, track association and modular multisensor test concepts. | Research methods; neither contains APG-77/ALR-94 implementation data. |

## Code scope and findings

Reviewed `Avionics.lua`, parameter producers/consumers in the other six active Lua systems, indicator controllers and the C++ cockpit bridge. No own mission-computer, sensor-fusion or persistent track-store implementation exists in the inspected tree.

- **AV01 — C/I:** Current mission functions primarily dispatch inherited DCS commands and display host data. An integrated F-22 simulation requires a shared model for aircraft state, navigation, sensors, stores, equipment availability and selected modes. A new screen alone does not create those functions.
- **AV02 — C:** Main/battery power, page enablement and opacity have multiple writers across C++ and Lua. In particular, `Avionics` can clear ICP opacity on battery loss while `ICP_System` writes it from main power. Establish one owner per state and publish explicit equipment-availability/readout values. Different update periods make order-dependent behavior a runtime concern.
- **AV03 — C/R:** [Night dimming](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/Cockpit/Scripts/Systems/Avionics.lua#L301) subtracts 0.9 from the knob. An isolated update with knob 0.5, night selected and main/battery power available sets UFD/MFD opacity to **−0.4**. Define a bounded brightness transfer function and keep the underlying operational state independent of opacity.
- **AV04 — C:** Turning the UFD knob to zero [clears warning parameters](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/Cockpit/Scripts/Systems/Avionics.lua#L398). Dimming must hide an indication without erasing the fault/alert state consumed elsewhere. Split fault detection, alert management, acknowledgment and rendering.
- **AV05 — C:** Fuel display derives quantities from fixed full-internal constants and sometimes uses previously computed totals. See [06](06-fuel.md). Shared air data also mixes meters, feet, knots and normalized animation values. Publish named quantities with units and validity rather than requiring each screen to reconstruct them.
- **AV06 — C/U:** Heading conversion, barometric altitude, radio altitude and g indication depend on the exact semantics of `get_base_data()` and EFM exports. Verify wrap, reference frames and whether acceleration already includes gravity before changing formulas. The EFM's estimated equivalent airspeed is not a calibrated pitot/static air-data computer.
- **AV07 — C/I:** FCS/engine/fuel synoptics often read model arguments or derive quantities from RPM rather than read a physical system. Animation should be a consumer of state, not the avionics measurement source. Retain special decorative PMFD animation as presentation only; its acceleration-driven tail animation is not an active flight controller.

## Proposed rewrite and future acceptance

Define a small independent mission-avionics architecture with explicit producer ownership, timestamps, validity, source identity and mode transitions. Keep sensor truth separate from displayed/estimated tracks, and keep pilot selection separate from measured equipment state. Chinese processing papers help structure the design but do not justify copying unknown production algorithms.

Later verify power changes at every update phase, day/night/zero brightness, alert persistence, unit conversions, heading wrap, invalid sensor data, page-switching consistency, fresh mission initialization and independent avionics operation with inherited FC systems disabled. The seven-device smoke checks load/update selected paths under synthetic host inputs; they do not establish DCS scheduling or fusion fidelity.
