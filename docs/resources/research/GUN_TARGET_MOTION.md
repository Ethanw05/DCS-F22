Current implementation: [GUN_DIRECTOR_REFINEMENT.md](GUN_DIRECTOR_REFINEMENT.md) supersedes the original model and fallback described during initial development.

# Gun target-motion director — 25 October 2026

Implemented, built and installed in the main mod and Saved Games copy. Offline numerical/adapter/Lua tests pass. Actual DCS execution, native API calls and burst accuracy remain unverified.

## Investigation result

The DCS Hornet input routine at `0x180381E40` uses its tracked object identifier to look up the registered object, reads world velocity through virtual offset 304, and constructs an acceleration vector from load-related methods and the object basis, including gravity subtraction. The Hornet gun routine at `0x1803E7230` feeds target position, velocity, acceleration and launch/atmospheric inputs to the shared precise TOF calculation.

The same underlying target association already exists in our `avSimpleRadar` backend. Its `update_STT_data` at `0x180344CC0` loads the selected object ID from `this+2024` into EDX before the registry call. It checks detection status, obtains that object's velocity, copies its world pose, differentiates velocity against its previous update time, and stores the current model time. The omitted decompiler EDX argument was checked in assembly. Copy helper `0x1801E8980` copies the 3 basis vectors and translation at matrix indices 0/4/8/12.

The replacement reads this **existing lock cache**, rather than searching all simulation objects or matching unrelated search plots:

| Cache offset | Type | Meaning |
|---|---|---|
| 2024 | uint32 | locked target identity |
| 2028 | float pose, 16 slots | target world transform |
| 2076 / 2080 / 2084 | float | north / altitude / east translation |
| 2092 / 2096 / 2100 | float | world velocity, m/s |
| 2104 / 2108 / 2112 | float | world acceleration, m/s², native velocity difference |
| 2128 | double | model time of cache update |

Acceleration from this backend is differentiated velocity, unlike the Hornet's load-derived acceleration. Nonfinite or implausible acceleration is rejected independently of velocity. The old speculative position-only estimator has been removed because the verified cache supplies better inputs.

## Implemented path

1. `NativeSidewinder.cpp` publishes the read-only lock cache as `F22_STT_*` alongside its existing radar observations. The existing profile/vtable checks remain in place.
2. `Gun_Director.lua` requires powered GUN mode, a confirmed native lock, valid ownship flight data, a cache age no greater than 0.15 seconds and at least 0.1 seconds of advancing updates after an identity change. It checks that cache position agrees with current radar LOS/range within max(20 m, 1% of range). It checks active-pause consistency and estimates rotating-velocity motion. The native adapter accounts for measurement age plus flight time consistently.
3. Command 10851 calls the new `NativeGunSight.cpp` adapter on the cockpit thread. The adapter obtains the registered weapon device, checks its vtable and reads the currently loaded cannon shell descriptor. Muzzle speed comes from that descriptor, not a hardcoded 1030 m/s value.
4. The adapter requests the same native world gun transform as `avSimpleWeaponSystem::update_sight`: weapon context +16 human interface, virtual +320 aircraft interface, then virtual +408 gun pose with arguments 255/0/0. Both the actual muzzle translation and bore direction are used. It rejects invalid geometry rather than assuming the gun fires from the aircraft centre.
5. The original `GunIntercept.h` numerical solver searches launch direction and flight time together. Its target model integrates rotating velocity with tangential acceleration; see the refinement report. Projectile initial velocity includes ownship world velocity. Its trajectory callback calls the shared `CannonSight::sightTime` using the loaded shell, muzzle altitude, current EFM wind and native drag/gravity integration. A constant wind-table adapter supplies the measured wind vector. The generic solver does not substitute an invented drag coefficient.
6. A converged required gun direction is rotated onto the actual current bore, and the same rotation is applied to current target LOS. The result is projected into the current body/HUD frame. At the solved firing attitude, the pipper overlays the **current visible target**; it is not a separate future-position gate. The prior optical-reference correction is retained.
7. Weapon_System consumes only the computed director. There is no gyro or manual-range aiming substitute. The HUD shows `TRACK  ARC 2KM` when valid; without a solution the pipper is hidden. Range arcs are not firing consent.

The computed director currently operates at 100–2000 m, solves on advancing cockpit updates, nominally 50 Hz, allows at most 4 seconds TOF and 12 inverse iterations, and requires less than 0.25 m numerical endpoint residual within its trajectory model. These are mod implementation limits, not F-22 performance claims. A response sequence and clearing validity before every native request prevent stale results or an old EFM from masquerading as a new solution.

## Exact API profile

Verified against both installed bin and bin-mt PE headers:

- CockpitBase.dll timestamp `0x6AC12468`, image size `0x59A000`.
- Weapons.dll timestamp `0x6AC12438`, image size `0x21F000`.

All seven required exports were checked in the installed DLL export tables. Calls use the exported descriptor getter, CannonSight descriptor constructor/destructor, and wind-table overload of `sightTime`. The constructor writes through byte 71; the adapter reserves an aligned 80-byte object. The wind callback follows the native getter's RCX=this, RDX=result, R8=altitude convention. The new adapter catches a native access fault, disables itself for the session and marks the solution invalid. This is a runtime precaution, not evidence that native execution has passed.

## Verification

Passed:

- `gun_intercept`: independent forward checks for crossing, closing, vertical and accelerating targets, including nonlinear drag.
- `native_stt_motion`: field layout, identity, sample age, invalid values and separate acceleration validity.
- `native_gun_adapter`: fake host tests of shell input, world muzzle/bore interface, wind callback, intercept endpoint, response sequence and invalidation.
- Existing native seeker contract test after the shared bridge edit.
- `test_gun_director.py`: current-target pipper semantics, ownship attitude changes, native velocity preservation, identity warmup, stale lock rejection, missing native response and missing clock.
- Gun optical alignment, reticle construction, cockpit startup, telemetry bounds and modified-Lua syntax checks.

The initial rebuilt DLL was copied to installed `bin/f22.dll` and SHA-256 equality checked. Lua edits were merged by subsystem blocks, preserving unrelated concurrent target-designator work. Installed-file syntax was checked. Backup: `fi/work/gun-director-installed-backup/20261025-015506`.

## Flight check and limits

Restart DCS to load the new DLL. At 500–1500 m in normal flight, acquire a steady target in GUN mode. `TRACK` means the new solution is active; `GUN NO SOLUTION` identifies a missing computed solution. Test straight, crossing and steady-turn encounters with short bursts. Check lock loss and reacquisition, target changes, active pause and power loss.

The existing bounded `F22_RADAR_TEST` logger now records target ID/time, position/velocity/acceleration, director selection, solver reason, TOF, numerical residual, actual world muzzle position, muzzle speed and required aim. Reason 0 = solved, 1 = no request, 2 = profile/API unavailable, 3 = weapon device invalid, 4 = shell invalid, 5 = gun geometry invalid, 6 = no intercept convergence, 7 = trapped native fault. If request validity is zero, inspect lock/cache readiness first.

This is a constant-turn/tangential-acceleration prediction, not knowledge of the target's future decisions. Wind is held at its current EFM vector rather than sampled through a full atmospheric profile. Muzzle spin/dispersion, gun-launch delay and complete eye/head parallax are not modeled here. The projection uses the existing aircraft-frame target LOS. Native gun pose, live cache identity and actual burst placement need DCS validation. No claim of superiority to either Hornet or F-16 is supported yet. No-lock funnel, maneuver whiskers, BATR history and a firing-consent criterion remain separate unfinished work.
