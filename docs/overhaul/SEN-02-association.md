# Owned radar association and source-scoped fusion

Radar track numbers are owned tokens, distinct from simulator object IDs. The
tracker receives range/azimuth/elevation/Doppler samples and full predicted EKF
covariance. A non-mutating normalized innovation score validates each candidate;
mutual nearest matches must pass gate36 and a9-point alternative separation.
These thresholds are explicit game policies. Processing groups returns by their
actual dwell epoch, with one report per assigned track. Ambiguous reports coast
existing tracks, withdraw association/support authority and never renew sample
time. Same-epoch overlapping births cannot become perfectly separate targets
merely because the scene supplied different object IDs. This is a conservative
single-hypothesis method, not a claim of APG-77 software, JPDA or MHT.

A separate private binding connects accepted detections to DCS objects only at
the native weapon boundary. It requires three consistent reports and a mature
velocity estimate; ambiguity, stale clocks/generations and duplicate bindings
withdraw it. The responder answers host target/support queries through this
binding, while cockpit targeting and launch-history/TOF use owned radar tokens.
The actual payload launch continues to receive the host object ID. No binding ID
or target truth is published into the radar observations.

Association validity updates independently from the measurement timestamp and
cached covariance. Lua acquisition, retained track supportability and native
weapon support withdraw together. A coasting plot remains an old observation.

Tactical picture IDs occupy a third, independent namespace. Radar, RF, optical
warning and datalink reports retain their original source IDs and times. Equal
numeric IDs across sensors cannot establish a match. Unique reciprocal geometry
matches combine awareness; ambiguous bearings remain separate. Fresh bearing
association uses a3deg game gate and1s source-age limit; timestamped offboard
positions may project up to13s and additionally require a500m+25m/s-age position
margin and100m/s velocity gate. Unknown-age donor positions do not transfer
identity through correlation. These are estimated association policies, not
recovered datalink accuracy or authenticated F-22 procedures. Awareness fusion
never grants fire-control authority or inserts data into the radar EKF.

Datalink records are keyed by link/reporter/source, preserving two aircraft each
reporting their own track1. A remote radar track number equal to our host ID is
not discarded as ownship. PPLI membership/affiliation remains its direct native
network evidence, separate from these local radar tokens. TSD duplicate hiding
uses the correlated radar observation's ID, not an accidental picture-ID match.
Pilot donor consent also binds reporter and link.

The retired radar-ID-to-RWR classification cache is removed. Qualified radar ID
comes through its matched tactical observation and retains a separate known
identity time. Fresh position/producer heartbeats cannot renew old friendly
identity. Source evidence/conflict and friendly protection remain inspectable;
unknown/future identity times remain unknown.

Verification: identity permutation without track renumbering; a same-ID position
jump cannot drag an established track; competing returns withdraw authority;
Doppler distinguishes two crossing targets; native host/track translation,
duplicate-binding refusal and same-timestamp authority withdrawal; actual
payload host ID versus recorded radar token; equal/different sensor IDs,
ambiguous bearings, geometry divergence, known/unknown donor correlation,
reporter collision and frozen identity ages. Native air callbacks retain fixed
storage and the allocation probe passes. A Lua5.1 dense160-contact association
microbenchmark measured2.29ms/update and no retained growth over1000 updates on
this host; this is not an in-game frame-time measurement. Entry buffers/maps are
reused. Existing native radio/ground callback allocation/complexity exceptions
remain; no whole-module compliance claim is made.

Design reference: MathWorks, Tracking Closely Spaced Targets Under Ambiguity,
R2026b, Introduction and Single-Hypothesis Tracker sections explain unresolved
returns, validation gates and the limits of one-hypothesis assignment:
https://www.mathworks.com/help/fusion/ug/tracking-closely-spaced-targets-under-ambiguity.html
Numeric choices above are ours. Multi-donor track-to-track fusion, modeled RF
resolution/clutter/false alarms, PRF ambiguity/interference and actual DCS
multi-target missile/ground/failure qualification remain open. DLL and matching
Lua consumers must be deployed together and flown before runtime acceptance.

Current checks:164/164 script regressions,30/30 native tests, DCS Lua syntax
for15 changed files and scoped lint0new/69baseline pass. New association/bridge
helpers remain within CCN15 and60-line targets; retained native initialization,
query, driver and radio/ground legacy exceptions are not a compliance claim.
