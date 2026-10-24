# 14 — Head-down displays, ICP, fonts and lighting

## Applicable resources

| Reference | Application | Limit |
| --- | --- | --- |
| [R06–R09](../RESOURCES.md#r06), [R125](../RESOURCES.md#r125) | Physical display roles, integrated presentation and published synoptic examples. | No complete current page/state specification. Some papers are abstract-only. |
| [R12](../RESOURCES.md#r12), [R99](../RESOURCES.md#r99), [R156–R158](../RESOURCES.md#r156) | Readability, workload, presentation consistency and evaluation. | General engineering guidance does not prove authentic F-22 colors, fonts or labels. |

## Code scope and findings

Reviewed all indicator initialization/definitions, 38 display page scripts, `fonts.lua`, `materials.lua`, main panel, clickable/display controls and their data producers. All 38 page scripts constructed in isolated Lua 5.1 with minimal common-host drawing substitutes; no parameter-controller index overflow or repeated insertion of the same object was detected by those specific checks. This does not validate DCS renderer behavior.

- **DSP01 — C/I:** Many pages repeat clipping, mesh, text, color and controller setup. Centralize later around shared components and small page specifications, retaining page-specific geometry. Repeated element names merit maintainability cleanup, but name repetition alone was not shown to cause a host failure.
- **DSP02 — C:** Page state is distributed across display systems and `Avionics.lua`, including power/page flags. Define one selected-page state per physical display and a separate availability predicate. Update all flags from that state to prevent stale overlap during page/power transitions.
- **DSP03 — C/R:** Night-mode opacity can be negative (see [09](09-avionics.md)); battery/main-power writers can disagree on ICP visibility. Use a bounded common brightness model, with independent warning priorities and daylight/night adaptation. Do not clear physical alerts when a display is dimmed.
- **DSP04 — C:** ICP digit, clear and undo controls are declared/listened for, but the active handler contains no corresponding data-entry implementation. COM2 opens the rearm menu and STPT opens the kneeboard. They are convenience mappings, not implemented radio/waypoint pages. Document them now and replace them coherently with navigation/CNI work later.
- **DSP05 — C/I:** FCS and engine synoptics use animation or RPM-derived proxies for physical quantities. Display actual achieved actuator/system state with units and validity; do not show a vector-angle label for an RPM-derived nozzle proxy. Fuel quantities need the conservative ledger described in [06](06-fuel.md).
- **DSP06 — C:** Main-panel left/right gear lights are wired to `N_GEAR_LIGHT`. Independent left/right state must reach their own indicators. This is currently obscured by shared gear position, not evidence that the wiring is correct.
- **DSP07 — C/I:** PMFD MAP/SYS/SFM structures and static page labels are not proof of a functional moving map, mission management or independent sensor fusion. Make unavailable selections explicit when later defining the product scope. Keep decorative animations outside physical state ownership.
- **DSP08 — U:** Font atlas coverage, aspect ratio, clipping depth, masks over inherited displays, brightness range, monitor export and VR readability require in-DCS visual validation. Syntax/construction checks cannot establish line width, flicker, transparency or stereo correctness. No fabricated screenshots were used as aircraft references.

## Proposed rewrite and future acceptance

Use a component library, a single page router per display and a documented view model containing units, validity and source. Reconstruct only evidenced page details; visibly document assumptions in the development specification. Separate physical measurements from presentation-only effects.

Later validate every page/softkey from cold/hot/air starts, power interruption during selections, min/max numeric widths, missing/invalid sensors, cross-display consistency, all lighting positions, clipping/exports and VR. Verify text and colors against attributable material where available, and human-factors criteria where exact aircraft evidence is absent. No page implementation changed during this audit.
