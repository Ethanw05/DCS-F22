# Ground radar flight presentation and HUD fixes

The 28 October flight reported a flashing scan highlight, missing HUD cues after
ground tracking, and GMT bricks in MAP. The latest log contains three ground
segments; native ground/video readiness is present. In segment 2, all 50 logged
object-track samples have MEMORY=1 and DESIGNATION_VALID=0. The last segment
instead acquired type-3 fixed terrain fallback coordinates, not object locks.
`FLIGHT-DIAGNOSIS.json` preserves the log identity and representative rows.

The native no-surface-grant branch marked every retained ground track as memory
while A/A jobs used the array. The ordinary surface branch also compared age
with twice the most recent callback interval. Neither is a stable measurement
freshness definition. The Lua handoff requires a live associated observation,
so these flags prevented a designation from reaching the HUD. The fix uses
original measurement age, finite/current time and association across both kinds
of interval, with a declared .5-second game-policy lease matching the existing
ground packet lease. Loss/ambiguity/old data still enters memory. No observation
time is renewed, and air intervals create no surface query or RF credit.

The shared renderer's DynamicParam8 adds a bright cosmetic footprint. It is
now zero: rapidly changing AESA looks/cache direction no longer drive that
highlight. Image collection, measured scan fraction, GMT limits and array
scheduling are preserved. This does not add a slow fictitious antenna sweep.

The old display explicitly painted the ground search contact list in MAP as
well as GMT/sea modes. Those unselected bricks are now gated at both producer
and indicator to GMT/sea search/tracking modes. Internal returns and a selected
ground target remain available in MAP. GMT's MAP-image interleave is a separate
control; this change does not disable interleaved sensing.

The installed `AG_Mark_System.lua` was also older than the already committed
coherent consumer. The installation pairs that consumer with the present
ground protocol/provenance/snapshot modules, preserving original source time,
source epoch and withdrawal. Its end-to-end test drives an actual ground owner
and native track packet through the actual mark owner to a valid HUD cue,
then verifies withdrawal on real memory/loss. No HUD geometry, font or styling
is changed. HUD target/cue/edge flags are added to the existing one-second
ground diagnostic for the next flight.

Source checks: 35 Lua cases; 26 cases through the planned installed closure;
actual native callback acquisition/air-interleave/expiry/association tests;
650 camera/parameter checks; 230 ground-host and 516 video-API checks. Native
fixtures have zero warnings under `/W4 /WX /analyze`; Lua lint has zero new
findings. The full DLL retains 64 unrelated baseline warnings, with none in
the changed native files. Source and build identity are recorded in RESULTS.

Actual displayed pixels, HUD visibility and flight/VR performance require the
next in-game check. The pre-change log did not record HUD cue flags directly;
the rejected handoff is established from designation flags, code and reproduced
native/Lua behavior. Type-3 terrain fallback must not be advertised as a moving
object lock. No SAR capability or new host ABI/profile is enabled here.
