# SEN-04 — SAR research and native interface feasibility

28 October 2026. Research baseline: ground installation 8044d59. This work
adds reproducible offline experiments, not a new operational radar mode.

## Decision supported by the evidence

Build an owned complex-return/collection/image-formation pipeline behind
MAP/EXP. Keep GMT detection/tracking and target authority, sharing finite
AESA service. DCS supplies the environment and display integration.
Use range-profile backprojection as the correctness reference; optimize
with local-coordinate GPU processing and investigate digital spotlighting/
factorization for larger areas.

The numerical and GPU portions now have working proofs. Full DCS terrain
collection, output publication and operational performance remain unqualified.
The existing shared DBS renderer is still the installed imagery provider.

## Original phase-history experiment

Run tools/research_sar_point_targets.py with Python 3.12, NumPy and Matplotlib.
It synthesizes complex frequency samples from point-scatterer distances,
range-compresses them, then backprojects using per-pulse platform positions.
It does not draw known targets directly into image pixels.

Illustrative settings are 10 GHz carrier, 150 MHz bandwidth, 250 m aperture,
128 pulse positions and 256 frequency samples. These are research inputs,
not recovered F-22 specifications. The broadside benchmark is not an
assertion that an F-22 forward array can steer 90 degrees.

| Experiment | Observed result |
|---|---|
| Two point targets 6 m apart | Focused separately; center valley 23.17 dB below the weaker peak |
| Reduce aperture to 20 m | Pair merges in cross range |
| Reduce bandwidth to 15 MHz | Ground-range pair merges |
| Leave 20 cm trajectory error uncompensated | Correct compensation recovers 12.92 dB in peak power |
| Symmetric targets left/right of a straight forward-looking flight path | Identical range/phase histories in this single-channel model |

The nominal bandwidth-derived slant-range scale is about 1 m; measured
two-target separation in this experiment is 6 m. Neither number authenticates
APG-77 resolving performance. The forward-looking ambiguity needs antenna/
spatial-channel information or changing geometry; reducing a blur setting
cannot recover information absent from the collection.

Outputs: out/sar-research/point-target-metrics.json and
point-target-proof.png.

## Standalone GPU image formation and texture-copy proof

The separate CMake project at tools/sar-research builds
f22_sar_gpu_probe. It creates its own D3D11 hardware device/context,
uploads range profiles, runs an HLSL backprojector, copies its owned UAV
texture into a display-like texture without UAV binding, and compares a
readback against the double-precision CPU reference.

The shader uses a local image origin and rationalized range difference:

    delta = 2 dot(r,q) + dot(q,q)
    dR = delta / (sqrt(R*R + delta) + R)

CPU double precision supplies the per-pulse reference range and its offset
from the collection reference. This avoids subtracting large FP32 world
ranges inside the shader. All work/storage has explicit bounds.

| RTX 4070 measurement | 193x193 | 512x512 | 512x512 load case |
|---|---:|---:|---:|
| Distinct pulse positions | 128 | 128 | 1,024 |
| Complex signal/error ratio against CPU | 88.22 dB | 86.97 dB | 87.77 dB |
| Warm dispatch/copy/blocking test-readback time | 0.49–0.71 ms | 0.75–1.11 ms | 2.13–2.68 ms |

The first uncached 193x193 observation took 137 ms; later first-dispatch
observations ranged from about 1 to 11 ms. Shader/driver warm-up must be outside the flight
callback budget. These are standalone wall times, not timestamp-query GPU
execution times or DCS frame-time guarantees.

All cases cover a 24 m synthetic patch. A full EXP3 footprint requires wider
unambiguous range, adequate spatial pulse sampling, scene returns and a
larger collection budget; this small benchmark does not qualify that workload.
Production should keep processing and presentation on the GPU, with no
blocking staging readback. The probe readback is validation only.

Build/check: MSVC 19.51 C++20, /W4 /WX /analyze; HLSL cs_5_0 strict mode and
warnings as errors. Both image sizes exceed the experiment's 40 dB complex
accuracy criterion. That criterion is an engineering check, not aircraft data.
Metrics and build log are in out/sar-research.

Generate the larger case with the Python script's --gpu-load-case option.
Run the standalone executable against gpu-input-512-p1024.bin. The additional
pulse positions densely sample the same250m aperture; they are not duplicated
rows and do not claim eight times the aperture or resolving power.

## Hex-Rays and original DCS source findings

New decompilations use the installed DCS binaries, not aircraft radar calls.
Input hashes, target RVAs and decompilations are retained under
out/sar-research/ida. No DCS executable code was patched or executed by
the static analysis. The user's already-open IDA databases were preserved.

| Interface / location | Established finding |
|---|---|
| enlight!AGRadar::draw,0x180003630 | Source, scan, blur and final presentation are distinct stages |
| enlight!AGRadar::getData,0x180004090 | Returns matrix/camera-related data; no complex radar-echo buffer established |
| enlight!AGRadar::blurPass,0x180003360 | Existing DBS is angular image filtering, not a coherent phase-history processor |
| SceneRenderer,0x180045F40 | Updates renderer parameters and queues RadarMainPass |
| SceneRenderer,0x180045460 | Queued pass resolves textures and calls AGRadar::draw |
| dx11backend!copyTexture,0x180013D20 | Matching whole resources use ID3D11DeviceContext::CopyResource; type/format/dimensions are checked |
| dx11backend!getRenderTargetInternal,0x1800162B0 | Named texture lookup returns an intrusive owned reference |
| lua-terrain!GetHeight wrapper,0x180003990 | Uses ITerrain::GetDefaultTerrain and virtual+152 with an output buffer and world coordinate |
| Same height wrapper, checked assembly | Rejects marker -1 at output +56; height is a double at output +16 |
| GetSurfaceHeightWithSeabed,0x1800038C0 | Also reads a float at output +64 |
| GetSurfaceType,0x180001C90 | Reads surface-category bits and surrounds the query with virtual+248/+256 context operations |

The output-buffer size, complete PointOnSurface layout, context-operation
semantics and terrain-query thread ownership still need qualification.
Do not infer the return size from a Hex-Rays stack variable declaration:
unused fields and floating-point arguments were missing from its inferred
prototype; assembly established the consumed height offset.

edterrain4 exports querySurfaceMesh and querySurfaceMeshEx. Their signatures
suggest a useful bulk geometry path, but their actual implementation ABI
is not established. edterrain4 and Inter have no file-backed .text in the
installed packed images. Ordinary UPX 5.2.1 decompression declined the
terrain file. Export names are retained as candidates, not successful
decompilations. The unproductive packed-image analysis was stopped.

The shipped model radar shader at
D:/DCS/Bazar/shaders/model/functions/radar.hlsl uses world geometry,
surface normals and a fixed coefficient with radarValue/radarCornerReflector.
enlight/radar.fx reconstructs geometry from depth and applies antenna,
shadow, compensation, blur and presentation operations. This supports a
potential radiance/depth environment-input route. It does not supply verified
raw complex returns or physically accurate electromagnetic material data.

## Integration work required before enabling SAR

1. Acquire coherent terrain/object/visibility samples in the permitted host
   phase. Validate depth-to-world registration or a bounded terrain-patch
   adapter. Define reflectivity estimates, stable scatterer phases and changes
   caused by destruction/motion without turning scene truth into track reports.
2. Add explicit SAR collection leases alongside GMT search/track and other
   AESA jobs. Only granted illumination contributes pulses. Keep emission,
   aperture geometry, RF time, processing progress and display refresh distinct.
   Existing pointed GMT jobs must not be counted as SAR search completion.
3. Publish a completed image into an owned texture with matched generation,
   dimensions/format and lifetime. The current parameter callback precedes
   RadarMainPass; writing there can be overwritten. Qualify a separate texture
   or render-graph publication point and restore any borrowed context state.
4. Exercise collection interruption, navigation/motion errors, forward-looking
   ambiguity, paused/rewound clocks, target handoff, terrain masking and
   full-footprint performance in DCS. Inspect image quality and frame times.

## Sources selected from the supplied catalog

The user supplied [awesome-sar](https://github.com/RadarCODE/awesome-sar).
Most listed InSAR/map-processing tools operate on existing observations.
These upstream projects are more directly useful to image-formation research:

| Reference | Specific use / checked revision |
|---|---|
| [RITSAR](https://github.com/dm6718/RITSAR) | Point phase histories, backprojection, digital spotlighting and factorization; 0e36d2ed; MIT |
| [gotcha-back](https://github.com/tbensonatl/gotcha-back) | CPU/GPU accuracy comparison, local precision concerns and range-profile interpolation; 06da38ad; BSD3 |
| [sar-sim](https://github.com/IMS-AS-LUH/sar-sim) | FMCW signal simulation followed by range and azimuth compression; 98781db5; reference only |
| [RaySAR](https://github.com/StefanJAuer/RaySAR) | Geometry, multiple reflections and 3D object scattering; 5aeda313; reference only |
| [NGA sarpy](https://github.com/ngageoint/sarpy) | Complex-data formats and future external-data validation |

The prototypes are original code. No upstream package was installed into the
mod or copied into its runtime. Pinned metadata and the inspected reference
files remain in out/sar-research/upstream.

General SAR principles:
[Sandia's SAR explanation](https://www.sandia.gov/radar/pathfinder-radar-isr-and-synthetic-aperture-radar-sar-systems/what-is-sar/),
[NASA image-formation overview](https://science.nasa.gov/mission/nisar/get-to-know-sar/).
Context ownership:
[Microsoft D3D11 threading contract](https://learn.microsoft.com/en-us/windows/win32/direct3d11/overviews-direct3d-11-render-multi-thread-intro).
