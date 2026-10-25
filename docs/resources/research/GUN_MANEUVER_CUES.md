# Gun maneuver references — 25 October 2026

The central computed pipper remains the firing solution. The new surrounding marks show hypothetical changes in the target's maneuver; they are not extra aiming points to align with each other.

## Sources and what was actually checked

- Installed Hornet Lua: `D:/DCS/Mods/aircraft/FA-18C/Cockpit/Scripts/Multipurpose_Display_Group/HUD_AVQ32/indicator/Pages/HUD_AA.lua`, lines 173–191. Separate 1G reference, long maneuver-potential arms, relative 9G displacement and short arms; primary reticle is separate.
- Installed Hornet Early Access Guide, pages 267–268: FORESIGHT indicates in-plane and out-of-plane target maneuver potential. BATR represents projectile-at-target-range feedback.
- Private IDA analysis: `fi/work/gunsight-research/FA18C-firecontrol.i64`; focused outputs under `fi/work/gunsight-research/maneuver-cues/`. Main gun function 0x1803E7230; callbacks 0x1804DA800, 0x1804DA960, 0x1804DA9A0, 0x1804DAA90. Scalar publisher 0x180387EC0 exposes 215–221 for position/rotation, wing lengths, separation and visibility. The full routing from these fields to callback reader indices 207–212 has not been proven.
- Native constants: 0x1806C6DF8 = 0.00034 radians per display unit; 0x1806CC040 = 2941.176470588235 reciprocal; 0x1806C6E68 = 0.4 smoothing interval. Eight-unit ticks are 2.72 mrad; native wing clearance works out to approximately 9.86 mrad. The native primary solution and hypothetical target maneuver projections are distinct.
- [Official F-16C Early Access Guide, updated 16 August 2026](https://www.digitalcombatsimulator.com/upload/iblock/e78/33zl8132hi71d3tv0194vvkzpzl3mrr6/DCS%20F-16C%20Early%20Access%20Guide%20EN.pdf), pages 561–564. Page 564 describes the T-symbol's 1G/nonmaneuvering and 9G references, lateral potential lines that shorten as bullet flight time decreases, the separate Level 5 computed pipper, target aspect caret and BATR feedback. Pages 561–562 describe dogfight declutter and EEGS levels. Local downloaded copy and rendered relevant pages are in the focused research folder.
- The full F-16 cockpit module is not installed. `CoreMods/aircraft/F-16C` is the AI aircraft. No F-16 cockpit DLL or HUD Lua was available to inspect; F-16 findings are manual-based.

## Implemented behavior

- Keep the 3 mrad fine cross, its existing range arc and the primary rotating-velocity/tangential-acceleration intercept solver. Add open locating corners 10 mrad from the centre; the precision point is unchanged.
- Four secondary native solves use the same shell trajectory, muzzle position, wind, own motion and flight-time solver as the primary solution. They represent 1G, 9G and two lateral maneuver cases. Updating these references at 10 Hz limits extra work; their relative positions follow the current primary aim between updates.
- Gravity is separated from target proper normal load. A level 1G reference has zero net vertical acceleration, and a level 9G reference has approximately 8G upward net acceleration. Lateral references share a 9G normal-load budget: sqrt(9^2 - 1^2) G laterally plus 1G in the baseline plane. These are explicit hypothetical cases, not measured enemy limits.
- Direction of the reference maneuver plane comes from estimated target motion. References disappear when that plane is undefined, a hypothetical solve fails, data exceeds 0.2 seconds, identity changes, or the primary solution is invalid. No alternate gun solution or fallback pipper is introduced.
- Render 1G and 9G REF identification ticks only when separated at least 12 mrad from the primary centre. Lateral arms leave a 10 mrad central gap and grow only to their computed span, quantized in 1.5 mrad segments up to the display's 94 mrad segment extent. HUD clipping still applies. No invented minimum arm length.
- HUD lines and own stroke font share RGB (0,218,20), opaque alpha and nonadditive blending. This is intended to preserve a darker green against bright scenery. In-game and VR appearance remains unverified.
- Added telemetry: native cue validity, display visibility, timestamp, track ID, observed load estimate, computation cost in milliseconds and lateral spans. This permits checking additional solver cost during the next flight.

## Deliberate limits and validation

A 9G reference is not a claim that every target can sustain 9G. These are maneuver-potential references, not a probability envelope, confidence interval or guaranteed hit region. The central pipper remains the command for the currently estimated target motion. This change does not improve radar measurements or remove long-range prediction error.

F-16 aspect/range presentation and dogfight declutter are further design references, not new features in this change. BATR was not implemented: it needs actual shot history and projectile timing, and cannot honestly be recreated from the instantaneous pipper alone.

Passed: native gun intercept, native STT motion, native adapter, target-motion derivative, maneuver load-budget/intercept and seeker-contract tests; Lua cue projection and visibility, asynchronous handoff, recorded pursuit replay (57/60 accepted after warm-up), director, body frames, no-fallback, optical alignment, reticle, HUD resources, startup and Lua parse validation. Full DLL build passed. Actual cockpit appearance, maneuver legibility and solver frame-time cost require the next DCS flight; simulation tests are not a hit-rate measurement.
