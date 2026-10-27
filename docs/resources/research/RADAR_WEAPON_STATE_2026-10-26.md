# GUN radar state carryover — 26 October 2026

The preserved user flight log confirms WIDE remained active after GUN -> SRM
at 20:55:38 UTC and SRM -> NAV at 20:55:39 UTC. MRM restored RWS at
20:55:40 UTC. A later GUN -> NAV at 20:58:08 UTC again left WIDE active.

Two state owners caused the fault: `Combat_Logic.lua` remembered one ACM
pattern for both GUN and SRM and reapplied it during weapon selection;
`Radar_System.lua` restored search only on entry to MRM. The active pattern
and `computer.return_mode` could therefore retain the gun's 10 NM ACM scan.
This was a state lifecycle fault; no input bindings were changed.

Radar now owns weapon-entry and exit state. GUN and SRM remember deliberate
ACM requests separately. GUN initially uses WIDE; SRM initially uses the
current RWS/TWS search. NAV and MRM restore search. Unfinished acquisition
and its retry latch clear on a transition, while confirmed native STT stays
locked and receives the correct return pattern for later reject/track loss.
Search range, volume and explicit radar-OFF preference remain intact.
Synchronization runs before a radar command as well as on update, so a
same-frame explicit pattern request wins over weapon-entry defaults.
`F22_RADAR_WEAPON_MODE` records transitions, requested/return patterns,
native mode and pending unlock. These are mod workflow choices.

Validation: the new regression fails on the previous code with
`expected RWS, got WIDE`. Fifteen relevant Python/Lua suites pass after the
change. Replaying the recorded mode/focus commands through the actual Lua
owners changes GUN -> SRM and GUN -> NAV from WIDE to RWS. That replay uses
an empty native-search fixture; it does not replay flight/detection physics.
Final native DCS flight validation remains pending.

Evidence: `D:\Codex-F22-Overhaul-2026-10-25\radar-gun-mode-20261026`
contains the original log, source backups, mode timeline, state replay,
focused diffs, test results and installation hashes. HUD/RWR and binding
files are outside this installation.
