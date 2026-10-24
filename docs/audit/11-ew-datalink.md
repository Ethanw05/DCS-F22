# 11 — EW, countermeasures and datalink

## Applicable resources

| Reference | Application | Limit |
| --- | --- | --- |
| [R36](../RESOURCES.md#r36) | Manufacturer description of ALR-94 passive sensing/geolocation and integrated functions. | Does not reveal detection sensitivity, emitter library or real geolocation algorithms. |
| [R104](../RESOURCES.md#r104), [R108](../RESOURCES.md#r108), [R115](../RESOURCES.md#r115) | CNI, IFDL and demonstrated gateway integration. | Gateway demonstrations do not imply unrestricted direct interchange with every DCS datalink. |
| [R39–R42](../RESOURCES.md#r39) | Public modernization scope and test reporting. | Dates/configurations differ; not all described capability is a baseline fleet feature. |
| [R170–R171](../RESOURCES.md#r170) | Generic ESM/radar timestamp association and cooperative-sensing models. | Not ALR-94 performance, not classified operational techniques, not DCS API documentation. |

## Code scope and findings

Reviewed aircraft countermeasure/sensor declarations, weapon-system jammer state, ICP threat-volume dispatch, right MFD RWR page/controller and aircraft `EPLRS` flag.

- **EW01 — C:** No custom RWR/ESM device or emitter/track model is registered. The aircraft declares `Abstract RWR` and `AN/ALQ-135`. The right display masks/exposes inherited symbology and dispatches native display controls; it is not a modeled ALR-94 receiver.
- **EW02 — C/I:** Local jammer state follows toggled commands without a single authoritative link to equipment availability, native jammer status, thermal/power limits or faults. Establish command request, measured/native response and displayed state separately. Do not invent ALR-94 active-effectiveness numbers from passive-sensing publicity.
- **EW03 — C/I:** The aircraft declares chaff/flare inventories of 120 each, charge increments and dispenser geometry. There is no independent sequencer/programmer, inventory reconciliation or per-dispenser fault logic in the active Lua. These counts are configuration data, not evidence of actual expendables fit or program timing.
- **EW04 — C:** `EPLRS = true` is a DCS interoperability choice (the source comment explicitly mentions the A-10C TAD). It does not implement IFDL, message provenance, link topology, latency, gateway restrictions or identification fusion. A universal shared tactical picture would misrepresent the documented aircraft/network distinctions.
- **EW05 — I:** Passive emitter detections should carry bearing uncertainty, time, source and identity confidence. Datalink reports should remain distinguishable from onboard tracks. R170's asynchronous association method is useful for test design; it supplies neither ALR-94 angular accuracy nor a real F-22 fusion implementation.
- **EW06 — U:** Native countermeasure launch, jammer control, RWR indications and communications compatibility must be tested under an independent device stack. R149 lists interfaces, including explicitly unverified ones. Preserving existing cockpit buttons does not prove those effects survive removal of inherited avionics.

## Proposed rewrite and future acceptance

Implement only publicly supportable abstractions: host-provided warning contacts, explicit emitter/track confidence, a bounded countermeasure sequencer, coherent inventory and clearly identified network reports. Document interoperability choices as simulation policy where DCS cannot represent the real link boundary.

Future checks should cover independent countermeasure inventory/launch, master/standby controls, power loss/restoration, emitter disappearance, stale network reports, conflicting identification, multiplayer clients and gateway availability. Exact receiver coverage, operational techniques and real countermeasure effectiveness remain unverified; do not make source-free realism claims. No EW effectiveness or network code was changed during this pass.
