# NAV-WP05 — received radio components and angular course indication

The installed ED Hornet guide (24 March 2024), pp136–138 distinguishes receive-only
bearing, transmit/receive bearing plus slant range, and air-to-air range without
bearing. Its p145 selected-course HUD uses 4/8-degree references. This mod adopts
those references for the TACAN course-line CDI: 4 degrees is the inner mark and
8 degrees full scale. This is a named display adaptation, not a recovered F-22
instrument calibration. Waypoint cross-track retains its separate 2 NM full scale;
the active scale is labelled on NAV.

`Radio_Navigation.lua` only admits received native components. OFF admits neither;
REC admits bearing; T/R admits both; A/A modes admit only range when the host's
actual range-valid flag is set. No range is synthesized in REC or from geometry,
and no A/A bearing is invented. The two A/A submode reception cases still need a
controlled host check; these admission rules do not establish that either submode
actually receives. Range-only DME remains visible even without heading/position
or bearing. Magnetic DATA bearing does not need an ownship variation conversion;
true bearing and projected guidance do.

Bearing-only OBS retains its angular CDI and TO/FROM indication. It withdraws the
range-dependent intercept solution and HUD track-steering cue instead of silently
substituting direct-to. Explicit direct bearing steering remains available with
OBS off. Invalid/nonfinite components withdraw their authority; restoration does
not engage AFCS. The native receiver remains the measurement owner.

Actual Lua guidance tests cover range-invariant angular deviation, both signs,
TO/FROM passage, saturation, REC/T/R/A-A, range-only DME, malformed components,
magnetic-reference loss and the separate waypoint scale. Existing independent
ILS LOC/GS, GINS-loss radio survival and true/magnetic course-invariance checks
remain applicable. DCS Lua 5.1 compile and pinned lint/complexity checks are run.

Still open: station magnetic variation is not ownship variation. The guide p140
requires magnetic-course fallback for an unknown TACAN database station; native
station identity/datum access must be qualified before adding that contract.
Ident/marker audio, actual LOC/GS sign/sensitivity, A/A reception and controlled
station-loss scenarios remain host qualification tasks. Missing adapter fields
do not prove that receiver audio is absent. ILS remains advisory runway guidance;
no backcourse, ICLS/ACLS or automatic LOC/GS capture is advertised.
# Current selected-course contract

OBS steering requires schema1 canonical true course in [0,360) degrees. The
deprecated raw display-course plus variation substitution is removed. Missing,
withdrawn or nonfinite selected-course data withdraws OBS steering/CDI for both
waypoints and TACAN; independently received bearing/range remains available.
The actual guidance regression reproduced raw-course acceptance before this
change and now covers invalid bounds, restoration, reference invariance and no
implicit direct steering when the selected OBS course is unavailable.

