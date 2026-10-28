# Ground MAP partial-collection refresh regression

The reported frozen map is a real regression. In the Oct27 player flight,
`VIDEO_FROZEN=0` and live native camera position/heading changed while repeated
GPU observations retained the same image. Mode/erase changes could produce a
new picture, but ordinary aircraft motion then left it retained. Source and
offline tests alone did not qualify moving terrain-video behavior.

Two connected defects were found:

- Lua sent `floor(controls.units)` as the native image collection value.
  The native renderer refreshed only when that value changed. Completed partial
  RF work was discarded until an entire two-axis image volume accumulated.
- Collection advancement depended on sampling a short `SURFACE_SERVICE` pulse
  at the slower cockpit update. It also stored a new sequence even if the pulse
  had already ended. Completed jobs could disappear between producer and
  consumer callbacks, delaying whole-volume completion further.

The native array now publishes persistent cumulative discovery sequence/work.
Only completed search beams contribute `1/actual_cell_count`; pointed/routine
jobs contribute zero. The Lua consumer checks publication coherence, generation,
time and monotonic source state, then consumes the work difference once.
Missed callbacks deliver already completed RF work; they do not simulate extra
dwells or refresh track observation timestamps. Unknown/torn/stale/reset sources
cannot replay history. A128-volume per-publication limit bounds malformed jumps;
normal half-second control leases and minimum surface dwell fit inside it.

Partial work reaches `F22_AG_VIDEO_COLLECTION` without rounding. Native scene
refresh requires changed completed work and respects FRZ. A geometry/UI change
can erase/reformat video, but cannot independently authorize new terrain pixels.
The image reference pose updates with the actual refresh. ACTIVE still ends at
its requested collection boundary; display callbacks do not generate RF work.

The ordinary radar telemetry was skipped by the A/G early return, concealing
the source state in these flights. A/G now records the same bounded stream,
including control emit/surface, cumulative work, image progress/reference time
and hold state. Completed-beam search metadata persists independently of its
one-callback service event. Native ground sensing keeps its explicit beam grant.

Checks: Release DLL build,31 native tests and165 script checks pass. New tests
cover fractional image refresh before a whole volume, missed pulses/skipped
jobs, duplicate/pointed work, packet/epoch faults and native publication after
the service pulse ends. Native scheduler tests account for every discovery job
and exclude pointed jobs from accumulated work. Lua has0 new lint findings and
all5 changed Lua sources pass DCS syntax. The native video test retains the
existing NDEBUG/UNDEBUG command-line warning. Actual moving GPU imagery on the
new combined installed DLL still needs the post-fix flight check; passing
offline tests is not that check.

That change corrected collection delivery; the follow-up below shows why its
renderer invalidation was insufficient. It does not establish
full SAR/reflectivity processing, imagery under every terrain/lighting case,
complete ground association or validated aircraft performance parameters.

## Follow-up: common RBM cache contract

The next player flight still froze. Its320 AG snapshots cover model time
473.059–1045.857, all in MAP mode1. Completed fractional search work advances
from0.11038961 to34.3246753, and the image reference time follows it. Nevertheless
GPU mean0.16899871826172 remains identical from approximately906–1045 while
the live camera and parameter callback counters continue advancing. Readiness,
camera callbacks and completed RF delivery were not proof of new terrain pixels.

The common renderer was decoded at the matched installed engine profile:
Visualizer08FCE0/090E50/0912F0, SceneRenderer045F40, and enlight AGRadar
update06530/draw03630/buildDBS03540. DynamicParam5 is **buildDBS**, honored by
DBS mode1; stock MAP uses RBM mode0. MAP rebuilds its terrain cache when
DynamicParam0 changes direction. The adapter held it at+1 indefinitely, so
requesting buildDBS could not refresh the MAP cache. This corrects the earlier
interpretation of parameter5 as a general refresh flag.

The owned adapter now coalesces actual completed RF work into image transactions,
alternates the renderer cache direction at each transaction, and keeps the same
camera/point/parameters through four accepted parameter captures. The recovered
renderer has three draw stages; four submissions conservatively allow them to
finish before replacing the captured geometry. Multiple camera callbacks before
one parameter capture do not consume extra stages. This is renderer protocol,
not a mechanical antenna or a second sensing scheduler. DBS requests remain
exclusive to expansion imagery. No elapsed timer or camera motion creates RF
work. FRZ retains the captured image and its original reference epoch.

New diagnostic counters distinguish image captures, RBM restart requests and
DBS requests. These count provider submissions, not GPU completion. The opt-in
GPU probe remains the evidence needed to qualify changing imagery in DCS.

The actual callback regression uses the recovered cache contract and the flight's
three-camera-calls-per-parameter pattern. A separate identical contract probe
against the previous provider produces1 terrain restart/1 changing geometry;
the fixed provider produces10/10. Tests also cover coalesced RF work, no new RF,
FRZ/resume, expansion, stale/powered-off controls, foreign objects, generation
reuse without reconstructing the native camera, and a latched malformed buffer.

GMT uses a separate native detector. This flight recorded GMT_READY1 but zero
queries and zero candidates because GMT mode was never selected. A new test
executes NativeGroundSensor's actual scene query, beam gate, measurement/filter
and processing queue: it detects a10m/s vehicle, estimates its motion, rejects
terrain-masked/off-cone/stopped search returns and dormant objects, retains an
acquired stopping target, and coasts/expires without inventing observations.
Existing Lua tests cover transport, selection, designation and display bricks.
These are substituted-host checks; actual in-game GMT detection remains unqualified.

Checks:35 native tests and169 script checks pass; modified Lua parses in DCS
Lua5.1 and has zero new lint findings. New image/identity fixtures compile under
MSVC /W4 /WX /analyze. Existing NativeGroundVideo API binding/install/update and
parameter callback remain explicit legacy complexity exceptions: bounded18-value
host transport, exact owner/profile/lifetime guards, fixed image state, no scene
query in the render callback. No whole-file compliance claim is made.
