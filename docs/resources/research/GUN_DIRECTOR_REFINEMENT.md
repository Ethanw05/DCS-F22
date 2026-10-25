# Computed gun director refinement and flight test — 25 October 2026

Current status: built and installed in the main mod and Saved Games copy. **No gyro/manual fallback exists in our aiming code.** A missing or rejected computed solution hides the pipper. The native weapon service still owns firing, inventory and loaded-shell data. No-lock funnel and secondary maneuver cues remain unfinished.

## What the aircraft-code review established

- F-15 core director `0x14086C620`: constructs a fixed-world-acceleration target prediction using position + velocity*time + acceleration*time²/2; uses the shared TOF calculation and a from-to rotation to map aim correction onto the current target LOS. The decoded path substitutes one second if its TOF calculation fails. Our implementation does not reproduce that substitution.
- Hornet target input `0x180381E40`: obtains the tracked simulation object's velocity and load-derived acceleration. Gun routine `0x1803E7230` and shared precise residual helper `0x1800C5EF0` use the same polynomial target-motion assumption with shared shell integration and a TOF root search.
- These are specific decoded DCS code paths, not claims that every mode, real aircraft implementation or display route has been fully reconstructed. Our comparisons do not reproduce complete Hornet/F-15 avionics.

## Corrections and new model

1. Removed the native gyro/manual aiming selection and unused gravity/LOS-rate lead computation from Radar_Data_Bridge. Weapon_System now consumes only the computed director. Native sight-range/span writes and `MAN RNG`/`RDR GYRO` labels are gone. Loss of a valid solution gives no pipper; `GUN NO TRACK` or `GUN NO SOLUTION` describes the missing input/solution.
2. Removed the previous 20 Hz solve hold. The solver now samples the actual world muzzle and bore each advancing cockpit update, nominally 50 Hz. Holding a world-space bore while ownship turned could otherwise add substantial angular error. The last numerical solution initializes the next root search only for the same target within 0.15 seconds; it is never drawn as an alternate solution when a new solve fails.
3. Corrected measurement-age handling. Previously the target position was advanced while its velocity remained at measurement time. The native adapter now predicts from the original timestamp through **measurement age plus projectile flight time**, consistently advancing the full motion state.
4. Added a single 3D rotating-velocity model with tangential acceleration. It estimates turn-plane angular velocity from consecutive native velocity vectors, smooths that angular velocity with a 0.12 s time constant, and reconstructs normal acceleration against the **current** velocity. This avoids the phase lag caused by smoothing a rotating world-space acceleration vector. Tangential speed change is filtered separately with the same time constant.
5. The target predictor integrates velocity rotating at a constant angular rate while speed changes linearly. Its zero-turn limit is straight-line acceleration. Small-angle series keep this continuous near zero rate. A midpoint numerical integration independently verifies its formula over turn rate, speed, tangential acceleration and horizon.
6. The projectile still uses the loaded native shell and `CannonSight::sightTime` for drag/gravity/altitude with the current EFM wind. The inverse solver now requires each Newton step to reduce endpoint error, reducing overshoot. It continues to use actual muzzle origin/bore and ownship inherited velocity.

`Gun_Motion.lua`, `GunTargetMotion.h` and `GunIntercept.h` implement the estimator, predictor and root solve separately. Comparison predictors exist only in offline simulation, not as runtime fallbacks.

## Synthetic results

The repeatable runner uses the actual Lua estimator and C++ inverse solver over **2,187 encounters**. Projectile drag, measurement noise and future control changes are explicit synthetic assumptions. This is not DCS flight validation.

| Scenario | Previous implementation mean error | New director mean error |
|---|---:|---:|
| Sustained turns, including assumed noise | 4.932 m | 1.493 m |
| Sustained turns, noise-free | 4.467 m | 0.034 m |
| Straight flight, including assumed noise | 1.487 m | 1.597 m |
| Unannounced rollout/reversal after firing | 10.568 m | 11.374 m |

The turn improvement is real within this simulation, but it is not universal: straight noisy flight is slightly worse than the old time-inconsistent implementation, and unexpected future maneuver changes still cause large errors. Against the consistently time-aligned fixed-acceleration comparison, straight-flight means are effectively equal (1.597 m each); sustained-turn means improve from 4.061 m to 1.493 m. No predictor was supplied future pilot commands. Those limitations remain visible in the report.

Full scenarios, P90/worst errors, assumptions and limitations: `fi/outputs/gunsight-review/simulation/Simulation-results.md`. Repeat with the validation Python environment:

`python tools/simulate_gun_director.py --output <report-directory>`

The runner asserts the noise-free sustained-turn cases stay below 0.3 m in this synthetic numerical model. This threshold does not represent real hit accuracy.

## Real dogfight data

Logging is enabled directly in both mod copies via Radar_Config; no separate package is required. Existing bounded `F22_RADAR_TEST` records now add solve time/identity, target input motion, computed future position, actual world muzzle/bore, current-bore ideal ballistic endpoint at computed TOF, trigger request and native ammunition count.

Fly normal time, keep a target tracked beyond bullet flight time, and include steady pursuit, sustained turns, reversals and short bursts around 500–1500 m. Try a lock loss and target change as well. No need to aim perfectly for predictor scoring: later target positions can assess prediction error independently of pilot aiming.

`tools/analyze_gun_flight.py <dcs.log> --output <report.md>` compares the computed target prediction against a later interpolated position of the same target. It also compares a fixed-acceleration prediction at the same horizon and the ideal native ballistic endpoint along the actual bore. The latter includes pilot aiming error and is **not an observed bullet track or hit event**. Trigger request is not proof that a round fired. Long gaps, missing future data and identity changes are excluded. Recording actual individual rounds/impacts remains a separate task.

Default log: `%USERPROFILE%/Saved Games/DCS/Logs/dcs.log`.

## Validation and installation

Passed C++ intercept, native STT decoder, native gun-adapter, rotating-target predictor and existing seeker contract tests. Passed Lua director identity/age/attitude/current-update tests, explicit no-fallback behavior, real-log scorer fixtures, telemetry bounds, radar bridge, cockpit construction/startup, optical alignment and Lua syntax checks. Required native DLL profiles/exports remain unchanged from the previous audit. Native API execution and firing accuracy still require DCS testing.

DCS was closed before replacing its loaded DLL. The installed DLL hash matches the rebuilt main mod binary. Lua changes were merged into the installed files while preserving unrelated HUD/target-designator work. Backup: `fi/work/gunsight-v2/installed-before/20261025-024757`.

Remaining limits: the target's future controls are unknown; constant turn-plane/rate and linear speed are assumptions; wind uses its current vector; gun-launch/display delay, complete eye/head parallax, dispersion and exact round histories remain uncalibrated. Matching computed pipper to real bursts is the next acceptance check, not a completed result.
