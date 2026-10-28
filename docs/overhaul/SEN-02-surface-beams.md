# One array owner for actual surface looks

Surface acquisition, tracking and AGR now request pointing from the owned array
scheduler. They cannot repoint the ground sampler after receiving an unrelated
RF grant. The immutable completed beam carries world direction, cone half-angle,
range and actual completion time; starting the next air job cannot overwrite it.
The sampler requires that explicit current beam and resource state. There is no
optional parameter-only illumination route. Frustum and exact-cone/range checks,
terrain ranging, object acquisition and fixed-point confirmation use that beam.

Pointing is transformed through the aircraft's full pose and the physical field
of regard. Ground search remains stabilized to the horizon. A fan search covers
a finite two-dimensional grid over the declared1..59deg depression region, using
3deg cone half-angle and20ms dwells. A selected/acquiring ground point or AGR can
request the next surface job; old request data cannot rewrite an in-flight job.
The existing two-surface/one-air job division is retained, including priority air
service. These are game policies, not authenticated APG-77 scan dimensions.

Unselected measured surface tracks request routine looks after1.5s. One in four
surface jobs can service this request; the other jobs continue discovery. Wide
surface search can take longer than the former six-second cache lifetime, so
coasting SA retention is30s. This extends memory only: no hit or observation time
is renewed, and the estimator's independent six-second reinitialization and
five-second selected-track limits remain. Overload cannot provide unlimited
fresh tracks. Ground association still uses native IDs and needs the independent
measurement-association migration already completed for air tracks.

Selected ground state remains anchored at its actual observation epoch. The old
coast loop mutated the measured point and steering then predicted it again. That
double prediction is removed. The cockpit separately predicts its display from
qualified velocity, hides vector/speed/course when motion is unknown, and hands
off the measured coordinate rather than a freshly timestamped display forecast.
The vector aspect uses the measured ground track instead of a constant zero.
No numeric text format, saved binding, HUD styling or recording is replaced.

Ground capability readiness requires both the owned AESA driver and the actual
ground producer; a surviving driver cannot mark an unavailable receiver healthy.
MAP requests retain their actual surface range even while the object receiver is
inactive. Diagnostics publish actual completed surface elevation/width/range/time
alongside its sequence/azimuth. Discovery-job metadata carries its real two-axis
cell count; pointed/routine looks receive no image-collection credit. ACTIVE
collection cannot finish by treating one horizontal row as a whole volume. Coasting publication remains separate from a new RF look.

Verification exercises actual native owners: mid-dwell request replacement,
completed-beam versus next-job separation, finite vertical/horizontal search,
retained air service, routine/discovery division, current/stale requests, explicit
resource/beam rejection, AGR terrain rays, no fresh look from a non-downward beam,
qualified measured-track cueing, current ground readiness, fixed storage and
no observation refresh from coasting prediction. Lua checks cover the real A/G
track, designation, unknown-motion and display-element paths. The renderer still
supplies terrain imagery; this does not claim SAR reflectivity/signal processing,
PRF ambiguity resolution, complete surface association or in-game qualification.
DLL and matching A/G Lua/indicator changes must be packaged together.

The subsequent [moving-image refresh regression](SEN-02-ground-refresh.md)
replaces pulse-sampled image credit with cumulative completed native RF work and
preserves its fractional progress through renderer cache invalidation.
