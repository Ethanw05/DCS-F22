Latest solver research, simulation and flight-data plan: [GUN_DIRECTOR_REFINEMENT.md](GUN_DIRECTOR_REFINEMENT.md).

Current motion implementation: [GUN_TARGET_MOTION.md](GUN_TARGET_MOTION.md) records the verified native STT identity/motion cache, gun-pose path and installed director.

# F-15 and Hornet gun-sight code map

Updated 25 October 2026. This supersedes the earlier statement that the F-15 investigation stopped at its aircraft DLL. The F-15 class is now located in the restored **core DCS.exe image**. The code below is analysis evidence, not original source or a drop-in implementation for the mod.

The [pipper design and additional HUD receiver trace](GUN_PIPPER_DESIGN.md) records the newer decoded HUD numeric reader/publication infrastructure and the implemented fine-mark/range-arc presentation. The full active Hornet channel remapping remains unresolved.

## Main findings

**F-15:** RTTI identifies `whCWS_F15`, `whHUD_F15` and `whRadar_F15` in the restored executable. `whCWS_F15` virtual slot **99**, at **0x14086C620**, is a strong gun-director candidate: it obtains shell information, constructs motion/load vectors, calls shared `CalculateTOFToAirTarget`, predicts motion with a second-order term and gravity correction, uses `Rotation3::setFromTo`, projects into the ownship basis and produces two limited angular outputs. Class membership and arithmetic are established; the final F-15 HUD consumer remains to be traced before calling its entire presentation path complete.

**Hornet:** the trace reaches target-input preparation, shell selection, launch velocity, range-limit calculations, wind preparation, gun calculations, FEDS, SHOOT-related gating and 21 HUD callbacks. A target-object lookup in the motion-input path reads simulation velocity and load-related quantities. This is more informative than assuming the Hornet derives all motion from noisy exported radar angles.

**Useful algorithm difference:** the F-15-associated `CalculateTOFToAirTarget` samples atmospheric/drag information and uses a bounded iterative calculation with an analytic drag approximation. The Hornet's precise-TOF path repeatedly evaluates a shell trajectory; `updateFM_` evaluates drag against current air-relative speed during stepping. This is a code-based reason to favor a verified trajectory-based solver for our mod. It does not demonstrate a measured accuracy advantage over either aircraft.

## F-15 ownership and calculation

| Location | Role/evidence | Status |
|---|---|---|
| F15CCWS.dll 0x180001020 / 0x180001040 | Requests `class whCWS_F15` through WorldManager | Confirmed factory boundary |
| DCS.exe type descriptor 0x1414DAFA8 | RTTI name `.?AVwhCWS_F15@@` | Confirmed class identity |
| DCS.exe complete-object locator 0x141347BC8 | Connects class RTTI to a zero-offset vtable | Confirmed data relationship |
| DCS.exe vtable 0x141161E28 | 166 consecutive code pointers, 150 unique targets in the extracted run; includes inherited methods | Inventory candidate boundary, not 166 aircraft-specific algorithms |
| DCS.exe 0x14086C620, slot 99 | Motion/TOF/rotation/angular-output director candidate | Body recovered and inspected |
| DCS.exe 0x140826190 | Calls virtual slot 99 with output addresses at object +7872/+7876 | Confirms cached two-angle output path on this object layout |
| DCS.exe 0x1408AAFF0 | F-15-associated caller of slot 99, then compares returned angles and target geometry | Recovered; exact cue interpretation remains under annotation |
| DCS.exe 0x14086D8E0 | Chooses slot-99 calculation or a separate fallback path, then calls an output/display object | Recovered; display-object virtual target still unresolved |
| Weapons.dll 0x1800C68B0 | `CalculateTOFToAirTarget` | Named export and implementation recovered |
| DCS.exe 0x1408A9450 | Aircraft-system update dispatch; includes virtual calls and flight/weapon mode branches | Recovered, mode interpretation incomplete |
| DCS.exe 0x140866720 | Shell-based altitude-intersection calculation reached from F-15-associated update methods | Recovered; do not confuse with the air-target director |
| DCS.exe 0x140607D30 / 0x14075F600 / 0x140761DD0 | Core callers of shared `Gun_Aiming_Time` / `Gun_Aiming` / impact routines | Related engine references; F-15 ownership is not established for every caller |

In the slot-99 candidate, a failed TOF calculation falls back to a one-second value. That is an observed branch, **not** a recommendation to copy its fallback into our sight. Failures in our computed director should be exposed through validity/quality and a clear fallback mode.

The same candidate contains a from/to rotation before projecting the target line of sight. This supports the conventional director architecture we want: the pilot puts the resulting pipper on the current target, rather than aiming at an independently drawn future target gate.

## Hornet input and calculation chain

| VA in FA18C analysis image | Role/evidence |
|---|---|
| 0x1803805D0 | Calls input preparation at 0x180381E40 and shell/envelope preparation at 0x180381350 |
| 0x180381E40 | Validity handling; LOS times range; registered-object lookup; velocity and load-derived acceleration vectors; transformed equivalents |
| 0x180381350 | Selects `M61_20_HE` or `M61_20_PGU28`, loads the descriptor, forms launch velocity from shell speed and ownship motion, calculates candidate range limits |
| 0x1803C88F0 → 0x1803E65C0 | Caller/update dispatch that reaches the gun-calculation routine |
| 0x1803E7230 | Main recovered gun-calculation routine, including tracked/no-track branches, FEDS, trajectory/TOF/LCOS calls, maneuver geometry and gun-related output publication |
| 0x1803E4630 | Weather/wind-table update used by the gun path |
| 0x1803E9AD0 | Post-calculation firing/SHOOT-related state gating, including a 0.5-second model-time branch; exact mode semantics still require annotation |
| 0x1803BB7B0 | Angular field-of-view limiting helper used by gun calculations |
| 0x1803BB050 / 0x1803E1210 | Line/distance and angular geometry helpers used in maneuver/miss geometry |
| 0x180387F20 / 0x1803E1110 / 0x180487EF0 | Publish indexed values to display/data channels |

Important motion fields on the inspected object, **for analysis only**:

| Offset | Observed use |
|---|---|
| +26256 / +26288 | LOS-derived, range-scaled vectors in two frames |
| +26384 / +26416 | Velocity-like vector from registered-object lookup, and a transformed equivalent |
| +26552 / +26584 | Load/orientation-derived acceleration-like vector, and a transformed equivalent |
| +26632 | Scalar range-like quantity used throughout this path |
| +16856 | Shell-speed/bore-derived launch velocity with ownship motion added |
| +16592 | Embedded CannonSight object |
| +16552 | Wind-table reference |

The lookup uses an ID-like value at +61104 with `RegisterManager::instance`. Its source, track association and all timing/filtering remain to be annotated. These offsets are not a supported mod API and must not be used as a shortcut without separately validating object identity, lifetime and version.

The gun routine contains `atan(6.096 / range)` in range/envelope-gated geometry. The 6.096 m constant corresponds to 20 feet and agrees with the installed Hornet manual's stated criterion; this is corroboration of one component, not proof that all documented hysteresis/anticipation behavior has been reconstructed.

## Shared projectile and FEDS implementation

| Module / VA | Function / role |
|---|---|
| Weapons 0x1800C6220 | `CalculateAAGun_LCOS` |
| Weapons 0x1800C68B0 | `CalculateTOFToAirTarget`, used by the F-15 slot-99 candidate |
| Weapons 0x1800C9410 | `calculateTOFToAirTargetPrecise`, called from the Hornet gun routine |
| Weapons 0x1800C5EF0 | Precise-TOF residual helper: predicts motion, forms a gravity-corrected launch direction, calls `sightTime`, compares trajectory/target distances |
| Weapons 0x1800C9700 | `loadShell` |
| Weapons 0x1800C9B00 / 0x1800C9BC0 | `sightDist` overloads |
| Weapons 0x1800C9FC0 | `sightTime` |
| Weapons 0x1800CA150 / 0x1800CA200 | `sightVel` overloads |
| Weapons 0x1800CA7E0 | `updateFM_`: air-relative speed, atmosphere, Cx interpolation, descriptor parameters, gravity and time stepping |
| Weapons 0x1800CA6B0 / 0x1800CA6C0 | FEDS forwarding/point advancement |
| CockpitBase 0x180359150 / 0x1803593A0 | GunSight construction/destruction |
| CockpitBase 0x180359790 / 0x180359C40 | GunSight calculation overloads |
| CockpitBase 0x18035B590 / 0x18035B750 | Distance/time funnel trajectory calculations |
| CockpitBase 0x18035CA20 | FEDS launch/history creation |
| CockpitBase 0x18035D410 | FEDS point advancement and expiry |
| CockpitBase 0x18035C270 | FEDS point retrieval |
| CockpitBase 0x180279B90 | Loaded cannon-shell descriptor retrieval for the simple weapon system |
| CockpitBase 0x18027B670 | Current simple-weapon-system gyro/ballistic sight baseline |

`simulate_shot` is also inventoried, but its inspected behavior includes terrain intersection; it must not be substituted blindly for an air-target trajectory primitive. Ground-unit aiming and K14 sight code are present in the broad shared inventory but are not claimed to implement the modern radar director.

## HUD and Lua presentation

The stock Hornet `HUD_AA.lua` creates the funnel, fine pipper/reticle, range/RMAX display, maneuver cues and BATR/FEDS displays. Its callback registration is at 0x1804E4C50. The callbacks are readers/presentation code, not the target intercept solver.

Key callback VAs: reticle position 0x1804DAC90; flash 0x1804DABA0; range 0x1804DAE00; RMAX 0x1804DADE0; 1-g 0x1804DA800; 9-g potential 0x1804DA960; 9-g shift 0x1804DA9A0; BATR 0x1804DAE20; funnel 0x1804DA140; FEDS dot 0x1804D9CC0; SHOOT/IN-LAR 0x1804E2420. The full index lists all 21 registrations.

**A remaining dataflow gap:** the drawing callbacks read indices such as 201/202, while the recovered gun routine publishes other channel/index combinations as well. An additional bridge at 0x180348810 maps values from a virtual getter to indices 201–206, but numeric matches alone do not prove it is the active provider for every Hornet display branch. Producer-to-consumer channel ownership must be resolved before claiming a complete end-to-end trace.

## Where the recovered code is

Browse the function index (private workspace, not distributed). It links pseudocode and disassembly in the private research workspace rather than adding hundreds of raw files to the mod or Desktop DCS MODDING.

The F-15/core analysis database is `fi/work/gunsight-research/code-inventory/f15-core/F15-core-gunsight.i64`. Existing Hornet/shared private databases remain in `fi/work/gunsight-research/`. No game binaries or current mod behavior were changed by this investigation.

## Coverage and remaining work

Inventoried this pass: 220 Hornet functions/candidates, a 13-function state-bridge pass, 125 shared cockpit functions/support candidates, 41 shared Weapons functions and 250 core F-15/engine functions/candidates. Some entries overlap or are inherited/generic utilities; these counts are **not** counts of independently verified gun algorithms.

This is not yet “all code recovered.” Unexpanded direct calls, virtual dispatch, remaining leaf/thunk interpretation, underlying shell/atmosphere data, full F-15 HUD ownership, and Hornet channel routing remain. An additional pass recovered the five slot-99 call candidates and previously missing vtable leaf methods. The initial machine inventories record 302 queued Hornet work items and 87 core work items at the traversal limits; duplicate work items and generic support calls are included. These bounds kept the sweep focused and do not imply that those items are all additional gun functions.

The DCS executable reached its restored original code in offline emulation, and its RTTI/code were captured. **Import reconstruction did not pass validation** (59 missing/changed imports), so the captured image is only for static analysis. Seven initially selected ballistic imports were matched to restored IAT slots through their modeled targets; this is not a claim that the complete image can execute. Flight.dll was restored for analysis but did not contain the sought class name. WorldGeneral unpack attempts stopped at unsupported API calls and supplied no verified rebuilt image.

The next research targets are the F-15 slot-99 HUD consumer, virtual/thunk edges around that director, precise argument/frame definitions, and the Hornet display-channel bridge. Runtime firing tests remain separate from static code recovery.
