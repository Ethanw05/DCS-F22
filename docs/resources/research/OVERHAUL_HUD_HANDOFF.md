# HUD-01 source correction and optical qualification handoff

## Ready isolated patch

Path: `C:\Users\Ethans Desktop 2.0\Desktop\DlcBuilder\hud-review-2026-10-25`.

- `hud.patch`: bounded source/test diff against captured current shared sources.
- `hud-change-manifest.json`: exact per-file baseline/final SHA256 and staged file paths.
- `baseline/`: exact pre-edit contents for merging concurrent changes.
- `stage/`: independent text sources; assets are hardlinks and were not edited. **Do not build or copy bin/f22.dll from this tree.** No native sources changed.
- `hud-tests-final.log`: full **78/78 Python/Lua checks passed**. The final additional assertions in the gun no-fallback fixture and cross-cue test also passed directly after a comment/assertion-only update.

No shared source, runtime, DLL, font, asset, EDM, device definition, camera position or optical installation constant changed. No DCS instance was used. Merge only the manifest files against latest shared work. Stores worker confirmed HUD/ag.lua was not being edited; AG_Ballistic_Computer.lua and Weapon_System.lua must still be merged by changed section to preserve later stores/native delivery work.

## Evidenced corrections

1. **Two forward origins existed.** layout.boresight_y × layout.angular_scale was0.15 ×0.22 =0.033. optics.frl_elevation was-(-0.022)/0.55 =0.040. Gun/IR/radar/AG used the latter, while FPM/fixed aircraft reference/designated NAV/acquisition roots used the former: a7 mrad plane-coordinate mismatch for the same forward ray. Layout now derives its FRL from the existing optics object. The optical object itself remains unchanged.
2. **Some linear translations consumed angles.** The native element translation gains are physical focal-plane distances, so their inputs must be right/forward and up/forward. Feeding atan angles directly compresses off-axis positions. The radar marker already consumed slopes; FPM, gun, IR, AG pipper/marker and supplementary gun geometry did not all do so. A small pure `HUD_Projection.lua` distinguishes planar angles from spherical polar LOS and supplies render-only slope channels. Existing angular solver/telemetry channels remain unchanged.
3. **A/G fall line and pipper had separate projections.** The line endpoints now use the same ray slopes and optical origin as the pipper. The actual ballistic producer/native-element test proves their endpoint coincidence at finite off-axis direction.
4. **Rear seeker rays have no forward HUD image.** Spherical rays with forward component<=1e-6 are excluded from the forward cue. This prevents tan/angle wrapping from reflecting a rear-hemisphere seeker direction onto the forward display. Native lock, strength, audio and seeker angle contracts are unchanged.

These are installation-consistency and projection corrections, not recalibration to a production F-22 HUD specification.

## Render contract

New `*_X_SLOPE`/`*_Y_SLOPE` values are dimensionless focal-plane slopes. They are derived from the same accepted solver/frame sample as their retained angle channels. The native matrix controller gains remain1000 ×GetScale(); the existing optical forward-distance factor remains0.55 m.

- HUD_FPM_X_SLOPE/Y_SLOPE alongside unchanged HUD_FPM_X_RAD/Y_RAD.
- HUD_AG_TGT_X_SLOPE/Y_SLOPE alongside unchanged HUD_AG_TGT_AZ_RAD/EL_RAD.
- HUD_AG_CCIP_X_SLOPE/Y_SLOPE alongside unchanged HUD_AG_CCIP_AZ_RAD/EL_RAD.
- HUD_IR_SEEKER_X_SLOPE/Y_SLOPE alongside unchanged HUD_IR_SEEKER_AZ/EL. Input is spherical LOS; vertical slope is tan(elevation)/cos(azimuth).
- HUD_GUN_NATIVE_X_SLOPE/Y_SLOPE alongside unchanged HUD_GUN_NATIVE_AZ/EL. Input is independent planar angle pair.
- HUD_FUNNEL_nn_L/R_X_SLOPE/Y_SLOPE alongside unchanged angle-valued HUD_FUNNEL_nn_L/R_X/Y. Interpolation remains in the coherent angular sample stream; only rendered points are projected.
- F22_GUN_MNV_name_X_SLOPE/Y_SLOPE and supplementary `_PLANE_LEN`, `_PLANE_ROT`, `_PLANE_AXIS_ROT` alongside retained angular maneuver data. Arm geometry uses the plane-space endpoints it joins.
- HUD_AG_DIL_X0/Y0/X1/Y1 are explicitly plane slopes; Y includes the existing physical FRL offset because that line root has no separate FRL translation.
- HUD_TD_X/Y, HUD_DT2_X/Y, HUD_WP_X/Y and their locator channels already carry slopes and remain unchanged.

Both principal conventions are tested: planar az=atan(right/forward), planar el=atan(up/forward); spherical az=atan2(right,forward), spherical el=atan2(up,sqrt(forward²+right²)). Confusing the two elevations produces coupled horizontal/vertical error. Naming retained channels explicitly avoids silently redefining existing telemetry.

## Evidence and current acceptance boundary

`tests/test_hud_projection_frame.py` constructs the actual native-style HUD elements, traverses their parent/controller translations and verifies14 roots share the same physical forward ray. It checks finite nonzero planar/polar rays, rear/invalid ray rejection, real FPM and A/G mark producers, a real native-trajectory-contract ballistic activity, and the line/pipper endpoint. `tests/test_gun_no_fallback.py` loads the new pure projection dependency in its existing extracted-owner fixture and confirms the missing-director path still cannot fabricate a sight.

Existing tests remain useful but bounded:

- `test_hud_combiner.py` verifies EDM-derived glass geometry and hypothetical binocular ray intersections. It is **not** a captured DCS stereo render/head-tracking test.
- `test_gun_optical_alignment.py` verifies the assumed native controller/optical-plane convention and scale. It is **not** a measured aircraft/world alignment result.
- `test_hud_adi_agreement.py` verifies shared pitch/bank signs and units versus head-down ADIs. It does **not** qualify horizon/pitch-ladder perspective or physical optical alignment.
- `test_hud_native_units.py` verifies page/controller scale consistency, not real optics.
- Target/AG/gun replay tests qualify their stated source/time/frame behaviors. They do not establish release-impact accuracy, physical boresight alignment or a production HUD field of view.

Remaining material limits:

- `device_init.lua` uses explicit HUD geometry because the shipped EDM lacks the expected HUD connector triplet. The optical constants are mod installation values.
- The nominal software aperture uses the default snap-view translation(0.247411,-0.067882,0) from Views.lua. Target/locator pre-gating assumes that eye. The physical glass mask moves with the cockpit, but pre-gating/locator behavior at other head positions remains unqualified.
- The legacy horizon/pitch ladder uses affine angular pitch translation and roll rotation. Its zero reference now agrees with other cues, but its full perspective behavior is not corrected/qualified here. At nonzero pitch, a linear angle displacement differs from tan(pitch). Do not tune optics or ballistics to conceal that separate display approximation.
- Acquisition boxes and symbol extents remain estimated reference artwork; exact operational F-22A dimensions, optical FOV, eyebox and all tactical symbology are not established by photographs/teaching material.
- Actual DCS matrix semantics, binocular compositor, VR/IPD, head tracking, camera zoom and physical combiner clipping need the runtime matrix below.

## Exact runtime qualification matrix

This is a proposed engineering test matrix, **not manufacturer limits or a claim that these tests have been flown**. Keep the mod/source/DCS build hashes, camera settings and measured results with each run. Record nominal HFOV88.727844° and view pitch-8.414850° from default SnapViews[1][13], then use actual runtime camera values for measurement. Default snap translations are H0=(0.247411,-0.067882,0) in the configured camera translation convention; confirm that convention against actual runtime camera pose before treating it as model-space position.

### 1. Stationary common-ray registration

Use identifiable static world points whose positions and ownship pose are known, including a long-range horizon/reference and a target near5–10 km. Produce the same body ray in a designated NAV marker, radar marker, A/G designation, and a solved gun/CCIP case where meaningful. Do not force native track/ballistics validity merely to make a screenshot. Inspect the fixed forward aircraft reference and ground-velocity FPM in stable level flight separately from weapon bore alignment.

At H0, test body direction pairs(azimuth,elevation): (0,0), (±3°,0), (0,±3°), (±5°,-5°), (0,-10°), and points immediately inside/outside each observed glass boundary. Use polar versus planar elevation correctly when generating the expected ray.

| Run set | Required configurations | What to measure |
| --- | --- | --- |
| 2D zoom | HFOV30°,60°,88.727844°,120°; unchanged head center | Same world/cue angular registration; zoom must change pixels/scale together without changing aim ray. |
| Attitude | Pitch0°,±5°,±10°,±20° × bank0°,±30°,±60° | World horizon, FPM and ladder separately; log affine-ladder discrepancies rather than moving the optical zero to fit them. |
| Direction | Each ray above, plus zero crossing in azimuth/elevation | Correct signs, no polar/planar cross-coupling, smooth cue motion and no reflected rear ray. |
| Field edge | Sweep slowly across left/right/top/bottom boundaries and return | Physical clipping and nominal pre-gates/locators; no cue visible over the frame and no wrong-side locator. Record cases where a moved eye can see a ray that the nominal-eye pre-gate hides. |

### 2. Head translation and rotation

Hold world target/aircraft pose fixed where possible. Repeat central and edge-ray registration at these exact offsets from H0, in metres:

| Pose IDs | Delta from H0 |
| --- | --- |
| H0 | (0,0,0) |
| H1/H2 | (±0.05,0,0) |
| H3/H4 | (0,±0.05,0) |
| H5/H6 | (0,0,±0.05) |
| H7/H8 | (0,0,±0.10) |
| H9–H12 | (0,±0.05,±0.10), all four combinations |

Then test each configured6DOF limit individually: absolute x=-0.05/+0.45, y=-0.30/+0.10 and z=±0.22, using the actual runtime coordinate convention. These are clipping/visibility tests; do not presume the entire configured camera travel is a valid optical eyebox. Repeat H0 and H7/H8 with head yaw±15°, pitch±10° and roll±10°, keeping the same world target in view. A conformal mark that remains visible should stay on the same world ray; disappearance at the glass boundary is distinct from aim drift.

### 3. Stereo/VR

Run an actual VR renderer with both eye images saved independently. At IPD60,64 and70 mm, test H0, H3/H4, H7/H8 and H9–H12. Use the headset's actual per-eye transforms; do not substitute a mono screenshot offset. Test central and boundary rays, then repeat at the configured minimum/nominal/maximum render scale. Check world/cue correspondence per eye, comfortable depth/fusion, correct cockpit-attached glass clipping and no one-eye over-frame cue. Record headset/runtime/IPD and actual camera transforms.

### 4. Weapon and timing separation

- Gun: stationary/moving targets at300,600 and1000 m, level and±30° bank. Record actual native gun transform, aim direction, solved pipper, shell trajectory, target and camera at matching times. A fixed aircraft reference is not automatically the muzzle bore. Separate targeting/ballistic/timing error from screen projection error.
- CCIP/AUTO: representative350/450 kt cases at3000/5000 ft AGL, level and20°/40° dive, bank0°/±30°, bays open/opening. Record accepted solution age, predicted ray, actual release pose/time and observed impact. Optical agreement with the predicted world ray can pass while impact prediction fails; report those separately.
- Repeat central-ray head movement during valid solutions. Never compensate a head-dependent aiming error by retuning a ballistic coefficient, nozzle, camera or pipper offset.

### Measurement and proposed gates

Log source/build hashes, model time, own pose, world reference position/ray, raw angular channels, projected slope channels, selected cue/validity, camera center/orientation/FOV, render size and eye ID. Use angular world/cue registration, not arbitrary pixel distances. When using screenshots, convert measured target/cue pixel positions through the actual camera projection separately and subtract their angles; account for screen resolution/subpixel uncertainty.

Proposed mod engineering gates: nominal central registration error<=1 mrad, additional visible-cue drift from head translation<=1 mrad, and left/right-eye differential error<=1 mrad. Allow<=2 mrad near an observed field edge only with documented raster/measurement uncertainty. These are explicit project targets, not F-22A specifications. Any failed gate remains unqualified. Clipping gates are categorical: cockpit-attached boundary, no reflected/over-frame cue and no stale valid aiming mark after source loss. Independently report ladder perspective deviations rather than granting the whole HUD a pass from cue-center tests.

## Resource basis

- [Current audit HUD-01](stage/docs/resources/research/SYSTEMS_ACCURACY_AUDIT_2026-10-25.md): separate optical acceptance gate and source limitations.
- Local source/SDK/native-element conventions, actual EDM-derived `HUD/glass.lua`, `device_init.lua`, `HUD/optics.lua` and Views.lua: implementation evidence only.
- [MIT F-22 flight-controls lecture](https://ocw.mit.edu/courses/16-687-private-pilot-ground-school-january-iap-2019/resources/special-lecture-f-22-flight-controls/): public display/control context; not production HUD optical calibration.
- [JASDF Aeromedical Laboratory survey](https://www.jstage.jst.go.jp/article/jasdfaml/48/1/48_21/_pdf/-char/ja) and [USAF Flying Safety June2002](https://www.safety.af.mil/Portals/71/documents/Magazines/FSM/fsmjun02.pdf?ver=2017-03-28-101049-403): historical artwork/layout context; not a dimensional/eyebox specification.


## Merged construction-time render schema

The incremental hud-schema-2026-10-25 patch is merged. All47 bound slope/plane channels and full maneuver variants now exist with invalid defaults during device construction, before indicators bind. The producer constructors do not dispatch solver requests, reset existing angular fields or overwrite native solver buffers. Independent test_overhaul_hud_binding.py and stronger test_hud_render_schema_startup.py cover this order. Full incremental-stage suite82/82 passed; final shared snapshot still requires its own complete run.
