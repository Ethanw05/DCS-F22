# Optional MAP/SAR implementation

This is the implementation route for R-RAD-022, following the user's decision
that SAR is explicitly selected within MAP. Normal MAP remains the existing
mapping path; entering A/G or selecting ordinary EXP does not start SAR.
The standalone foundation is verified, but operational SAR is not installed.
The runtime CMake glob already compiles `SarCore.cpp`; there is no live core
instance or SAR scheduler/display call path. Compiling the source does not
activate the feature.

## What can be reused

| Component | Existing implementation | Present limit |
| --- | --- | --- |
| Coherent return generation and image formation | `SarCore.h/.cpp`: complex frequency histories, range compression, motion compensation and backprojection | Standalone CPU reference; fixed capacities, no DCS connection |
| GPU image formation | `tools/sar-research/Backproject.hlsl` and streaming/optimization experiments | Standalone device; cannot simply insert that device/context into DCS |
| Depth/radiance registration | `SarSceneInput.h`: inverse projection, stable world-cell phase and bounded scene conversion | Requires paired, qualified native depth/radiance/visibility capture |
| Public terrain geometry | `SAR_Terrain_Scene.lua`: bounded height/surface calls with separate geometry time and provider lease | Terrain only; objects and visibility explicitly unknown |
| Antenna and resource owner | `AesaRadar::Model` and `NativeAesaRadar` | Surface jobs are not typed SAR grants; no coherent SAR pulse completion is published |
| Current ground display | `NativeGroundVideo` camera and renderer ownership | Existing output is MAP/DBS; the parameter callback precedes the engine radar pass |

Fresh verification on 28 October: 9,543 coherent-core checks, 50 scene checks
and seven terrain-provider tests pass. Both native fixtures compile with
MSVC `/W4 /WX /analyze` without diagnostics. The Lua provider has no Luacheck
1.2.0 findings under Lua 5.1. Core storage is 12,748,704 bytes, allocated once
outside callbacks. These are software results, not aircraft or host validation.

## Build sequence

### 1. Prove a separate cockpit image surface

Create one owned SAR image resource on the actual DCS graphics device and make
it available to the cockpit material system. Keep two completed-image slots
so a new collection cannot overwrite the image currently displayed. First
verify a calibration pattern, orientation, dimensions, lifetime and both VR
eyes. A calibration pattern is an integration test, not SAR imagery.

The current `dx11backend.dll` still exports `getDevice`, `getDeviceContext`,
`createRenderTarget` and `getRenderTargetInternal`. Static inspection confirms
the current device/context getters at RVAs 0x50e0/0x50f0 read fields +0x28/+0x30.
The current module is timestamp 0x6acb8051, image size 0x199000. This establishes
candidates, not permission to reuse old private texture layouts. Qualify the
texture descriptor, allocation/name registration, intrusive ownership/destructor,
device replacement and accepted render phase before invoking those adapters.

Use a dedicated named SAR texture/material, rather than writing the final
image into `mfd8` from the existing parameter callback: the queued engine
RadarMainPass can overwrite that target afterward. Immediate-context work
must obey the host's render ownership/synchronization; Microsoft documents
that [a device context is single-threaded](https://learn.microsoft.com/en-us/windows/win32/direct3d11/overviews-direct3d-11-render-multi-thread-intro).
Do not introduce swap-chain interception or an extra renderer owner.

### 2. Supply a complete scene through bounded tiles

Preferred full-detail route: capture unblurred radar scene radiance, matching
depth, inverse view/projection, render origin and RF-origin visibility from
the same completed pass. Reconstruct ground/object surfaces and feed them to
the coherent forward-return model. The shipped `enlight/radar.fx` and
`model/functions/radar.hlsl` are the existing scene-input research basis;
the final green/blurred display image is not a complex radar measurement.

Retain original geometry, illumination and provider times. Use stable terrain
cell phases; object scatterers need stable local geometry/lifetime handling
through motion and destruction. Reflectivity remains an explicitly estimated
game model. Apply antenna/range/area weighting once, with defined power-to-voltage
conversion. Unknown visibility or incomplete scene coverage cannot become a
healthy empty scene. A completely known empty/occluded scene can yield zero.

The public terrain API provides a useful DEM/checking path without private
terrain offsets, but its current provider cannot stand in for the whole scene.
It must not claim that buildings, vehicles or visibility have been sampled.

The current core accepts at most 256 scatterers in one pulse scene. Extend its
producer seam to bounded scene tiles: begin a frozen pulse, consume uniquely
numbered tiles, then finalize only after complete coverage. Each tile carries
the same pulse/scene identity and original times; queue exhaustion returns
backpressure. Preserve partial frequency sums until all tiles are consumed,
then range-compress once. A tile is not another pulse or extra RF credit.
Compare tiled histories against the existing one-shot analytic reference.

### 3. Add actual SAR collection jobs to the existing AESA

Add a typed SAR service alongside air search/maintenance/support and ground
search/track jobs. Preserve the current one-array owner. Due support/track
deadlines retain their bounded priority; SAR competes for remaining RF work,
with explicit airborne discovery and ground-update obligations. The current
two-surface/one-air discovery policy is a game scheduling choice, not a SAR
waveform or recovered APG-77 schedule.

A completed SAR dwell publishes a unique collection/grant token, RF start/end
times, reachable illumination volume, waveform identity and original physical
and navigation phase-centre samples. Only that completion can create phase
history. MAP refresh, GMT grants, rendering, processing and elapsed time cannot.
If a dwell represents multiple modeled pulses, their waveform timing must fit
its RF lease and their individual trajectories must be sampled or explicitly
interpolated from qualified motion endpoints; copying one pose repeatedly
does not create a synthetic aperture.

The geometry planner must check steering, useful aperture and spatial pulse
sampling for the requested footprint. Existing forward-looking experiments
show left/right ambiguity with a straight single-channel trajectory. Report
insufficient geometry instead of manufacturing resolution. Sparse or irregular
SAR illumination must remain valid input to backprojection; it cannot be
silently treated as uniformly sampled data.

### 4. Connect formation and immutable publication

Freeze grid, reference point, waveform, scene/nav/clock/source identity and
requested footprint for each collection. Keep the CPU core as the reference;
reuse the existing GPU backprojector for operational throughput, with bounded
scene synthesis/profile/image work. The current 256-scatterer and small-patch
experiments do not establish a full EXP footprint budget. A single 4,096-unit
CPU step per frame is not a measured real-time processing guarantee.

Preallocate/warm resources before flight work. Keep production profiles/images
on the GPU where practical; no blocking GPU readback in sensor/render callbacks.
For CPU-reference image upload, validate destination usage, format, dimensions,
row pitch and synchronization; [UpdateSubresource restrictions](https://learn.microsoft.com/en-us/windows/win32/api/d3d11/nf-d3d11-id3d11devicecontext-updatesubresource)
apply. Preserve/restore any borrowed graphics state and retire producers before
releasing resources.

Publish only complete images with collection/source identity, geographic grid,
dimensions, original first/last observation times and scene provenance. Both VR
eyes consume one publication. The previous complete image survives a cancelled
collection, with its original age and frozen status. Separate image retention
from current sensing health, RF consent and designation authority.

### 5. Add the optional MAP workflow and qualify it

Add an explicit SAR selection and capture/cancel/auto-refresh controls within
MAP. Preserve existing EXP, INTL, saved command IDs and ordinary MAP behavior;
do not turn them into implicit SAR requests. Show collecting/processing,
completed image age, frozen and unavailable/insufficient-geometry states. Only
an active SAR request schedules new collections. Cancel incompatible work on
power/SIL, mode/request/grid change, navigation loss, clock rollback or source
replacement. Auto-refresh starts another collection after completion under
the same RF and processing budgets.

GMT remains a separately measured moving-target service, with optional tracks
over the SAR background. Image designation uses the image's geographic grid
and original collection identity; a static image is not current moving-target
truth. Air surveillance continues under the shared scheduler independently of
which radar page is visible.

Release checks include scene/depth registration and shadows; moved/destroyed
objects; RF-off and empty-scene distinctions; interrupted/irregular collection;
navigation error and forward ambiguity; stale/torn epochs; retained-image age;
designation; normal MAP/GMT/A/A continuity; source/device teardown; and actual
2D/VR CPU/GPU frame-time and memory measurements. Install a matched native/Lua
package only after the scene and texture seams pass actual-host qualification.

## Immediate work and completion boundary

The next implementation task is the owned texture/calibration publication seam,
followed by paired scene capture. These two native proofs determine the concrete
resource and scene adapters before wider scheduler/UI integration. Existing core
tests and this implementation plan do not close those proofs. No new DCS DLL
profile or SAR runtime switch is enabled by this foundation commit.
