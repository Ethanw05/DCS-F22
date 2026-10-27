# Ground MAP integrity corrections — 25 October 2026

The current terrain MAP owner now addresses the three designation defects and scan-command concern in the separate ground-radar audit. These changes do not implement SAR/GMT or calibrate real F-22 radar performance.

## Corrected behavior

- **Independent command time:** designation uses current model time supplied by the outer radar owner, or a protected native clock call. Missing time fails closed. Both the last ground-owner update and native batch must be no older than 0.5 seconds. Native readiness is checked again at the command. A stopped owner, stopped transport, availability loss or clock rewind cannot renew an old candidate.
- **Reselection at designation:** cursor/recenter/range/width edits invalidate the cached candidate immediately. TDC selects again from the current bounded image using current cursor state and the most recent fresh display pose. It never silently reuses a previous selection. A rejected command does not alter an already accepted stationary coordinate or increment the designation sequence.
- **Shared cursor footprint:** display and selection use the same +/-0.025 normalized cursor dimensions. Candidate testing occurs in projected display coordinates, replacing the former range-based circular snap gate. Stationary image points still expire after eight seconds.
- **Bounded scan requests:** requested scan width is retained while its centre is recentered as needed to fit the declared common-backend +/-60-degree azimuth envelope. At a 55-degree cursor bearing, a 120-degree scan stays centred on zero; a 30-degree scan centres at 45 degrees. A cursor outside the reachable body bearing is explicitly marked uncovered in diagnostics. Effective centre, width and constraint state are published; the page shows the centre as `CTR`.

The 0.5-second publication limit, eight-second image life and azimuth bound are declared mod policies. In particular, this is not a recovered APG-77 scan schedule or proof of the native scanner's physical clipping behavior. Existing image coordinates remain static terrain measurements rather than moving-target tracks.

## Verification

`tests/test_ground_radar_integrity.py` covers the real outer command path during an owner stall, stale transport, loss of native availability, recovery, rewind and immutable accepted coordinates. It tests digital movement/recenter before an activity update, all four map ranges, 48 heading/selection-boundary combinations, the former 40-NM out-of-box snap, 1,083 scan-width/body-bearing combinations, and the actual rendered cursor definition at three native scales.

The initial isolated source copy passed all 52 Python/Lua/asset checks. After merging the latest concurrent work, the final shared-source run passed 53/54 checks. The sole failure was `test_mfd_shared_pages.py` on the NAV/HSI element snapshot; it was reproduced in the shared source before these radar changes. All ground-radar integrity, handoff, delivery and SCS checks passed. A transient navigation failure in an intermediate copied snapshot disappeared against the current shared source. The actual Lua and original font were rendered in three synthetic ground-map scenarios and visually inspected; these are offline fixtures, not DCS captures. No native C++ sensing or weapon code was changed by this correction. Live DCS acceptance is pending, with the user's installed mod/session left untouched by this task.

The native retest should include analog cursor acquisition, command timing at the frame boundary, off-axis narrow/wide scans, varied attitude/altitude and A/A–A/G transitions. Recheck the new `CTR` readout, accepted coordinate and designation sequence against actual input events. The prior native terrain-return and range-change evidence is useful context but does not qualify these new changes by itself.
