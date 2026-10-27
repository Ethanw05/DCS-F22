# NAV-WP03/07/08 — independent altitude and relief control

Selected analogue: ED Hornet guide, 24 March 2024, pp47–48. HSEL/CPL selected
from OFF leave pitch manual. BALT/RALT/V/S preserve the selected lateral mode.
The native owner captures indicated pressure altitude or independently valid
radar height; UFC no longer presets geometric MSL first. The same owner handles
keyboard and physical selection. Losing NAV decouples lateral control and latches
the reason while healthy vertical control continues. Restoration never engages
a mode. Command 11626 acknowledges the loss without changing mode selection.

CPL roll-stick override is temporary (0.18 enter / 0.12 neutral, game thresholds).
Manual pitch input releases the vertical mode. The ordinary paddle releases AP
and A/T permanently. The pre-existing explicitly held override/recapture bindings
remain a separate mod option, not a recovered F-22 core behavior. A roll-only AP
does not inhibit the manual-pitch autotrim path. These two physical-loop predicates
were coordinated with the aircraft owner; no force or hydraulic model is replaced.

BARO validity is independent of CAS success. A missing pressure measurement cannot
silently become geometric height. Radar measurement validity, numerical sanity
(20 km), display and RALT control envelope (60–1524 m) remain separate policies;
the latter are estimates, not authenticated F-22 receiver performance. Radar age
uses the existing native model clock, separately from the EFM elapsed clock used
by navigation/AP. Healthy pressure-altitude HUD publication is outside CAS logic.
No HUD styling, projection geometry, recordings or installed mod is changed.

Cruise A/T remains independent of pitch AP. CAS and Mach target memories step
independently. Pilot OFF is ordinary; rejected/automatic loss has a separate
10-second feedback field. Axis takeover (0.08 normalized input), output bounds,
rate limits, gains and LIMIT indication are game policies; engine authority and
closed-loop flight calibration remain qualification gates. No approach ATC,
autoland, carrier ACLS or automatic GCAS is enabled by this work.

Actual controller tests cover independent axes, source failure/restoration,
override/resume, north crossing, stale NAV, RALT envelope, target memory and A/T
takeover. The built DLL with isolated CockpitBase/World fixtures proves indicated
1000 m capture while geometric height is 3000 m, radar expiry/no reengagement and
acknowledgement without engagement. Fixtures are never installed in DCS. MSVC
19.51 Release and `/W4 /analyze` pass; native flight dynamics/receiver optics and
VR remain unqualified. Legacy RAPTOR physics and large Lua update/page builders
are retained; bounded command helpers isolate this change rather than asserting
whole-file NASA compliance.
