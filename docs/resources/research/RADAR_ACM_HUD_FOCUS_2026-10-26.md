# ACM commands rejected with HUD focus — 26 October 2026

The user flight at 21:16–21:17 UTC selected HUD focus before GUN, then
repeatedly pressed vertical and boresight. The commands reached the cockpit,
but `Combat_Logic.lua` rejected TMS scan selection unless the radar display
had focus. WIDE therefore remained active. The prior weapon-state fix did
not cover this focus state. Its regression fixtures used radar focus.

The focus guard now permits TMS up/down/right in HUD-focused GUN and SRM.
Other display focus, BVR focus guards and A/G HUD designation retain their
existing behavior. Input bindings are unchanged. `F22_HOTAS` now records
decoded values, mode, focus and primary format; `F22_RADAR_REQUEST` records
accepted requests, alongside the existing applied radar-state diagnostics.

The added regression fails before the correction with `expected VACQ, got
WIDE`. Replaying the recorded inputs through the actual Lua controllers
dispatches 30 scan requests after correction versus zero before. The one
remaining press occurred in NAV and stays inactive. This replay uses an
empty native sensor fixture and does not reproduce flight physics.

Native DCS validation passed twelve state snapshots with HUD focus selected:
WIDE -> VACQ -> BORE -> WIDE -> BORE -> VACQ; repeated GUN selection;
SRM search and boresight selection; restored GUN VACQ; MRM and NAV search.
Logged scan requests were 30 x 20 degrees for WIDE, 10 x 59 for VACQ, and
3.3 x 3.3 for BORE. Fifteen relevant regression suites also pass, including
confirmed-STT preservation and acquisition switching. Native validation
used active pause and a dedicated sensor scene; it qualifies control/state
behavior, not dogfight detection performance or weapon accuracy.

Only `Combat_Logic.lua` and `Combat_System.lua` were installed. Source and
installed hashes match. The owned DCS test process was closed afterward.
Evidence, original user log, source backups, replay, twelve native snapshots
and complete native log are preserved at:
`D:\Codex-F22-Overhaul-2026-10-25\radar-acm-focus-20261026`.
