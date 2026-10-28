# Offline signature research

These tools produce experimental geometry and perfectly conducting (PEC)
single-reflection estimates from the existing EDM. They do **not** change the
aircraft's signature in DCS. Do not install their output as calibrated F-22 RCS.

Run using Blender's Python with a factory startup; no add-on installation or live
Blender scene is needed. The tested runtime is Blender 5.1.2, NumPy 2.3.4.
`edm-reader.json` pins the external MIT reader dependency to commit
`13cc40b32cd4a39d4337d7beb6e79365a8149770` of
[DCS-EDM-Blender-Importer](https://github.com/devozdemirhasancan/DCS-EDM-Blender-Importer/tree/13cc40b32cd4a39d4337d7beb6e79365a8149770).
Place its `edm/` directory and `LICENSE` in an external reader directory. The
adapter verifies their hashes, rejects parser warnings/recovery and requires EOF.
The third-party parser is not a hardened untrusted-file service; use the known
project asset. Post-parse budgets do not bound its internal allocations.

Example from the repository root, with the three task-specific paths set to
external directories/files:

```powershell
& $blender --background --factory-startup --python-exit-code 1 `
  --python tools/rcs/edm_geometry.py -- `
  --edm Shapes/F-22A.EDM --reader $reader `
  --dependency-manifest tools/rcs/edm-reader.json `
  --arguments $arguments --output $geometryOutput

& $blender --background --factory-startup --python-exit-code 1 `
  --python tests/offline/test_rcs_prebake.py

& $blender --background --factory-startup --python-exit-code 1 `
  --python tools/rcs/bake_pec.py -- `
  --geometry "$geometryOutput/geometry.json" --output $estimateOutput `
  --azimuth-step 30 --elevations -20 0 20 --frequencies-ghz 3 10
```

The argument file is an explicit JSON map, e.g. `{"309":2,"317":2}` requests a
candidate pose with both pylon meshes hidden. This is a modeling input, not an
observation of actual loadout. Unlisted arguments are zero. No attached weapon
meshes are included. Supply separate argument files/output folders for gear,
canopy, refuel-door and other configurations. The generator overrides 600/601/602
to produce eight binary bay combinations; bit 0 is main, bit 1 left, bit 2 right.
It does not yet sample partially open doors.

The F-22 combined render mesh has zero `index_start` values for many parents.
Using those as ordinary face slices loses the bay geometry. This adapter uses
the fourth position-channel float as a rigid-parent selector and rejects faces
that span different parents. The interpretation follows the
[reverse-engineered EDM specification](https://ndevenish.github.io/Blender_ioEDM/EDM_Specification.html).
Transforms retain both base quaternions and use spherical interpolation for
rotation keys. Their order and the visibility endpoints remain candidates until
compared with native DCS poses. In particular, the extracted closed-pose bounds
do not exactly match the EDM's declared root bounds; geometry fidelity is open.

The estimator evaluates coherent surface integrals over illuminated triangular
PEC facets, retaining round-trip phase. A BVH centroid ray approximates each
facet's visibility. It implements the monostatic co-polar PO approximation:
`sigma = 4*pi/lambda^2 * abs(sum(cos(theta)*integral(exp(i*2*k*s.r), dS)))^2`.
The analytic rectangle requirement is from D. Jenn's
[NPS EC4630 notes, pp26–28](https://faculty.nps.edu/jenn/EC4630/TheoremsandConceptsV2.pdf).
The tests also check translation and subdivision invariance, occlusion, parent
selection, quaternion retention, malformed geometry and hierarchy rejection.

This excludes RAM/coatings, radome transmission, polarization conversion,
diffraction, multiple reflections and cavity returns. Centroid shadows can miss
partial occlusion. A coarse angular sweep misses narrow lobes. Geometry, mesh
shadow convergence and aircraft calibration remain unqualified. PEC output is
neither measured F-22 RCS nor an upper/lower bound on it.

The tools perform no simulator callback work. Sweeps cap geometry at two million
vertices/triangles, 512 state/aspect combinations, eight frequencies and 64 million
shadow rays; exceeding a budget fails instead of truncating the result. Outputs
must be new external paths. The original EDM is read only and hash checked.

Multiplayer integration requires an actual per-aircraft signature consumer in
DCS AI and receiving radars. Existing `net_animation` declarations include bay
arguments 600–602, but visual replication does not establish radar replication.
No qualified native setter has been found. No production consumer, global
aircraft-type mutation, invisibility toggle or fabricated engagement is added.
Server/remote aircraft, two independent aircraft, late join, respawn and native
SAM/other-module radar behavior all remain host qualification requirements.
