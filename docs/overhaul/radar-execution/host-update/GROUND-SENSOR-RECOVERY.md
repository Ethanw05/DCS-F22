# Ground sensor current-host candidate

The current sensor still accepts only the previous five-module bundle. The
candidate retains that bundle and admits the exact reviewed current scene bundle
plus GraphicsVista6acb8063/62000. `GroundSensorHostProfile.h` reuses the existing
air scene selector; all30 mixed old/current five-module combinations reject.
There is no per-module version fallback or status override.

`GROUND-SCENE-PROOF.json` records the consumed current interfaces. The current
aircraft/object point/type/dead/position/motion and scene bridges reuse the exact
current air proof. Current terrain callers establish slot13's two12-byte float
vector references, float maximum, output-hit pointer and bool return. Current
WorldGeneral11832c..11835c calls object59 then response6 with float0 and
Vec3f{1,0,0}, matching the sensor's positive-RCS predicate. Query19/24 ownership
already matches the host after20374a8 and remains unchanged. The paired Surface
camera closure positively establishes the existing784-byte camera and its local
clip/cache/resource behavior; this candidate changes no camera layout.

Two guard/diagnostic corrections accompany selection. PE capture now checks
readability, bounded DOS offset, PE signature, AMD64 and PE64 magic before reading
the image identity. Virtual method capture rejects nonexecutable data, guard or
uncommitted pages and slot arithmetic overflow. The actual publisher now reports
unavailable API reasons1/2/3 before a default snapshot reason4; fresh reports keep
reason0. No sensing, motion, terrain tolerance, RF allocation or target policy is
changed, and copying a diagnostic retains the original source time.

`GROUND-API-RESULTS.json` records230 passing candidate checks under MSVC
`/W4 /WX /analyze`, with a12-file dependency closure unchanged before/after.
The unchanged previous-only source has23 expected diagnostic failures. Fixtures
exercise actual Api admission and borrowed motion/terrain/RCS call shapes using
inert owned objects, and actual completed parameter publication for reason,
readiness, source time and even commit. No DCS export is invoked. Modified helper
complexities are at most12; the export conjunction was extracted without changing
its terms.

`NATIVE-GROUND-SENSOR-CURRENT.patch` is unapplied and checks against primary source
SHA845f3ad1d0813435e63586b6b493196c16b74a430ef725d6b0f8b2a245654e2c.
All existing control, sampling, query ownership, filters, geometry, reset and
publication bytes remain unchanged outside the declared diagnostic helper/call.
New tests and `radar_ground_host.cmake` await integrator registration under the
explicit reviewed-source gate; an unregistered test is not a pass.

Root can apply this narrow candidate with the paired current Camera/Video guard
work and matching Lua protocol, rebuild the matched package and verify achieved
ground queries/returns in the later flight. Inert software and static native
interface evidence do not claim actual terrain effects, callback lifetime or
loaded/installed identity. No existing production source, installation, game or
process was modified by this owner.
