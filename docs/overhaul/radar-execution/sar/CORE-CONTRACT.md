# Coherent SAR core contract, schema 1

Standalone producer/consumer contract before connection to live radar source.
The core is `EFM/source/SarCore.h/.cpp`, namespace `Sar`. The scene adapter is
separately owned `SarSceneInput.h`; live AESA, scene capture and display integration
remain separate work. No runtime profile, GPU device or native ABI is enabled.

## Established research reused

The existing point-return model and zero-padded inverse-transform convention in
`tools/research_sar_point_targets.py` supply the established formation convention.
The CPU reference ports `tools/sar-research/Backproject.hlsl::evaluate`: rationalized
local range difference, explicit adjacent-bin linear interpolation, positive
minimum-frequency phase compensation, ordered complex pulse accumulation and
one final normalization. `ProbeRuntime.h` and the original GPU/optimization tools
already prove standalone GPU resource/copy/streaming experiments. They are not
duplicated or activated. Their research inputs, recordings and assertions remain
untouched. The bounded incremental CPU inverse transform replaces the research's
NumPy IFFT call; it is a production lifecycle port, not a new imaging algorithm.

## Frozen collection

`Config` schema1 contains positive collection/source/navigation/clock/environment
epochs (1..16777215), World start time and maximum duration/gap, fixed World N/U/E
metre grid origin and two metre step vectors, fixed reference point/range,
minimum frequency and positive frequency spacing, frequency/range-bin counts and
required pulse count and explicit static/dynamic scene kind. Epoch, waveform, grid, phase reference and navigation frame
cannot change during accumulation. A new request cancels incomplete work. Power,
navigation invalidity, epoch change, rollback or excessive duration/gap cancels
incomplete work without publishing a partial image.

## Explicit granted pulse and scene

`Grant` includes the exact collection/source/nav/clock/environment identity,
strictly increasing positive RF grant token, typed coherent-SAR service, completed
illumination flag, World start/end/sample times, actual phase-centre position and
independently estimated navigation phase-centre position. Only completed eligible
RF grants create histories. A/A, GMT, display, requested work, pause, replay and
failed sampling create no pulse or RF credit. Completion must precede current
time and be no older than0.25s; sample time lies inside the actual illumination.
The scheduler remains the authority for exclusive finite RF time and antenna
visibility. Core acceptance alone does not establish emitted RF or host effects.

`Scatterer` fields are `Point position` (array<double,3>, World N/U/E metres) and
`Complex amplitude` (complex<double>, effective estimated voltage including
visibility/path loss and a stable scattering phase). `Scene` carries explicit
availability, environment epoch, original geometry time and a bounded span of
scatterers. Unknown geometry/visibility is unavailable, not a healthy blank.
Available empty scenes are valid zero returns. `SceneKind::dynamic_snapshot`
requires original geometry age<=0.05s. `SceneKind::static_terrain` may retain older
DEM geometry within the same frozen mission/provider/environment epoch; the
original geometry time is never refreshed by a cache read. Both require a
separate original `lease_time` for current provider availability AND
illumination-specific visibility, not future and age<=0.05s. Changed provider/map
identity must change environment epoch or withdraw availability. Per-pulse
`SceneRecord` and image `SceneSummary` preserve original geometry/lease times.
The adapter owns stable phase and
motion/destruction semantics; an incompatible environment epoch cancels collection.
No coalition, object/track identity, target permission or direct pixel truth enters
this API. Inputs are copied into the fixed pending slot before return.

For each eligible pulse and frequency the core forms complex frequency history
`sum a * exp(-j*4*pi*f*(Ractual-Rreference)/c)`. Double-precision range profiles
use the existing zero-padded inverse-transform/shift convention, normalized by
frequency count. Reconstruction uses estimated per-pulse navigation, never the
known scatterer coordinates. Target coordinates enter only the forward echo
equation. Image pixels come only from range-profile backprojection.

## Bounds and processing

Fixed capacity:512 pulses,256 frequencies,1024 range bins,256 scatterers/pulse,
8 pending grants,256x256 image pixels. FFT bins are powers of two and at least
twice the frequency count. Numeric software domains include1MHz..100GHz sampled
frequencies,1Hz..1GHz frequency spacing,1micrometre..10km grid-vector lengths,
and1m..30000km reference range; these are finite arithmetic bounds, not aircraft
waveform or resolution claims. The owner is allocated/initialized outside callbacks;
recurring work allocates nothing. `step(context,budget)` requires current explicit
power/navigation/epoch/clock evidence before every batch and caps work at4096 units: one echo
term, seed/reorder/transform/profile entry, pixel contribution or normalization
per unit. Queue admission copies at most256 validated scatterers. No unbounded
drain, wait, file I/O, shader compilation or GPU readback occurs in the core.
Queue-full returns backpressure and consumes neither grant identity nor RF credit.
All used raw/derived numerics are finite and explicitly bounded; out-of-gate
returns or image geometry are rejected rather than wrapped into range aliases.

`seal()` succeeds only after the configured pulse count has been admitted.
Only after every pulse and every final pixel normalization completes is a new
image published. Progress counters describe work, not resolution or track truth.

## Completed image and integration seam

Two owned complex image slots separate work from the last complete image. A
completed slot is immutable until retired by the next completed publication;
begin/cancel/power loss never overwrite the active complete slot. Its original
epoch/grid/waveform and first/last observation times remain attached. A const
view is borrowed only until the next completed publication or owner destruction;
the integrating owner must serialize/pin transfer before reuse. Both VR eyes
consume one published identity, never independently reconstruct. Retained image
presence is not current healthy sensing, target authority or current RF consent.

GPU integration can consume completed per-pulse profiles plus the same frozen
metadata and reuse the existing HLSL kernel/streaming layout. Host scene capture,
texture allocator/refcount/destructor, permitted render phase/state restoration,
actual device identity and full-footprint budgets remain separate qualification
requirements. This standalone core does not claim operational SAR or aircraft
resolution/calibration.

Primary references: [DLR SAR tutorial, 2013](https://elib.dlr.de/82313/1/SAR-Tutorial-March-2013.pdf)
for coherent phase/range/azimuth fundamentals and [NASA SAR overview](https://science.nasa.gov/mission/nisar/get-to-know-sar/)
for bandwidth and aperture dependence. Exact implementation conventions come from
the already owned research sources above; illustrative test parameters are not
APG77 specifications.
