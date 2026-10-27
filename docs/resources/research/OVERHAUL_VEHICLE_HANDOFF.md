# Vehicle and EFM correction handoff — 2026-10-25

This isolated patch corrects concrete implementation errors and introduces a small estimated physical supply/state model. It does not claim a production F-22A flight-control law, aerodynamic deck, engine deck or equipment calibration. Public evidence establishes the architecture and bounds; the numerical estimates below are deliberately labeled.

## Integration

- Staged tree: `C:\Users\Ethans Desktop 2.0\Desktop\DlcBuilder\vehicle-overhaul-2026-10-25\stage`.
- Source patch: `vehicle.patch`. Exact baseline/final SHA256 values: `vehicle-change-manifest.json`. Full original copied-file manifest: `baseline-manifest.json`.
- `baseline/` preserves the exact pre-edit contents of every modified existing file. New files have a null baseline hash.
- **No shared code was edited.** Integrate the changed sections of RAPTOR.cpp/.h onto the current NAV/altimetry and Sidewinder work. Do not replace those whole files without merging; this stage predates their latest changes.
- No device IDs or creators changed. New brake transports are 10540 (left), 10541 (right), normalized 0..1, added to Inputs.h. Autopilot range 10500..10525 is unchanged.
- Main and battery bus state remain owned by Engine_System.lua after one-time EFM startup seeding. MAIN_POWER/BATTERY_POWER NaN reads now fail closed instead of inventing healthy-engine power.
- MFD_System.lua and Weapon_System.lua were deliberately untouched. Parent must consume the contract below and remove their competing pressure/engine-indication integrators whenever EFM_VEHICLE_VALID is true. Bay/gun-door motion must be scaled by the same EFM_ACTUATOR_AVAILABLE; this physical consumer remains parent/stores integration work.
- Build directory: `C:\Users\Ethans Desktop 2.0\Desktop\DlcBuilder\vehicle-overhaul-2026-10-25\build`. Staged bin/f22.dll was detached from its hardlink before building. **Do not copy the staged DLL to the shared build or live mod**: build the merged current source so latest NAV/radar/Sidewinder changes remain present.

## EFM output contract

EFM_VEHICLE_VALID is reset to 0 on cockpit initialization and becomes 1 after vehicle state is published. All these parameters are read-only to cockpit devices. Publication uses the existing cockpit-update cadence, one EFM step behind current force integration.

| Parameters | Units and meaning |
| --- | --- |
| EFM_HYD_LEFT_PSI, EFM_HYD_RIGHT_PSI | 0..3950 psi estimated supply states |
| EFM_ACTUATOR_AVAILABLE | 0..1, shared redundant hydraulic authority gated by MAIN_POWER or BATTERY_POWER and destruction state |
| EFM_ENGINE_LEFT_TEMP_C, EFM_ENGINE_RIGHT_TEMP_C | Modeled engine temperature, degrees Celsius, with heat-up/cool-down lag |
| EFM_ENGINE_LEFT_OIL_PSI, EFM_ENGINE_RIGHT_OIL_PSI | Modeled oil pressure, psi, with lag |
| EFM_ENGINE_LEFT_NOZZLE_PCT, EFM_ENGINE_RIGHT_NOZZLE_PCT | Achieved nozzle area/opening indication 0..100, shared with draw arguments 90/89; distinct from vector angle |
| EFM_TVC_LEFT_DEG, EFM_TVC_RIGHT_DEG | Achieved individual pitch-vector angles, ±20 degrees |
| EFM_ENGINE_LEFT_THRUST_N, EFM_ENGINE_RIGHT_THRUST_N | Actual current net thrust magnitude, newtons |
| EFM_ENGINE_LEFT_THRUST_PCT, EFM_ENGINE_RIGHT_THRUST_PCT | 100 × actual thrust / current-condition modeled maximum AB thrust, clamped 0..100. This is available-thrust percentage, not throttle/RPM or static rated-thrust percentage. |
| EFM_ENGINE_LEFT_RPM_PCT, EFM_ENGINE_RIGHT_RPM_PCT | Existing contract, now modeled core fraction ×100, with short physical response lag |

Failure inputs: existing L_HYD_FAILURE/R_HYD_FAILURE, 0 healthy and >=0.5 failed. Each nozzle uses its side's supply. Conventional controls use simplified redundant cross-feed (either circuit can power them). Gear, flaps, slats, airbrake, elevons, ailerons, rudder and steering consume physical authority. Brakes have a separate finite pressure reserve and remain mechanical consumers when the flight-control electrical bus is unavailable.

Electrical outputs (same Lua owner, no new device): F22_ELECTRICAL_VALID, F22_BATTERY_SOC (0..1), F22_DC_VOLTS, F22_ESSENTIAL_POWER (boolean). Existing MAIN_POWER remains generator/GPU main bus; BATTERY_POWER is actual switched battery-bus availability. Fault inputs: L_GEN_FAILURE, R_GEN_FAILURE, BATTERY_FAILURE, APU_FAILURE, 0 healthy / >=0.5 failed. APU_POWER/APU_RPM_STATE remain the existing authoritative Lua APU state; EFM APU raw/relative RPM now read it.

## Changes and audit disposition

| Findings | Result |
| --- | --- |
| FCS-01 | Roll/yaw trims now enter the active law, bounded ±0.2 and reset through existing trim reset/AP disconnect behavior. Callback tests verify achieved surfaces change and reset. |
| FCS-02 | Explicit override -1 AUTO, 0 UP, 1 DOWN. Down/Up now reach physical flaps. Toggle selects manual DOWN from AUTO, then returns to AUTO. Existing automatic schedule is retained. |
| FCS-03 | Partial: achieved physical control allocation/slew/authority and visual consistency improved. Existing squared-stick/autotrim/g-feedback/gains and artificial rate moments remain unqualified; no claim of a production law or tested approach/refueling modes. |
| TVC-01 | Fixed: shrinking/zero command envelope retains bounded physical return to neutral, even when the scheduled command slew table is zero. Real supply failure can still hold a physical angle. |
| TVC-02 | Fixed state ownership: independent nozzles drive their own conserved rotated thrust vectors, draw arguments and cockpit parameters. Fixed ±20-degree drawing scale prevents schedule-driven visual teleporting. Other surface drawings read achieved force-producing angles; independent draw-call-rate integration was removed. |
| AER-01 | Lua reference area reconciled to existing EFM 78.06 m². Existing aerodynamic coefficients retained. Full configuration performance qualification remains open. |
| AER-02 | Arbitrary 100-degree AoA drag-direction flip replaced by drag opposing actual body-axis relative wind continuously. Lift/stability approximation remains unqualified; legacy artificial rate moments were preserved rather than blindly retuned. |
| ENG-01 | Raw fan/core exports now return distinct estimated shaft RPM in revolutions/minute, not throttle or fractions. Relative exports return shaft fractions; engine-off throttle cannot create raw RPM. Oil API uses Pa, temperature uses Celsius, fan phase uses radians. |
| ENG-02 | Shared fan/core, temperature/oil and nozzle-area state with finite response; display contract supplied. Cutoff no longer produces idle combustion thrust during rotor rundown. |
| ENG-03 | Partial: smooth airspeed blend of existing static/flight thrust and spool timing removes weight-on-wheels thrust jumps. Full installed-engine calibration and the legacy high-Mach zero table entries remain open. |
| FUEL-01 | External-first feed now draws proportionally from all reported external tanks, preserving symmetry instead of emptying the first map entry. Existing host mass ledger/internal CG proxy retained. Host mass/inertia are now stored, without changing controller gains or double-counting fuel. Detailed internal transfer/feed is still a lumped approximation. |
| FUEL-02 | Refuel capacity matches VLO definition (605 ×3.785 ×0.81482 kg per tank); tank label reflects that definition. Only host-reported installed tank entries accept external fuel, with no guessed zero/one-based pylon IDs. Full tanks return CAN_ACCEPT_FUEL_FROM_TANKER=0; accepted quantities and negative refuel mass deltas conserve. |
| VEH-01 | Partial but useful: finite battery energy/recharge, explicit essential bus and generator/battery/APU faults added to the existing single supply owner. EFM powered physical consumers use that supply. Full production wiring/load priorities remain out of scope. |
| VEH-02 | Physical hydraulic state now affects actual consumers, with pump/failure/leak/accumulator behavior. Parent bay/gun-door and display integration is required to close all consumers. |
| VEH-03 | Open/scoped: no fabricated production ECS/cooling/oxygen model added. Existing oxygen constant remains. SDK ED_FM_FLOW_VELOCITY means maximum engine jet/prop flow speed for fixed wing, **not ventilation**; its constant remains an unresolved jet-flow approximation. |
| GND-01 | Fixed: proportional independent left/right input through Lua and EFM suspension outputs; parking/common brake requests retain override. Nosewheel has no brake output/torque. Keyboard/joystick button releases clear only their own wheel. |
| GND-02 | Steering now consumes physical actuator authority; suspension-derived WOW and current speed schedule retained. Actual tire yaw/deceleration, DCS anti-skid interaction, NWS HOTAS host gating, touchdown and 2-m WOW fallback require flight validation. |

## Declared estimates and limitations

- Fan/core reference anchors are **12,000/16,000 RPM at nominal 100%**, solely estimated unit anchors because public F119 production shaft speeds were not established. Core/fan response constants 0.35/0.8 s. At nominal idle core=.67 and fan=.55; cockpit RPM contract explicitly uses core percent.
- Oil target up to270 psi; thermal envelope at15 C ambient approximately450 C idle /730 C dry /850 C full AB, 4-s heating and22-s cooling. These preserve a useful indication envelope; they are not measured F119 EGT or oil calibration. Nozzle-area slew60 percent/s.
- Hydraulic nominal3950 psi preserves the established mod display scale. Pump builds over20..60% core, 2200 psi/s rise, 500 psi/s shutdown decay, 2500 psi/s explicit failed-circuit dump. Redundant cross-feed is simplified. Brake reserve charges at0.4/s and discharges under moving brake demand; it is not a detailed accumulator volume/thermal model.
- Nozzle physical rate <=40 deg/s, centering floor20 deg/s. The upper bound uses public historical no-load development information; production scheduling is unavailable. Conventional surface rates mostly preserve existing limits; rudder rate80 deg/s is an explicit estimate.
- Battery12 Ah,18 A essential draw,80 A additional APU-start draw,8 A recharge,28 V supplied bus and24..28 V estimated battery terminal curve. These are mod parameters, not production electrical specifications.
- The single VLO tank definition is authoritative for this mod's capacity. A host zero-quantity callback is interpreted as removal, as before; an initially empty tank indistinguishable from removal cannot be inferred without a separate installed-station contract. Burned-empty tracked tanks remain refillable. External refuel fill order is a simplified map order, not a production transfer schedule.
- Existing lift/tail-force/stability tables, high-Mach thrust zeros, g=(ay/9.81)+1 convention, landing brake-assist drag coefficient, tire model, geometry/CG estimates and unsupported full-envelope behavior still require real host/flight validation. This patch is not flight qualification.

## Verification

- MSVC19.51 / Visual Studio18 2026, CMake generated and **full staged Debug EFM DLL built successfully**.
- `ctest --test-dir ../build -C Debug --output-on-failure`: **14/14 pass**. Debug configuration keeps assertions enabled.
- New vehicle numerical tests cover schedule-neutral return, bounded/no-supply nozzle motion, independent hydraulics and reserve depletion/recovery, engine unit/thermal/oil behavior, timestep invariance and thrust blending.
- New compiled EFM callback test loads a tiny **test-only local mock CockpitBase parameter API**, then the staged EFM DLL. It verifies raw/relative RPM, temperature/oil units, differential/common brake exports, functional flap/roll/yaw trim commands and reset, electrical/hydraulic failures/recovery, side-specific nozzle state/drawing, zero-envelope centering, draw-call independence, thrust continuity when only contact changes, cutoff thrust, and refuel acceptance/quantity/mass conservation. The mock is built only under the build directory and is never installed in DCS.
- Existing Python/Lua suite passed64/64 before adding the electrical test. Final full suite passed **65/65**, including the new electrical/brake transport test; exact output is recorded in `python-tests-final.log`.
- `tests/test_vehicle_electrical.py` exercises battery depletion/recharge, timestep consistency, one/both generator failures, battery failure, GPU restoration and proportional independent brake transport through Engine_System.
- No DCS process was started, stopped, installed, restarted or used. No shared binary was overwritten. No commits/publishing.

## Source basis

The reviewed audit contains precise findings and source limitations: [SYSTEMS_ACCURACY_AUDIT_2026-10-25.md](../../audit/README.md#retired-report-a25).

- [MIT F-22 flight-controls lecture](https://ocw.mit.edu/courses/16-687-private-pilot-ground-school-january-iap-2019/resources/special-lecture-f-22-flight-controls/) and [F-22 control-law development paper](https://doi.org/10.2514/6.1996-3379): architecture, transition/allocation validation goals, not gains.
- [Pratt & Whitney F119](https://www.rtx.com/prattwhitney/products/military-engines/f119): twin-spool augmented engine and pitch vectoring up to20 degrees; no installed engine deck.
- [Cobalt CFD study](https://www.cobaltcfd.com/pdfs/AIAA_2013_ratcliff.pdf) and [NASA development study](https://ntrs.nasa.gov/citations/20000115606): configuration/performance validation context; do not supply an absolute production coefficient deck.
- [F-22 fuel-system architecture paper](https://doi.org/10.4271/981544) and [F-22 EMD architecture paper](https://man.fas.org/dod-101/sys/ac/docs/f-22-emd-paper.htm): coupled architecture; no equipment calibration.
- Local `EFM/include/FM/wHumanCustomPhysicsAPI.h`: actual implementation contract for raw/relative RPM, Celsius/Pa/newtons, phase, oxygen, jet flow, brake, mass and refuel callbacks.
