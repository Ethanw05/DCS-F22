# 10 — Radar, IRST and sensor controls

## Applicable resources

| Reference | Application | Limit |
| --- | --- | --- |
| [R34](../RESOURCES.md#r34), [R101](../RESOURCES.md#r101) | APG-77 identity, AESA architecture and broad functions. | No verified complete detection/track/ECCM or scan-scheduling tables. |
| [R80](../RESOURCES.md#r80), [R107](../RESOURCES.md#r107) | Public IRDS contract and infrared modernization milestones. | A development/delivery milestone does not establish fleet-wide fit or the baseline pod's capabilities. |
| [R148](../RESOURCES.md#r148), [R150](../RESOURCES.md#r150), [R152](../RESOURCES.md#r152) | DCS independent radar/device feasibility and implementation examples. | Community observations and examples; native modern multi-target support is not established. |
| [R165](../RESOURCES.md#r165), [R170–R171](../RESOURCES.md#r170) | Geometry-sensitive signature modeling and timestamp/association methods. | Simplified studies and assumed scenarios, not real F-22 signatures or sensor ranges. |

## Code scope and findings

Reviewed aircraft sensor declarations, IRST sensor/pod registration, PMFD radar controls and indicator composition, native command dispatch and absence of a registered custom radar device.

- **SEN01 — C:** [`F-22A.lua`](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/F-22A.lua#L215) names APG-63, OLS-27, TADS optics and Abstract RWR; ECM names ALQ-135. These are inherited/surrogate host definitions. An APG-77 label on a page would not change the underlying model.
- **SEN02 — C:** Radar power/mode/range are local button/parameter states plus native commands. There is no custom return acquisition, dwell scheduling, track lifecycle, range-rate filtering or radar-to-weapon support code. Keyboard/native mode changes may bypass the local state, so displayed selection need not equal host selection.
- **SEN03 — C/I:** [IRST declaration](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/IRST%20Sensor.lua#L48) assigns ±90° azimuth, −15°/+60° elevation, 90/50 km head/tail detection, scan period 3 and a laser ranger. The consulted primary sources do not validate these settings for the F-22. The pod also has zero declared loadout weight. Mark this as an optional simulation configuration pending evidence and native sensor-behavior checks.
- **SEN04 — C/I:** Scalar aircraft RCS 0.0001 m² is a host gameplay parameter, not a defensible all-aspect, all-frequency F-22 signature model. R165 explicitly simplifies geometry/materials and cannot validate that scalar. Avoid tuning opponent detection to internet headline claims.
- **SEN05 — U:** An independent path using `avSimpleRadar` is plausible for basic search/STT. R148 documents RWS/STT, no native TWS, lost search returns in STT and nonpersistent return-slot identity. This is not proof that native AIM-120 guidance can support simultaneous independent tracks. Preserve this as a required prototype gate before committing to a full standalone combat architecture.
- **SEN06 — I:** Define source-tagged detections and time-managed tracks before drawing a synthetic F-22 radar page. Published asynchronous association methods can inform general design/testing, but their scenario assumptions must not become claimed APG-77/ALR-94 performance.

## Proposed rewrite and future acceptance

Separate DCS-supported target acquisition, an openly approximate track manager, pilot modes, display presentation and native weapon-support integration. Select a documented aircraft era so speculative future sensors do not silently appear on all aircraft. Do not substitute omniscient world-object data for onboard sensing.

Future checks must establish range/aspect/altitude behavior, clutter and terrain occlusion actually supplied by DCS, scan/lock transitions, keyboard/display synchronization, track loss/aging, valid targeting identity, multiple-target support and post-launch support. Start the feasibility check with a clean FC-disabled installation. The absence of own radar code is established; the exact capabilities of a future host implementation remain unresolved.
