# NAV automatic sequencing and landing HUD — 26 October 2026

## Source findings

1. `Nav_Computer.lua` cleared `automatic` in NEXT/PREV, ID selection and edit operations. `Navigation_System.lua` also cleared it on WPDSG. A selected AUTO preference was therefore lost as part of normal browsing/designation. AUTO now persists; an active target designation suspends sequencing until cleared. The capture radius and passed-waypoint corridor are unchanged, and sequencing still stops at the final point.
2. Navigation sequencing took ground speed exclusively from the HUD producer. It now reads valid horizontal EFM velocity directly, with the existing HUD ground-speed input as fallback. An unavailable or hidden HUD does not disable otherwise valid navigation sequencing.
3. `Nav_Guidance.lua` published ILS HUD validity only when the mutually exclusive steering source was ILS. Selecting TCN cleared it. Receiver validity and approach display are now independent of waypoint/TACAN steering and of IRS position availability.
4. The HUD bars also explicitly required `HUD_MODE == 1` (NAV). This mod does not have a separate landing master mode; that NAV-only check hid bars when landing with A/G or another mode retained. A separate approach-enable flag now permits explicit ILS acquisition in NAV and received approach guidance with gear fully down. Gear-up combat without explicit NAV/ILS acquisition remains uncluttered.

The user's preceding flight log was preserved. It recorded route loading but lacked the sequencing and approach state needed to attribute every reported missed passage. The new `F22_NAV_STATE` log records the actual sequence/capture state, receiver status and raw deviations, gear and HUD-enable flags. No cockpit screenshots are used as proof of reception or sequencing.

## Correct distinction between TACAN and landing beams

The Hornet presents TACAN bearing/range and course steering; its precision approach bars come from ICLS. An F-22 runway approach uses this mod's existing independent ILS receiver. TACAN channel selection cannot supply a localizer/glideslope or select an ILS frequency. The fix preserves both inputs together rather than fabricating precision guidance from a TACAN station coordinate.

Primary reference: [Eagle Dynamics F/A-18C guide, TACAN and ICLS sections](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf). Installed `FA-18C/Cockpit/Scripts/Radio/ILS.lua` supplies the common receiver configuration precedent. The existing native bridge uses shared `avILS` reception with independent LOC/GS validity; its implementation and ABI were not changed by this fix.

## Controls

- NAV AUTO/MAN remains the existing bezel control and binding. Enable AUTO once; NEXT/PREV no longer switches it off. WPDSG pauses automatic advance, and UNDESG releases that pause.
- For an approach, tune the runway's ILS frequency through ICP CNI. Select ILS on NAV for early acquisition, or lower the gear fully to enable received approach bars alongside TCN/WYPT steering. For the included Batumi mission, use ILS 110.30 MHz and TACAN 16X T/R.
- Bars follow each native channel's actual validity and disappear on signal/power loss. No autoland or automatic ILS coupling is added.

## Validation and scope

Only five cockpit Lua files are installed: `Nav_Computer.lua`, `Navigation_System.lua`, `Nav_Guidance.lua`, `HUD_Flight_Data.lua` and `HUD/page.lua`. The DLL, radar, stores, route files used by the user, bindings and unrelated work are preserved.

Evidence: `D:/Codex-F22-Overhaul-2026-10-25/nav-landing-fixes-20261026/`.

The route test enables AUTO using the actual MFD bezel, performs NEXT/PREV, then releases active pause and flies through successive fixes. It confirms two automatic advances and final-point ARRIVED without wrapping. The approach test uses the existing Batumi ILS mission and real tuning/gear/master-mode commands; no radio flags, coordinates or deviations are injected into production inputs.

Focused Lua regressions cover AUTO preference retention, designation pause/resume, sequencing with an unavailable HUD but valid EFM velocity, independent ILS/TACAN/IRS state, landing with A/G retained, gear-up suppression and power/signal loss. Existing NAV workflow, coordinate entry, designation and HUD flight-data checks also pass. Native readbacks and installed hashes are recorded alongside the preserved before/after files.

## Native results

Both dedicated tests passed, using desktop DCS with VR disabled:

| Check | Measurement |
|---|---|
| Physical MFD AUTO + NEXT/PREV | AUTO stayed 1 and the selected point returned to WP2. |
| Real route passage | Ownship advanced 2,247.6 m in the first flight interval; WP2 and WP3 sequenced to WP4, count 2, AUTO still 1. The final point then reported ARRIVED and did not wrap. |
| TACAN and ILS together | Batumi 16X T/R bearing/range were valid. At 110.30 MHz with gear down, both native LOC/GS and HUD LOC/GS were valid while TCN remained the steering source. |
| A/G retained during landing | HUD mode 7, landing configuration 1, FPM valid 1; both HUD ILS channels remained valid. |
| Actual approach motion | After releasing active pause and flying, received deviations changed; the HUD retained both bars. |
| Loss/recovery | Retuning to 108.10 MHz cleared both native and HUD validity flags; restoring 110.30 MHz recovered both. |

Artifacts: `route-results.json`, `approach-results.json`, `route-native/dcs.log`, `approach-native/dcs.log`, and `installed-final.json`. Five installed Lua hashes match the tested source. Only the two owned test processes were stopped; DCS is closed and ready for the user to launch normally. VR-specific drawing was not tested, and this check did not fly a full touchdown/autoland.
