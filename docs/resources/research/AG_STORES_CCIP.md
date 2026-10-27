# Bottom stores programming and CCIP request timing

**Historical UI/timing checkpoint, superseded 25 October 2026.** The old PROG/PREV/NEXT/direct-mode key assignments below are retained as history. Current stores use the original bay picture with contextual MODE/PROG/DOORS/FUZE controls; see the [UI handoff](OVERHAUL_UI_HANDOFF.md), [stores backend handoff](OVERHAUL_STORES_HANDOFF.md) and [implementation ledger](OVERHAUL_IMPLEMENTATION_LEDGER.md) for exact contracts and remaining native/flight validation. This older timing fix is not evidence of final CCIP accuracy.

The lower-center bay display remains the base. Its original bay/door diagram and status are retained. A/G PROG (right bezel button 10) opens its program subpage; BAYS returns. The separate legacy left stores page is unchanged.

## Controls

With A/G selected, use PREV/NEXT to select an actual loaded bomb type and GUN/CCIP/AUTO for delivery. Each bomb type retains its own mode, quantity and interval for the mission. Guided stores require AUTO for release.

Select QTY or INTVL on the bottom display, type with the existing ICP keypad, then press ICP OP5/STORE to commit. CLR removes one digit; UNDO cancels. The entry appears on the bottom stores page. Quantity is 1 through the lesser of eight and the available selected-store count; interval is 50–2000 milliseconds. These are mod control limits, not recovered F-22 specifications. Invalid/empty/overflow entries retain the old program. Navigation entry retains its own routing when no stores entry is active; changing context cancels the stores transaction. Programming is available with master arm SAFE.

A release hold captures the selected type's quantity, interval and AUTO target sequence. Each release still requires power, airborne state, master arm, the selected bay, a current solution and applicable guidance support. Editing a program cancels pending consent. Ending a hold cancels the remainder; holding after program completion cannot launch a second program. Timing uses the existing 20 ms controller, so a requested interval may be rounded later to the next activity tick.

Fuze remains STORE DEFAULT. The current adapter exposes no qualified fuze-programming operation; the display explicitly says programming is unavailable. No cosmetic fuze selector or claimed arming/delay was added.

The radar's GUN/CCIP/AUTO controls were removed. Radar designation and clearing retain their own owner. The terrain page is identified as terrain returns with GMT/GMTT unavailable.

## CCIP correction and evidence limits

The previous Lua update consumed the preceding bomb result and only then submitted the next request, retaining an extra 50 ms of release-state latency. The EFM's 10851 command invokes NativeAGWeapons synchronously. Lua now requests first and consumes that exact response sequence in the same activity. Changed store identity resets terrain state. Up to three immediate requests reconcile the impact plane with actual terrain; an unresolved result is suppressed. Selection changes invalidate the old solution before another store can use it. Release-attempt diagnostics now record the predicted point and solution age.

This corrects a demonstrated frontend timing problem. It does not establish the miss distance from the user's maneuvering flights or calibrate native bomb ballistics, ejection effects, wind variation or bay-motion prediction. The recent dcs.log and dcs.log.old files reviewed did not contain paired prediction/impact observations. Earlier controlled-test evidence does not qualify every release condition. Live flight acceptance remains required.

## Ground radar remains incomplete

The current native adapter transports at most 256 unassociated clutter records with position, time and return strength; its decoder explicitly excludes associated object IDs. There is no qualified image raster or ground-vehicle motion channel. Changing symbols, filling gaps or enlarging the point cloud cannot establish a useful MAP/GMT capability. The cosmetic intensity/view experiments were not integrated.

A replacement needs an image-producing terrain/scene sensor, occlusion and material response, scan integration and stabilized detail patches, plus a separately qualified moving-target observation/tracking path. The DCS Hornet's MAP/EXP and GMT/GMTT separation is the workflow reference (Eagle Dynamics guide, pp. 186–198). The [Community A-4E-C radar source](https://github.com/Community-A-4E/community-a4e-c/blob/2b0768e9ad50a2d1381aa65ba50d31be3691c0fd/A-4E-C/ExternalFM/FM/Radar.cpp) is a primary example of independent terrain intersections, surface normals and reflectivity integration. It was inspected as a reference; no A-4 implementation was incorporated. This is a backend replacement task, not a completed radar fix in this change.

## Verification

`test_ag_usability.py` covers actual inventory/type selection, profile memory, quantity and interval release commands, edit cancellation, master-SAFE programming, same-tick ballistic responses, mismatched sequence rejection, terrain reconciliation, the actual bottom bay/program format and native-safe text, physical bezel routing and ICP digit/CLR/STORE/UNDO/navigation handoff. Existing A/G delivery, radar and navigation checks remain part of the suite.

The combined isolated snapshot passed 57/57 checks before the final scoped keypad/format refinements; those refinements passed their targeted regression. Final shared-source verification is recorded in the local usability report. Actual Lua and the shipped font were rendered and visually inspected; these previews are synthetic fixtures. The installed mod and active DCS session were left unchanged. Native acceptance is pending for program execution, physical keypad/mode transitions, bay display layering and CCIP drops over varied terrain while maneuvering.
