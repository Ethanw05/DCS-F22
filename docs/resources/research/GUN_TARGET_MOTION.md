## 27 October 2026: native weapon motion behind the owned AESA

The current gun uses a separate **simulator-assisted weapon source2**, qualified by the selected owned AESA track, unique host binding, active gun resource, fresh observation (0.5s), receiver/emission readiness and matching generation. It does not publish native object motion as measured radar data. Interleaved search remains owned by the AESA scheduler. No avSimpleRadar sensing/cache path is restored.

IDA MCP inspection of the installed Hornet's matched unpacked image confirms `0x180381E40` reads registered-target velocity and derives world acceleration from its orientation and three load methods. Assembly at `0x180382336/357/38D` uses `mulss` after each return: **all three methods return float**, despite two incorrect decompiler double annotations. Registry slot2, registered-object slot7, target velocity slot38, orientation interface+48/slot3 and load slots73–75 are confined to the profiled native adapter. Borrowed target pointers never survive the synchronous read; the binding/generation is checked again afterward. Missing interfaces, absent/dead objects or a changed association withdraw the solution.

Provenance: installed FA18C.dll SHA256 `fa6e89b5e193b7faf11a9de16269bb9314472532cf447254cbf38e1e9b375f31`; validated unpacked image `0bd15061bdb6b126c87b51a7a0baa4d4ad3c9f3da7985a9539ec2b9b58ce7baa`. MCP transcripts and assembly are retained under the gun-track worktree's `out/hornet-binary-check`. The supplied 1-g HUD callback's channel209 is confirmed in assembly as the angle passed to `sub_1804D0310`, a sin/cos matrix rotation. Channels207/208 translate the cue;210/212 set line lengths. This does not establish every intermediate publisher mapping, and our existing cue geometry is retained.

Gun_Director no longer differentiates measured AESA velocity or damps primary native lead. Native P/V/load A is sampled at solve time; measured age still gates association and queue delay remains independently bounded. Source/generation-tagged coherent results drive the existing current-target pipper at120Hz. Existing low/high/left/right maneuver references retain their geometry, update at most40Hz and share8–24Hz adaptive smoothing. These rates are game policies, not F-22 specifications.

The immutable120Hz synthetic comparison (`out/gun-native-proof/comparison.json`, `assessment.json`) gives the old gun clean50Hz native P/V, the previous AESA gun noisy measured P/V, and the new gun current native P/V/load A. At1000m across straight/turn/onset/rollout/reversal white/correlated-noise cases: forecast miss RMS old4.154m, previous12.003m, new3.259m. **Steady straight/turn** pipper error-step RMS old0.000510mrad, previous0.665824mrad, new0.000236mrad; maneuver error-step RMS old0.048641mrad, previous1.802187mrad, new0.033380mrad. Artificial instantaneous onset remains a counterexample to uniform smoothness: new1.133mrad versus old0.854mrad error-step, with immediate native acceleration response versus old283ms in this host. The one-frame deferred-result impulse is retained in the CSV, not pooled into a steady-track claim. This is substituted-host/RK4 evidence, not observed DCS hit accuracy or proof of uniformly better behavior.

Verification:32 native tests pass,18 gun script tests pass, actual DCS Lua parser passes and modified Lua has0 new lint diagnostics/3 retained. Broad script run:176/177 pass; the unrelated trim-recorder test expects54 columns but its unchanged installed-baseline recorder emits74. That same failure reproduces from the installed baseline. Native object calls, audible behavior and flight stability still require DCS execution.

The following25October record describes the superseded mechanical-cache implementation. [GUN_DIRECTOR_REFINEMENT.md](GUN_DIRECTOR_REFINEMENT.md) retains earlier solver development.

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
