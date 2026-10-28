# SEN-01Ã¢â‚¬â€œ04: owned AESA sensor

This replaces the earlier native-constrained slice. Device13 is an owned
`avLuaDevice` clock; no `avSimpleRadar` detector, mechanical scan, observation
cache, acquisition command or target responder remains in the production path.
The common engine supplies scene objects/visibility and weapon services. Our
model owns sensing, finite array jobs, noisy measurements and estimated tracks.
These work items remain partial pending the qualification limits below.

## Physical model and evidence

- Electronic pointing steps between search cells and priority targets. Dwell,
  processing delay and observation age are distinct. A quarter of air RF time
  reserves discovery; ten priorities cover two designations and eight missile
  obligations. [The service-deadline correction](SEN-02-revisit.md) adds distinct
  GUN, acquisition/STT, missile-support and routine deadlines. A/G reserves two surface jobs per three array jobs;
  completed surface grants gate search, acquisition, tracking and ranging.
- Range-fourth-power response, off-axis gain, visibility, detection probability,
  a simple look-down penalty and noisy range/angles/radial Doppler precede
  tracking. Environment Cartesian velocity is private to measurement generation.
  It is never published as a measured full velocity. Radar IFF remains unknown.
- A six-state Cartesian EKF observes range, azimuth, elevation and scalar Doppler
  with measurement-time sensor pose/velocity. It uses full covariance, a CV
  process and Joseph updates. Initial transverse velocity is uncertain. A repeated
  timestamp adds no hit; inconsistent innovations are rejected without clipping
  velocity or resetting on an arbitrary outlier count. A >6s association gap
  starts tentative again. Coasting never refreshes the measurement timestamp.
- Air and surface object tracks use this estimator. Fire-control velocity requires
  two reports and worst-axis sigma <=100m/s. This is a declared game threshold,
  not APG-77 track quality. Priority revisits use completed RF-look time, including
  missed detections, so processing latency cannot cause redundant priority bursts.
- Power, thermal state and array integrity reduce the common resource budget;
  partial resource lengthens dwell/processing. NoseCenter damage is a declared
  array-effectiveness estimate. Repair retires generation without reviving a
  released native owner. The integrated physical owner remains authoritative.

All numerical policies are estimates:20ms search dwell,4..20ms tracking dwell,
12ms processing,3deg beam half-angle, requested25ms gun/50ms fire-control or
missile-support/100ms routine revisit, reference80km at1m2, noise laws and
continuous acceleration intensity100m2/s3. Callback cadence quantizes these
requested times. The ground8..55kt discovery predicate is an APG-73 game analogue.
Air association now uses measured innovations/covariance; its simulator-object
binding is private to the weapon boundary. Ground association still needs the
same migration. Exact aspect-dependent RCS, waveforms/PRFs, ambiguity resolution,
ECM/CFAR and false-alarm simulation remain open. These are not authenticated
APG-77 processing or performance.

Sources consulted: [Brower, 2001, ch32 Ã‚Â§32.3.2 p8](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf)
for interleaved electronic service; [NOAA PAR](https://www.nssl.noaa.gov/tools/radar/par/)
and [RTX APG-79](https://www.rtx.com/raytheon/what-we-do/air/apg79aesa) for steering
context; [IEEE AESS nonlinear radar tracking tutorial](https://ieee-aess.org/media/basic-tracking-using-nonlinear-3d-monostatic-and-bistatic-measurements)
and [MathWorks measurement model](https://www.mathworks.com/help/fusion/ug/introduction-to-radar-for-object-tracking.html)
for range/angles/Doppler, pose and uncertainty. The installed ED Hornet guide
pp171Ã¢â‚¬â€œ176 supplies named ACM/TWS procedural analogues; mod VACQ/WIDE choices
remain estimates. These references do not authenticate the tuning above.

## Native and consumer contracts

`NativeAesaRadar` guards PE identities, the exact avLua device/vtable/update,
owned callback lifetime and borrowed context-responder slot. The inspected
CockpitBase build has timestamp `0x6ac12468`, image size `0x59a000`, SHA256
`163d55167503da8dd0ea9eb459e17206fc3dc8d6b4805b5b13bbe58341beb794`.
The shared scene query/object conversion and terrain/object LOS are independent
of the retired radar. Research databases/decompilation remain outside commits.
The common radar-video renderer supplies pixels, not detections or scan authority.

`Radar_Resource` requires the coherent current physical envelope (mission power,
electrical validity, environmental validity, temperature and thermal fault) and
owned array health. Missing owners remain unavailable. World elapsed time checks
physical publication progress without comparing World time to spawn-relative
stamps; a >250ms stall withdraws resource. Clock loss or rewind retires authority
until fresh physical progress. No optional loose resource schema or pre-owner
MAIN POWER shortcut remains. The retired Lua processing queue/adapter and unused
mechanical STT decoder/test are removed; C++ owns sensing and processing once.
Required DCS scene, visibility and weapon services retain their current guards.

Control and measurement snapshots use odd/even sequences, absolute World/model
time and generation. Producer/request age >0.5s withdraws authority. Gun aliases,
Engagement and the shared native weapon responder use owned measurements only.
The responder accepts mature measured tracks within the six-second support
policy; existing native missile descriptor/DLZ/TOF libraries remain weapon owners.
Shared RAPTOR damage/repair hooks must follow the integrated physical guards.
Preserve the weapons owner's concurrent IR payload/generation/lifetime changes.

`F22A_%02d_` and `F22_RADAR_TACTICAL_%02d_` carry source2, observation time,
filtered N/U/E and VN/VU/VE, validity, raw point, measured range/angles/range-rate,
measurement sigmas, state sigmas and upper-triangle `COV_00..COV_55` for
`[N,U,E,VN,VU,VE]`. Covariance units follow that state. Raw measurement and filtered
estimate are different records of the same observation, not independent fusion
inputs. Metadata is copied into retained files, not aliased to reused input slots.
The weapons/fusion owner consumes this metadata without a second radar filter.

The retained ACM pattern controls post-loss return; priority lock restores the
pilot search volume between revisits. Search coverage rays depict that volume,
not a mechanical sweep. Missile autozoom includes valid target-specific RMAX;
gun zoom remains close-range. A missing envelope creates no fallback ray.
The optional blue NAV route is off by default and has an AA TSD NAV toggle on
bezel9 on all four panels. Raw `PROC Qn` debug text is removed; telemetry keeps
queue depth, and actual sensor degradation retains its warning.

## Verification and limits

The historical qualification below predates the service-deadline correction.
See [current scheduler verification](SEN-02-revisit.md) for its tests and limits.

- MSVC19.51 / VS18 Release DLL build and **28/28 CTests pass** (unused decoder test retired). New model/provider
  tests use `/W4 /WX /analyze`. Mocked native sensor callbacks allocate no C++ heap
  memory after initialization; this does not measure internal DCS allocations.
  Fixed bounds:64 tracks,32 pending reports,128 scene candidates,8 returns and
  16 visibility calls per air dwell. Snapshot scratch storage is preallocated.
- Lua5.1/Lupa2.6, Luacheck1.2.0:0 new findings,69 retained baseline findings.
  Full suite **158/158 passes** on the combined-source cleanup branch. Workflow
  fixtures publish explicit current physical/array inputs. Fault cases cover
  absent/torn/invalid/stopped owners, World/spawn epochs, clock loss, thermal/
  array degradation and fresh recovery through the actual radar controller.
  New resource helpers: maximum CCN9 and17 statement/declaration lines with
  Lizard1.17.31; retained large radar/ground callbacks are not certified by this.
- Synthetic moving/rotating-observer, irregular-revisit and maneuver test:
  position RMS16.8m and velocity RMS13.9m/s versus1642m/s raw derivative RMS.
  All160 archived position-only reports pass the replay; mean velocity step
  5.61m/s versus363.51m/s. No archived Doppler exists; see fixture provenance.
- DCS2.9.30.28738 run03,179.112 model seconds, fullscreen3440x1440 with remembered
  login:4037 discovery and1223 priority dwells,637 logged positive covariance
  reports, median estimated speed220.03m/s, median velocity step3.96m/s. Dynamic
  RMAX median successive change5.03m; max509m included maneuver/solver geometry.
  Loaded DLL SHA256 `F0B68C2A323882236CE95204BA02EA17CF5230C9E8E4E98744B91F4F1475084A`.
  This qualifies provider, clock, measured tracking, owned acquisition/responder
  and DLZ/TOF handoff; no missile was fired. It predates the final RF-revisit fix.
- Run04,53.244 model seconds, same full-screen/auth context: no STT/envelope axis;
  NAV layer/route stayed0 by default, became1 at30.192s after pilot toggle, then0
  at34.068s. The graph tests confirm no queue debug element. This run ended before
  a fresh visual capture; no claim of screenshot verification for that UI patch.
- `tools/analyze_owned_aesa.py` reproduces these bounded telemetry summaries.
  Closed logs remain in ignored build-radar. These qualification runs used the
  isolated profile. The later combined301b4c2 playtest was installed separately;
  this resource/retired-owner cleanup is source-only and has not been flown.

Outstanding: actual missile-in-flight multi-target support, surface/imagery and
physical-failure runtime qualification on the integrated flight/weapon build,
[offboard cueing](SEN-02-donor-cue.md) runtime acceptance, and broader tactical fusion qualification. Final RF-revisit
spacing is covered offline, not by the archived flown DLL. The inherited ground
adapter's long sample/update functions and parameter-string/map allocations are
recorded coding exceptions: query/ray/track work is bounded, but full callback
allocation/complexity compliance is not claimed. The air model/new provider have
fixed storage; further ground refactoring must preserve the qualified ABI.

The offboard cue consumer now has explicit source/epoch/intent validation and
finite native cue-area search; see [the donor cue contract](SEN-02-donor-cue.md).

Owned measurement association and tactical source namespace migration are
covered in [SEN-02-association](SEN-02-association.md); simulator IDs no longer
select air-track associations or establish cross-sensor identity matches.

The look-down estimate now compares target Doppler with the stationary-ground
clutter centroid, including ownship motion. The old zero-relative-rate notch
wrongly suppressed a co-speed target while sparing a stationary ground-radial
target. Width35m/s and attenuation0.15 remain explicit estimates; this correction
is not a complete terrain-clutter/CFAR model. A512-seed actual-detector replay
compares co-speed lookdown, stationary lookdown and equal-range lookup.
Reference: MIT Lincoln Laboratory, Introduction to Radar Systems, lecture7,
Attributes of Ground Clutter (platform motion shifts clutter Doppler):
https://www.ll.mit.edu/sites/default/files/outreach/doc/2018-07/lecture%207.pdf
