# Ground RF range controls

The user explicitly wants RNG+/RNG− retained. Those controls already selected
5/10/20/40/80/160 NM. Air tracks with range followed that scale; ground RF
contacts without a passive position fix used native relative signal strength,
which has no nautical-mile denominator. Changing range therefore left them fixed.

Ground receivers now have an additional **estimated** position path: intersect
the received, attitude-qualified world bearing/elevation with checked terrain
height. The ray starts at the ownship position at reception, not at a target
position or the current aircraft position. Existing triangulated solutions take
precedence. The estimate passes through the existing RF geolocation validation,
fusion, DEF and TSD consumers. It does not become radar measured range, target
identity or weapon authority. Signal strength is never converted to NM.

DEF retains RNG+/RNG− and its existing air-contact projection. `E` identifies an
estimated position; `>` identifies a ranged/estimated contact clamped to the
outer ring. An unlocated RF contact retains relative proximity under `REL RF`.
Terrain failure, shallow rays, stale/missing reception origins, insufficient
accuracy, source removal and power/clock resets withdraw the estimate.

This is a mod model, not a recovered ALR-94 ranging algorithm. Assumptions are a
stationary ground emitter, a one-degree direction envelope and 50 m of antenna/
terrain-height error. The solver rejects depression below 3 degrees, solutions
under 500 m, uncertainty above 10 km or half the slant distance, and intersections
beyond 160 km. Terrain is sampled at 1 km intervals with ten bisection steps;
narrow intervening terrain and multipath are not modeled. Direction/terrain
uncertainty is approximate, not a calibrated confidence interval.

The owner retains at most sixteen entries, attempts at most one ray per 50 ms
callback and makes at most 171 checked height calls per attempt. Original sample
time is retained; copying cannot renew its six-second life. Contradicting fresh
directions invalidate cached estimates. Status telemetry
`F22_RWR_TERRAIN_GEO_STATUS` records the last attempt: 0 success/reset, 1 missing
height provider, 2 invalid/failed terrain read, 3 no intersection, 4 geometry or
uncertainty rejection. It is diagnostic, not a readiness flag.

Primary evidence: read-only IDA MCP review of the installed CockpitBase.dll,
SHA256 `fb0a09be70627c7790dea1527cedfee43082bb8b112484d5c85be1d99d33de95`,
`avRWR::getEmitterPos` at `0x1803e9ed0`, exports azimuth and elevation from the
normalized emitter direction. The installed terrain API is already consumed by
the mod's navigation/AG owners. No native patch or mission-object access was added.
The [ED Hornet guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf),
pages 412–414, describes relative bearings and threat bands. Our requested NM
controls remain a mod feature; they are not claimed as a Hornet RWR control.

Ten new requirement cases exercise the actual receiver/fusion/DEF/TSD chain,
actual range buttons, terrain slope/failure, stale observations, clock/power
invalidation, contradictory directions, invalid inputs, bounded work and unchanged
air ranging. The old installed package fails the ground-position expectation;
the proposed package passes 30 focused cases through 64 script dependencies.
Source plus Lua syntax checks pass 33 cases. Luacheck 1.2.0 reports no new
findings; all new solver functions have complexity at most 9. Existing large
geolocation/RWR update and declarative display functions remain scoped legacy
exceptions; this small integration does not claim their wholesale compliance.

Actual native terrain-query cost, in-flight estimate accuracy/legibility, VR and
multiplayer remain untested. The calculation uses cockpit observations and local
terrain only, with no mission hook or server truth dependency. That architecture
does not itself establish multiplayer qualification. Installation identity is
recorded in `GROUND-RF-RANGE-INSTALLATION.json`: source commit `ceb4d66` is
installed in the normal Saved Games mod. All four Lua hashes match, 431 protected
files remain unchanged and 30 installed-package cases pass through 64 actual
script dependencies. DCS was absent, no simulator input was sent and the
installation lease was released.
