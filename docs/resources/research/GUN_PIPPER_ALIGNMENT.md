# Gun pipper optical alignment — 2026-10-25

Status: corrected in the main mod and installed Saved Games copy; geometry regressions pass. Actual DCS burst placement remains unverified.

## Finding and change

The HUD collimator's existing default vector is `{0.55, -0.022, 0}`. Its forward-axis compensation is 0.022 / 0.55 = 0.040 radians under the native focal-plane convention. The pipper previously inherited the decorative `boresight_y * angular_scale = 0.15 * 0.22 = 0.033` radians. That placed a zero-elevation native gun direction 7 mrad below the forward axis in this projection model: about 3.5 metres at 500 metres, or 7 metres at 1000 metres.

`HUD/optics.lua` now supplies the same optical reference to the HUD initializer and the gun symbol. Gun aim no longer inherits the decorative fixed-W offset. Native ballistic angles, weapon firing geometry and the fixed W itself are unchanged. Startup logs include `F22_GUN_ALIGNMENT` with both reference values.

This is an alignment correction, not a new director or a measured accuracy claim.

## Evidence

- DCS primary implementation: `D:/DCS/Mods/aircraft/FA-18C/Cockpit/Scripts/Multipurpose_Display_Group/HUD_AVQ32/indicator/AVQ32_init.lua`, final lines: the comment says the optical centre is four degrees below the FRL and defines vector Y as X times `math.rad(-4)`. This supports the focal-plane depression convention; it does not establish the F-22's real installation angles.
- Offline IDA: CockpitBase `ccIndicator::initialize` at `0x18038CC90` loads the three configured components into offsets 1532, 1536 and 1540. Getter `0x18036B7F0` returns that vector.
- Offline IDA: `avSimpleWeaponSystem::update_sight` at `0x18027B670` requests a native transform through virtual offset 408, uses its basis for muzzle velocity, adds its translation to the computed projectile position, subtracts the aircraft position, and projects the result into the aircraft frame before exporting pipper angles. The matrix request's exact underlying implementation remains unresolved. This is evidence against blindly adding another Lua muzzle offset; it does not prove the configured muzzle matches the visible model.

## Remaining physical checks

`F-22A.lua` still passes `muzzle_pos = {0.5, 0.5, 0}` to the host `M_61` mount. The evaluated mount's connector semantics and actual bullet spawn point have not been captured. Do not relocate the cannon using guessed real-world coordinates. `Views.lua` defines nominal eye position `{6.958, 1.36, 0}`, but the current sight has no verified native eye-parallax correction. This patch does not invent one.

At 500 and 1000 metres, steady flight and short bursts should establish the centre of actual bullet grouping against the pipper, first without turning, then during steady tracking. A nearly constant angular miss suggests optical alignment or bore direction; a miss that varies inversely with range suggests origin/parallax. A miss that grows with turn rate or target motion needs gyro/director analysis. Tracers at arbitrary distances are not equivalent to the bullet position at the selected sight range. Manual range remains 1000 metres without lock. The backend remains a radar-ranged gyro sight rather than a full moving-target solution.

## Verification

The new `test_gun_optical_alignment.py` failed on the original 33 mrad reference and passes with the correction. It checks optical zero, unchanged angular gain and positive/negative native elevation. Existing gun reticle, native HUD units, combiner geometry, startup and Lua syntax checks pass. These tests establish the implementation's geometry, not in-game hit accuracy.
