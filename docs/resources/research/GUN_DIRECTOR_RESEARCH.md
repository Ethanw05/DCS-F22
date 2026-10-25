# F-22 pipper: F-15/Hornet code findings and achievable design

**25 October update:** [The expanded code map](Gun-sight-code-map.md) now locates the F-15 class and a director candidate in the restored core executable. It supersedes the F-15 factory-only limitation described in this earlier research pass.

Research updated 24 October 2026. This is a design for a DCS mod, not a claim about real F-22 fire-control performance. No live gun-computer behavior was changed by this research.

## Conclusion

We can build a conventional radar-directed pipper with shell-specific ballistics, target-motion prediction, a compact range indication and a trajectory-based no-lock funnel. The largest upgrade is replacing the current range-only connection with a timestamped target-motion solution. A simpler display and better handling of stale tracks are achievable; superior accuracy to DCS's Hornet or Viper is not established.

The interface is **put the pipper on the visible target**. There is no separate aim gate for the pilot to chase. Predicted target motion is an input to the computer, rather than a future-position marker the pilot must interpret.

## Evidence, with limits

Addresses are analysis VAs with base 0x180000000 for the inspected binaries. They are not portable runtime addresses. Hex-Rays argument recovery is incomplete in several routines; named imports and relevant arithmetic/calls were checked against the corresponding disassembly. Do not turn the pseudocode into DLL calls with guessed signatures.

| Source | Finding | What it establishes |
|---|---|---|
| F15CCWS recovered factory, 0x180001020 | Aircraft type 6 requests `class whCWS_F15`. | This entry selects the F-15 combat-system object. It is not the gun solver. |
| F15CCWS factory, 0x180001040 | Passes a class identifier to `WorldManager::create`. | Following the export reaches an engine factory boundary. It does not yield an independent F-15 gun computer. |
| F-15C installed manual, pp. 49–51 | Distinguishes a no-lock static sight from radar-locked GDS. GDS is flown with pipper on target; range is inscribed around the sight, with a time-of-flight dot. | Verified intended F-15 behavior. Its internal prediction algorithm has not been recovered in this audit. |
| Hornet firing-solution routine, 0x1803E7230 | Contains calls to `CalculateAAGun_LCOS`, `CannonSight::calculateTOFToAirTargetPrecise`, `sightDist`, `sightVel`, and separate FEDS handling. | The recovered code extends beyond HUD callbacks into calculation. These calls occur in branches; they are not all a single sequential pipeline. |
| Hornet precise TOF call, 0x1803E86CA | Passes vector inputs, launch/environment data, time and vector outputs. Subsequent arithmetic constructs a vector of the form `p + v*t + 0.5*a*t*t`. | Direct evidence of a second-order prediction term. Exact track-field provenance, filtering and all branch semantics still need tracing. |
| Hornet helper, 0x1803E4630 | Queries `Weather::sAtmosphere` and updates the wind-table object used by the firing-solution path. | Wind/environment data are part of this path. |
| Weapons `CannonSight::sightTime`, 0x1800C9FC0 | Starts from supplied launch velocity/altitude, obtains wind when a table is present, advances the shell model in 0.03-second steps plus a remainder, and reports trajectory position/success. | A shell-model trajectory primitive exists; no need to substitute a guessed constant muzzle-speed-only model. Native ABI/lifetime and game-runtime behavior still require validation. |
| Shared `GunSight::calculate_funnel`, 0x18035B590 and 0x18035B750 | Loads shell launch speed, adds ownship velocity, builds a `CannonSight`, obtains wind context and calls distance/time trajectory routines. | The funnel is tied to projectile motion and aircraft state; a fixed decorative V is not equivalent. |
| Shared `avSimpleWeaponSystem::update_sight`, 0x18027B670 | Uses ownship angular motion/history, loaded shell information and a supplied distance to produce angles. No target-motion lookup was identified in this examined path. | Our existing native sight is a useful gyro/ballistic baseline; passing radar range alone does not supply a radar-directed target solution. |

The F-15 manual is `D:/DCS/Mods/aircraft/F-15C/Doc/F-15C DCS Flaming Cliffs Flight Manual EN.pdf`. The Hornet manual is `D:/DCS/Mods/aircraft/FA-18C/Doc/DCS FA-18C Early Access Guide EN.pdf`, pp. 267–270. These are the installed editions inspected, not unspecified online revisions.

Hornet p. 267 explicitly requires valid range, range-rate and angle tracking, and describes lead based on target motion and encounter geometry. Pages 267–268 also document firing-envelope constraints, maneuver references, and separate bullet-at-target-range feedback. Those aircraft-specific thresholds and the Hornet's gun-bore offset must not be copied as F-22 specifications.

## What our current mod supplies

Main source: the repository root.

- `Weapon_System.lua` supplies STT distance to `set_target_range`, otherwise 1,000 m, and supplies a fixed target span of 15. It reads native pipper azimuth/elevation and publishes them to the HUD. This block does not supply target velocity or acceleration.
- `Radar_Data_Bridge.lua` has an older angular-rate/range-over-muzzle-speed estimate, but the displayed native pipper does not consume its `HUD_GUN_LEAD_*` result. Improving that unused formula would not improve the visible sight.
- The radar backend is `avSimpleRadar`. Its aircraft label and configured range do not establish superior track accuracy or refresh rate.
- The declared muzzle position remains `{0.5, 0.5, 0}`. Native resolved gun origin/bore, loaded round, projectile origin and HUD alignment need calibration before making accuracy claims.

The latest test log contains 3,181 samples over two mission instances and 1,320 locked GUN samples. Those GUN samples are at 7.36–12.88 km, with no gun-mode samples below 2 km. Ownship position/attitude remain fixed while EFM reports 220 m/s forward speed, consistent with active-pause testing. These observations validate logging and changing exports, not normal-flight intercept accuracy. Scheduled 20 Hz samples do not prove the underlying radar refresh rate is 20 Hz.

## Recommended computed pipper

1. **Build one coherent track.** Collect measurement time, STT validity, range/LOS and ownship pose. Transform body LOS into a world-relative position before estimating velocity. Use actual target velocity if a native track interface can be verified; otherwise estimate it from multiple observations. Mark identity as unavailable rather than inventing one. Reject jumps and reset on reacquisition/target discontinuity.
2. **Predict to the current time, then projectile arrival.** Account for measurement age once, estimate velocity and optional bounded acceleration, and give up on a stale or inconsistent track. Acceleration is useful for a sustained turn but can worsen the solution when it is noisy or the target reverses its maneuver. Use a constant-velocity fallback.
3. **Use actual simulated shell ballistics.** Prefer a verified native trajectory adapter with the loaded shell descriptor, ownship launch velocity, atmosphere and wind. Solve launch direction and flight time together against predicted target motion. If native calls cannot be validated, calibrate an original trajectory model against actual DCS rounds before trusting it.
4. **Project a conventional director.** Compute the gun direction that produces the intercept, compare it with the actual gun bore, and project the correction relative to the target's current LOS. At the solved aircraft aim, the pipper overlays the target now. Do not simply draw a dot at the predicted future target position.
5. **Treat delay and geometry as part of the solution.** Measure output-to-display delay and any trigger-to-projectile delay. Verify muzzle offset, bore direction and HUD projection. Do not add an assumed human reaction delay to the pipper itself; any anticipatory firing cue is a separately tested feature.

This yields three clear states:

| State | Display | Computer behavior |
|---|---|---|
| Valid track and converged intercept | Fine central aiming mark, restrained ring, compact range/flight-time information | Uses measured motion and shell trajectory. Show a track-quality warning when appropriate. |
| Brief track interruption | Visibly degraded cue, if a short coast interval is allowed | Age-limited prediction; no full-quality firing indication. Expire rather than smooth indefinitely. |
| No usable track | Hornet-style trajectory funnel with selectable assumed wingspan | Visual ranging only. Requires actual projectile/ownship trajectory data, not an implied radar solution. |

Optional maneuver cues should be secondary to the pipper and calculated from explicit assumptions. A short predicted-motion whisker can help communicate direction, but it must not become the primary aiming instruction. Add post-fire bullet feedback only with launch-time history; otherwise it can misleadingly mirror the current pipper instead of the trajectory of previously fired rounds.

## How good can it be?

The realistic goal is an accurate DCS intercept under the measured track and shell model, with low display delay and a more readable sight. It cannot eliminate shell dispersion, unobserved future maneuvers or bad track data.

Illustrative error sensitivities, not measured DCS sensor specifications:

- At 1,000 m, a 1 mrad alignment error is about 1 m across the target plane.
- A 50 ms uncompensated position age at 200 m/s transverse motion is about 10 m.
- Neglecting a constant 40 m/s² acceleration over a 0.8 s prediction interval creates a 12.8 m position error. Applying that acceleration when the target has stopped turning creates a comparable error in the other direction.

These show why synchronization and motion estimation matter more than extra HUD decoration. Additional smoothing trades jitter against delay; its benefit must be assessed by miss distance, not appearance alone.

## Acceptance criteria before calling it better

Compare our native gyro baseline and the new director in the same recorded scenarios. A Hornet/F-15 comparison also needs matched projectile/geometry assumptions; differing ammunition and mounting can otherwise dominate results.

| Test | Required result |
|---|---|
| 500, 1,000 and 1,500 m, steady targets | Consistent bore/HUD alignment; measured projectile miss rather than just apparent pipper overlap. |
| Opposite crossing directions at the same range | Correct opposite lead, reduced systematic miss compared with the range-only baseline. |
| Ownship pitch/roll changes against a steady world target | No false target acceleration caused by differentiating body-frame angles. |
| Sustained target turn, then maneuver reversal | Benefit of acceleration prediction quantified, with controlled fallback when the model stops fitting. |
| Lock loss, reacquisition and target swap | No stale full-quality director or filter state inherited from the previous target. |
| Recorded firing bursts | Separate deterministic aiming error, dispersion, display delay and projectile launch timing. |
| Normal flight versus active pause | No mixing frozen position with advancing physical velocity; active-pause data excluded from flight-accuracy claims. |

The existing offline Python solver verifies numerical and pipper-overlay properties under an illustrative, uncalibrated drag model. It is not a live native-ballistics implementation or evidence that the mod already meets these acceptance criteria.

## Audit trail

Fresh focused IDA audits are in `fi/work/gunsight-research/f15-sight-audit`, `shared-gun-audit` and `hornet-motion-audit`. The Hornet firing-solution caller and Weapons primitives are in `native-firecontrol`. Scratch evidence remains there instead of adding raw JSON exports to Desktop DCS MODDING.

Remaining research gaps: F-15-specific solver internals; verified native adapter ABI and lifetime; track identity/timestamp/velocity access; target acceleration filtering; actual gun/bore/shell calibration; and normal-flight firing validation.
