Current implementation: [GUN_DIRECTOR_REFINEMENT.md](GUN_DIRECTOR_REFINEMENT.md). Computed aiming only; gyro/manual fallback removed.

Current motion implementation: see [GUN_TARGET_MOTION.md](GUN_TARGET_MOTION.md). The native lock-associated velocity/acceleration director is now implemented and installed; live firing validation remains pending.

Current alignment correction: see [GUN_PIPPER_ALIGNMENT.md](GUN_PIPPER_ALIGNMENT.md). The gun reference now follows the collimator rather than the decorative W.

# F-22 pipper design and Hornet display trace

25 October 2026. Conventional pipper-on-current-target interface. No separate aiming gate. This is an original DCS mod design, not a claim about classified F-22 avionics or superior radar accuracy.

## Implemented presentation

The main DCS-F22 mod now has an original `HUD/gun_reticle.lua` renderer:

- 3 mrad fine central cross, with a 0.75 mrad stroke, centered on the computed motion director.
- Four small fixed index marks at an 8 mrad radius. The previous approximately 40 mrad decorative ring and large broken cross are replaced.
- A measured-range arc, clockwise from twelve o'clock, full scale **2,000 m**. It saturates above that distance and is hidden without a valid radar range.
- Gun-mode range shown in meters rather than tenths of a nautical mile.
- Label `TRACK  ARC 2KM` identifies the valid computed director. The arc is a range scale, not RMAX, dispersion, accuracy or firing consent.

The parent sight draws only a valid computed director; power and GUN-mode gates remain. The renderer adds no lead offset, sign flip or smoothing. This presentation change does **not** improve the ballistic calculation by itself. Its readability and angular size still need a normal-flight/VR check.

## Mode design and remaining presentation work

| Condition | Primary sight | Secondary information |
|---|---|---|
| No usable radar track | Hornet-style trajectory funnel, with selectable assumed target span | Explicit manual-ranging state; no radar-quality firing cue |
| Valid track and converged ballistic intercept | Same fine center pipper, flown onto the current target | Range arc and compact actual computed TOF; small track-quality indication |
| Brief loss/interruption | Clearly degraded, age-limited coast cue if enabled | No full-quality firing indication; expire to the manual presentation |
| Excessively old/noisy data or no converged intercept | Hide the computed director and show `GUN NO SOLUTION` | Never smooth a stale track into a convincing solution |

The no-lock funnel remains **specified, not implemented**. Computed TOF is now logged by the motion director; a numeric HUD TOF readout and secondary maneuver cues remain unimplemented.

### Aim computation

Use one timestamped scene containing target LOS/range, target motion, ownship pose and velocity, gun origin/bore, atmosphere/wind, and the loaded shell descriptor. Transform to a consistent inertial frame, compensate measurement age once, then solve projectile arrival against predicted target motion.

Default to a constant-velocity target model until enough observations support a bounded acceleration estimate. Acceleration should aid a sustained turn, not amplify noise or survive a target switch. Measure and account for display/processing and gun-launch delay. Do not mix frozen active-pause position with an advancing flight velocity.

Project the required gun-direction error relative to the current target LOS, using the same optical frame for pipper and target brackets. At the solved aim, the center mark overlays the visible target now. Do not draw the required launch direction as though it were the target's predicted future location.

### Maneuver aid

Keep it secondary: short, open brackets or a short whisker that explains the direction/extent of an explicitly modeled maneuver assumption. Their geometry must come from alternative target-motion solutions. Do not display arbitrary 1-g/9-g spans or a probabilistic confidence ring without the necessary model and validation. Hide this aid when it would conceal the target or the solution quality is poor.

### Firing and post-fire cues

A firing-quality indication requires a converged solution, fresh track, validated envelope and actual weapon interlocks. Use hysteresis only after selecting and validating meaningful miss-distance criteria for our shell/encounters. The Hornet's documented thresholds are references, not F-22 specifications.

BATR-style feedback must propagate launch-time state/history. It must not follow the current pipper as though old rounds changed trajectory with the aircraft. Training/hypothetical rounds must remain distinguishable from actual firing.

## Additional Hornet tracing

The trace now adds these concrete links to the prior code map:

- `HUD_AA_GunReticlePos` at 0x1804DAC90 reads numeric indices **201 and 202** through a provider virtual method at vtable offset 120.
- RTTI locates the `avHUD_AVQ32_F18` root vtable at 0x180633678. Its slot 15, 0x180463DE0, is the leaf numeric reader `return *(double *)(self + 9104 + index*8)`. It was missing ordinary function analysis and has now been decoded/decompiled.
- The reticle range and RMAX callbacks call 0x1804E7D60 / 0x1804E7B60 with indices **204/205** and **204/206** respectively. BATR reads its own **113/114/115** visibility/position fields. These are separate presentation values, not one combined sight variable.
- The gun-calculation routine publishes through helpers such as 0x180387EC0. Disassembly confirms the scalar argument is in XMM2; earlier decompiler output incorrectly omitted it in some calls. The scalar helper type was corrected in the private analysis database.
- Publication helper 0x180487EF0 writes a channel, index and scalar, then dispatches through 0x1804871B0. Receiver 0x180487E80 writes the scalar/validity into an indexed receiver record.
- Routing descriptor constructor 0x180465FD0 stores source reference, source index, destination reference and destination index. Registration code at 0x1804665F0 includes non-identity mappings, e.g. 215 to 207. That confirms indices are remapped in this infrastructure, but **does not by itself establish the active 215-to-201 reticle route**.

The exact active provider wiring and remapping between the gun computer and final HUD array remain unresolved. Numeric index matches in unrelated channels are insufficient. The shared scalar publication/receiver path and final HUD read are now decoded, but this is not yet a complete end-to-end proof for every Hornet gun symbol.

Additional pseudocode and assembly remain in `fi/work/gunsight-research/gun-channels/`. The earlier [code map](GUN_SIGHT_CODE_MAP.md) and function index (private workspace, not distributed) cover the wider F-15/Hornet/shared solver investigation.

## Verification and next acceptance checks

Automated Lua 5.1 checks passed for the 3 mrad mark, unchanged aim center, range-validity gate, monotonic/bounded arc and saturation. Existing cockpit construction/startup regression checks and modified-Lua syntax checks passed.

Remaining in-game checks: fine-mark legibility and HUD clipping in 2D/VR; arc direction and meter readout at known ranges; disappearance of the arc on lock loss; computed-only aiming and invalidation; no implied shooting solution from the range arc. Solver superiority requires matched normal-flight burst tests at approximately 500–1,500 m, followed by crossing and maneuvering targets.
