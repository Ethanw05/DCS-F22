# Terrain-aware pilot warnings — 25 October 2026

Direct request: roll calls should choose an escape that clears surrounding terrain; improve warning fidelity without requiring exact production F-22 behavior.

## Final source package

Six runtime files, no DLL/device-ID changes:

- `Cockpit/Scripts/Systems/Terrain_Escape.lua` — new advisory predictor.
- `Cockpit/Scripts/Systems/Pilot_Warnings.lua` — existing policy integrated with predictor.
- `Cockpit/Scripts/Systems/Pilot_Warning_System.lua` — genuine sensor inputs, diagnostics and sound integration.
- `Cockpit/Scripts/HUD/pilot_warnings.lua` — existing warning, plus persistent airborne TAWS N/A indication when data fails.
- `Sounds/Effects/Aircrafts/F-22A/Warnings/terrain.wav` and matching sdef — original generated “Terrain. Terrain.”

`tools/generate_pilot_warning_audio.py --only terrain` generated only the new voice; existing warning recordings were not rewritten. Development eSpeak library is not a runtime dependency. Existing registration of PILOT_WARNING_SYSTEM and HUD warning subset remains valid. Source frozen for the ground-runtime owner's coherent copy. **No DCS process, evaluation channel, installed module or DLL was changed by this warning lane during ground ownership.** Ground owner is including the package in its next snapshot; new native acceptance is pending.

## Behavior

1. Predict continuation of the actual ownship flight state, including bank/load-driven curvature, wind, gravity and energy loss. Check terrain along center and ±15m corridor rails.
2. Compare upright pull-up, ±55° climbing turns and ±70° turns. Near inversion also compare the opposite roll route to upright. Roll time, G onset, indicated-airspeed-dependent lift capability, control damage and a sustained climb profile limit the candidates.
3. Select among paths that clear the protected terrain envelope. Hysteresis can retain a previously selected path only while it remains clear; it cannot retain an unsafe side.
4. Roll direction is the initial roll needed to reach the chosen escape bank, not simply the sign of current bank or a fabricated target direction. Once near the selected bank, the recovery call becomes PULL UP. No control commands are dispatched.
5. Test the chosen path with two additional seconds of reaction delay. If that delayed recovery still clears, issue priority2 TERRAIN caution. When the spare margin is exhausted, issue priority3 ROLL LEFT/RIGHT or PULL UP. If none of the sampled maneuvers clears, issue generic PULL UP and mark NO_ESCAPE; do not assert a clear turn exists.
6. Interrupt old spoken roll advice immediately when the selected safe side changes, including a return to a recently spoken direction. Ordinary repeat-rate limiting cannot suppress this urgent change. Brief alert hold never continues commanding a cleared/obsolete roll direction.

Floor crossing/rearm, landing-gear floor inhibition, mute/ACK, actual FCS validity, power/rewind clearing and missile-audio arbitration remain. Urgent recovery is not acknowledgeable and retains priority over missile audio; early terrain caution defers to missile warnings. Missing/invalid terrain or required performance inputs invalidate cached directions immediately; persistent airborne unavailability shows TAWS N/A instead of silently claiming protection.

Captured ILS landing desensitization requires actual NAV source2 and valid LOC/GS both within0.35 normalized deflection, gear down,70–180m/s indicated airspeed, descent1–12m/s, bank<20°, load0.7–1.4g and no more than5m terrain rise along the lookahead. A segment obstruction also defeats that exemption. Gear alone, excessive sink and rising terrain cannot suppress protection. This is a narrow mod approach policy, not complete runway-database TAWS behavior.

## Model and native contracts

| Quantity | Version1 policy / source |
|---|---|
| Position | Actual ownship base getSelfCoordinates north/up/east, meters |
| Velocity/wind | EFM_HUD_VN/VU/VE and WN/WU/WE, world m/s |
| Bank/heading/IAS/load | getRoll, negative getHeading, getIndicatedAirSpeed(m/s), getVerticalAcceleration(g) |
| Continuation | Current measured normal load and estimated current roll rate |
| Recovery horizon |12s; ≤0.15s integration step and ≤35m air/ground travel per step |
| Envelope |30m protected clearance, center/±15m rails |
| Reaction/reserve |0.8s modeled reaction plus2s warning reserve |
| G/roll | Nominal5g cap,2g/s onset,90°/s roll; reduced with IAS; degraded-control cap1.5g/30°/s |
| Low-speed estimate | n≤(IAS/80m/s)^2; a declared conservative mod assumption |
| Climb/energy |35° sustained climb profile; gravity and extra induced-drag term; no assumed afterburner acceleration |
| Update budget |5Hz nominal, early refresh on significant bank/IAS/load changes or discontinuity;12,000 total terrain/segment queries maximum per solve |

`terrain.GetHeight(n,e)` samples actual terrain, never mission units. `terrain.isVisible(n1,u1,e1,n2,u2,e2)` checks all three rail segments between integration samples at the protected-clearance height, catching ridges that height-only samples miss. Native six-scalar ABI was previously exercised in `o/work/ap-alt-warnings/dcs.log` under F22_TERRAIN_API_EXTRA: above-surface1000m line returned boolean true; below-sea line returned boolean false. This establishes the call shape/basic semantics, not current recovery-model flight acceptance. A present provider returning nonboolean/error invalidates the prediction. Height-only mode is retained as a separately observable capability if the host has no segment provider; it is not reported as traced coverage.

New F22_TAWS_* numeric readbacks: READY,REASON(1 no terrain,2 flight data,3 query/model failure),THREAT,ESCAPE_VALID,NO_ESCAPE,TIME_TO_IMPACT,BEST_BANK_DEG,MIN_CLEARANCE,QUERIES,PRIORITY,TRACE_ACTIVE,IAS_MPS,LOAD_G,HEADING_RAD,INOPERATIVE. MIN_CLEARANCE is sampled protected-envelope margin, not radar altitude or a certified global minimum. NO_ESCAPE means no modeled candidate clears; it is not proof that every possible maneuver is physically impossible. Constructor/reset initializes all fields before native indicator binding. Bounded F22_TAWS diagnostics log state changes and at most one periodic threat row per2s.

## Verification

- New `test_terrain_escape.py`: identical aircraft state with mirrored valley geometries reverses the roll call; blocked-side paths are rejected, unsafe preference is replaced, corridor/wing clearance matters, no-safe-candidate produces generic PULL UP, low-speed/control damage reduces recovery, caution escalates with recovery reserve, stable low flight/climb stays quiet, vertical dive remains checked, ILS-only flat touchdown exemption is bounded, bad data invalidates immediately, cache/budget/rewind behave correctly. A1mm analytic ridge between height nodes is missed by height-only sampling and caught by the six-scalar segment provider. Nonboolean ray results are rejected.
- New `test_terrain_warning_owner.py`: actual Lua owner invokes real contract-shaped providers, publishes escape/readiness/trace flags, switches right→left→right sounds without old-direction overlap or repeat blocking, preserves urgent ACK/mute sensing and clears on invalid capability/power.
- Existing bank-recovery checks remain at600m, where the modeled recovery actually clears. The400m banked descent now has a separate test requiring generic PULL UP/no modeled clear escape. No old bank-sign assertion was silently removed.
- Existing pilot-warning, RWR audio and optical warning tests pass. Shared suite before final segment refinement:86/86 PASS. Final shared run recorded below.
- Synthetic height-only performance on this host: median1.7–1.8ms/solve at100–200m/s,3.3ms at350,4.7ms at600 and8.0ms at900; sample workload1468–5675 terrain calls. These were offline Lua/analytic terrain measurements **before** early collision exit and native segment checks; they are not DCS CPU profiling. Actual terrain calls/ray cost must be measured in the owned game window.

## Evidence and limits

The public GCAS principle is to compare predicted aircraft trajectories with terrain and evaluate recovery capability; public descriptions of the baseline automatic maneuver use roll-to-upright and nominal5g. This mod adds advisory lateral-corridor comparison, not automatic control or a reproduced operational F-22 algorithm. [NASA GCAS overview](https://www.nasa.gov/aeronautics/resilient-autonomy-ends-autonomy-research-ongoing-suwyc/), [USAF Auto-GCAS illustration](https://www.edwards.af.mil/News/Photos/igphoto/2000095056/). FAA forward-looking terrain avoidance/alert guidance supports flight-path lookahead, nuisance-alert evaluation and warning prioritization; Part23 requirements are context, not F-22 or mod certification. [FAA AC23-18](https://www.faa.gov/documentlibrary/media/advisory_circular/ac_23-18.pdf).

Remaining qualifications: actual IAS/G/heading units and readiness in current DCS, lateral native-terrain escapes, steep/inverted/low-speed aircraft response, delayed-command margin, wind/control degradation, approach nuisance rate and native frame cost. The public point-mass performance model is not the full EFM, does not solve arbitrary obstacle fields, and has finite candidate/corridor/horizon coverage. Scene-object/building/wire coverage from the host visibility provider is unqualified. No airport/runway database, universal visual-approach exemption, automatic recovery, certified TAWS claim or complete transport-aircraft warning-mode suite was added. Earlier installed flat-descent ALTITUDE/PULL UP proof qualifies the prior warning integration, not these new trajectories.


## Final validation/installation checkpoint

Final shared suite **86/86 PASS**, log fi/work/terrain-warning-final-tests.log. Ground runtime owner included the coherent six-file package in owned DCS32532. Their real held coastal-flight readback at model11s: READY1,REASON0,TRACE_ACTIVE1,IAS_MPS123.85485076904,LOAD_G1,HEADING_RAD-4.0913162231445,QUERIES483. This confirms genuine native flight inputs and actual terrain segment-query execution; no warning stimulus/aircraft state was injected for that readback. Evidence: 2026-10-25/os/work/ground-radar/gpu-native.log and DCS log, ground owner thread01a17586-a292-7b90-b998-f04c2f64570d. Our subsequent read-only source/installed byte comparison recorded fi/work/terrain-warning-installed-manifest.json. Native sampling readiness is qualified; lateral advisory flight accuracy and aircraft response calibration remain outstanding until the ground GPU owner releases the controlled runtime.
