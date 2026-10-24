# 13 — HUD and symbology evidence

## Applicable resources and claim boundaries

| Reference | What we can study | What it cannot establish |
| --- | --- | --- |
| [R02](../RESOURCES.md#r02), [R03](../RESOURCES.md#r03) | Published F-22 HUD illustration; R03 Figure 3 reproduces the earlier USAF illustration. Basic layout and the discussion of counter-pointer presentation are relevant. | Two independent cockpit captures, every tactical mode, current software-tape behavior or installed angular dimensions. R02 direct access is blocked. |
| [R01](../RESOURCES.md#r01) | Dated manufacturer HUD rig footage. Retain only as corroborating historical material. | An operational flight recording or sufficient sole reference. The user rejected this video as the principal reference. |
| [R06–R09](../RESOURCES.md#r06), [R88](../RESOURCES.md#r88) | Cockpit/display architecture and HUD modernization context. | A full symbol dictionary. Generic projector field-of-view/resolution specifications are not the installed aircraft's optical calibration. |
| [R12](../RESOURCES.md#r12), [R91](../RESOURCES.md#r91), [R99](../RESOURCES.md#r99) | Evaluation methods, dynamics/latency and USAF symbology human factors. | F-22-specific shapes, warning criteria or mode priorities. R91 concerns another aircraft/simulator. |
| [R156–R158](../RESOURCES.md#r156) | Chinese studies of character readability, workload and civil conformal flight guidance. | Raptor symbology. The general-aviation study used a Cessna-based simulator; CAAC material concerns civil HUD use. |
| [R51](../RESOURCES.md#r51), [R125](../RESOURCES.md#r125) | Investigation reconstructions and pilot systems context. | Literal HUD-camera evidence. Reconstructed flight views must not be traced as exact symbols. |

No verified public real-aircraft F-22 flight manual or comprehensive HUD mode/symbol handbook was located in this search. This is a search result, not proof that no further public material exists. Simulator manuals and unverified uploads are excluded from aircraft-authenticity claims.

The later [forum follow-up](../CHINESE_FORUM_RESEARCH.md#hud-and-manual-traps-encountered) screened additional image, video and manual leads. It did not establish a new authenticated tactical-symbol set; [the addendum](RESEARCH_ADDENDUM.md) preserves that evidence boundary.

### Visible cues to preserve from R03 Figure 3

| Observation | Reconstruction boundary |
| --- | --- |
| Left/right circular counter-pointer speed/altitude presentation | Do not substitute inherited vertical tapes. |
| Solid positive and dashed negative pitch marks | Exact angular spacing/declutter needs calibration. |
| Distinct central circular/winged and W-shaped cues; lower curved tick arc | Record shapes separately; cue semantics/mode behavior require corroboration. |

This is an illustration, not a calibrated combiner photograph.

## Code scope and findings

Inspected cockpit registration, indicator directories, HUD mode/brightness command dispatch, view configuration, materials/fonts and HUD-related parameter references.

- **HUD01 — C:** There is **no independent HUD device, page directory or indicator registration** in the current source. The custom indicators are head-down UFD/ICP/MFD/PMFD displays; native HUD behavior comes through inherited avionics. Its source is not present here to audit or rewrite directly.
- **HUD02 — C:** ICP “HUD modes” dispatch inherited NAV/BVR/VS/BORE/FLOOD commands. They are not implemented F-22 master modes. A standalone rewrite needs own mode selection, state and truthful labels, coordinated with sensors/stores/navigation.
- **HUD03 — I:** Before drawing, create a symbol ledger: reference image/date, visible shape/label, measured relative placement, intended data source, validity condition, clipping/declutter rule and confidence. Preserve uncertain cues as assumptions instead of turning interpretation into a purported manual entry.
- **HUD04 — I:** The defensible initial layer is ownship flight guidance: attitude, flight-path direction, airspeed/altitude/heading and available navigation cues. The published image can constrain appearance, but flight-path calculations, units, off-scale behavior and failure handling still need a documented simulation specification. Exact F-22 tactical cue logic remains unverified.
- **HUD05 — I/U:** Build a dedicated angular, collimated indicator with a calibrated eye point, combiner clipping and symbols tied to the outside-world projection. Existing head-down pages correctly use noncollimated rendering; copying their geometry is not a HUD calibration. Actual optical field of view, eyebox and all production cue dimensions remain unresolved.
- **HUD06 — U:** Native targeting/weapon-support feasibility limits the authenticity of tactical cues. A displayed target box or launch indication must correspond to an actual sensor solution and supported weapon state. Do not fabricate APG-77 tracking or a validated launch envelope through drawing alone.

## Future acceptance and remaining research

Later compare a documented reconstruction against the published illustration at matched framing, with assumptions visibly tracked in the development specification. Validate angular scale, horizon/flight-path alignment through pitch/roll/sideslip, wind/reference-frame choice, acceleration lag, heading wrap, speed/altitude validity, power/brightness, occlusion, off-screen cues and both VR eyes. Evaluate readability and workload separately from aircraft fidelity.

Highest-value further evidence would be attributable cockpit-display papers/full figures, official training illustrations and manufacturer optical/interface data. Exact combat-mode symbology, complete HOTAS priority logic, current tape changes and production failure flags remain unsupported. No HUD code or speculative symbol set was added in this pass.
