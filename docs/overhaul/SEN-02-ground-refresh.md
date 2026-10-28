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

This fixes collection delivery and cache invalidation. It does not establish
full SAR/reflectivity processing, imagery under every terrain/lighting case,
complete ground association or validated aircraft performance parameters.
