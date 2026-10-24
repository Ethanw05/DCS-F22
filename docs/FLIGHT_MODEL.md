# Experimental flight-model replacement

Implementation date: 24 October 2026. This replaces the inherited EFM equations and state flow, not just their constants. **It is an engineering approximation with local numerical tests, not a validated reproduction of the production F-22. No DCS runtime flight, Windows DLL load, pilot evaluation or measured performance match has been completed.** Historical audit findings describe the earlier baseline; this document describes the replacement.

## What changed

| System | Replacement behavior | Applicable evidence |
| --- | --- | --- |
| Air data and aerodynamics | Air-relative body velocity; lift/side directions perpendicular to airflow; drag opposing airflow; continuous attached/separated-flow blending; Mach/configuration effects and dimensionless rate damping. | [R27](RESOURCES.md#r27) geometry; [R178](RESOURCES.md#r178) equations. Actual coefficient tables remain unavailable. |
| Engines | Independent run/start/shutdown, fan/core lag, dry power, afterburner, net thrust and fuel flow; pressure/temperature lapse; fuel starvation and engine damage. | [R25](RESOURCES.md#r25), [R81](RESOURCES.md#r81). No installed engine deck recovered. |
| Thrust vectoring | Each achieved nozzle position has travel/rate limits. A common pitch-vector command shares control demand with aerodynamic surfaces. Thrust resolves as `(T cos θ, T sin θ, 0)` with moment `(position − CG) × force`. | [R25](RESOURCES.md#r25), [R65](RESOURCES.md#r65), [R126](RESOURCES.md#r126), [R179](RESOURCES.md#r179). |
| Pitch | Load-factor/rate blend; filtered actual body-normal force; approach/refueling rate mode; smooth configuration transition and control allocation. | [R20](RESOURCES.md#r20), [R65](RESOURCES.md#r65), [R125](RESOURCES.md#r125) support architecture/qualitative behavior, not our gains. |
| Roll/yaw | Stability-axis roll command resolves into body roll/yaw; rate feedback, sideslip feedback, coordination, trim and simultaneous allocation. | [R65](RESOURCES.md#r65), [R126](RESOURCES.md#r126). Numerical response schedule is assumed. |
| Actuators/configuration | Achieved surface positions advance with elapsed time, including at zero airspeed; cruise braking uses wing/rudder surfaces, with wing contribution fading as gear extends. | [R126](RESOURCES.md#r126) historical no-load rates/travel; [R22](RESOURCES.md#r22) braking arrangement. |
| Fuel/mass | Host-provided partial external quantities, proportional external drain, internal reserve, actual accepted refuel amount and explicit mass-event queue. | Checked-in host API declarations; tank geometry and feed order are approximations. |
| Host integration | Shaft RPM versus normalized RPM distinguished; temperature in Celsius; combustion distinct from integrity; contact-based WOW; earth-relative steering speed; independent proportional brakes; bounded, read-only draw callbacks. | [Bundled API](../EFM/include/FM/wHumanCustomPhysicsAPI.h). Current DCS behavior still requires runtime confirmation. |

The old hard changes at 65°/100° alpha, extra throttle factor in vertical thrust, Mach-dependent frozen nozzle rate, fixed-per-callback gear/flap movement and previous-frame thrust mixing are removed. Roll/yaw trim now affect actual commanded moments. Repair and release clear their owned state; damage notifications are not echoed as new structural-damage events. C++ no longer writes the Lua-owned electrical power parameters or clamshell arguments.

## Ownership, units and equations

`EFM/source/FlightModel/` is portable C++17. `RAPTOR.cpp` is the DCS/Windows adapter. DCS owns rigid-body integration, gravity, atmospheric state, aircraft mass/inertia, ground reactions and native weapon dynamics. The core returns aerodynamic/propulsive force and moment; it never advances host aircraft position or adds weight a second time.

SI units and radians are used internally. Body axes are X forward, Y up, Z right; angular components are right roll about X, left yaw about Y, nose-up pitch about Z. Host body wind is subtracted once. Ground speed is taken directly from earth-relative host velocity. `alpha = atan2(-Vy, Vx)` and `beta = asin(Vz / |V|)`.

Dynamic pressure is `q = ρ |V|² / 2`. Lift and side-force basis vectors are orthogonal to flow; drag acts opposite it. Moments include explicit force application points relative to the current host CG. Rotational damping uses `p b/(2V)`, `r b/(2V)` and `q_pitch c/(2V)` with a low-speed numerical floor. The separated-flow surrogate is smooth through the old thresholds, but continuity does not establish accurate post-stall forces or departure/spin behavior.

Each nozzle rotates the **already computed net thrust**. Vectoring reduces forward thrust through the cosine term; it cannot produce a second independent full-thrust vertical force. The allocator requests equal nozzle angles, while achieved positions remain separate. Unequal engines or failed actuators can therefore create real moments through their actual force arms. There is no invented sideways jet force.

The control allocator solves a bounded, regularized, weighted least-squares approximation to the requested three-axis moment using eight aerodynamic surfaces and one common nozzle command. Its local force derivatives come from this surrogate model, not a recovered F-22 effectiveness matrix. Surface rate/travel saturation is physical; the reported allocation residual is diagnostic. There is no claim of production optimal allocation or load protection.

Internal integration uses substeps no longer than 4 ms with host motion held constant within each callback. The returned wrench is the **average over that callback interval**. This preserves total applied impulse across different host callback durations. It does not eliminate the host's integration error or establish convergence for all motion.

## Source and assumption ledger

A source supporting the general architecture does **not** validate the chosen numerical schedule. All unsourced constants below are replaceable model parameters. The two main numerical data locations are [AirframeData.h](../EFM/source/FlightModel/AirframeData.h) and [FlightModel.cpp](../EFM/source/FlightModel/FlightModel.cpp).

| Parameter family | Implemented basis | Evidence level / limits |
| --- | --- | --- |
| Reference geometry | 78.04 m², 13.56 m; chord 5.8 m | Area/span: public geometry R27. Chord: assumed, not measured MAC. Aircraft registration area also corrected from 56.5 to 78.04 m²; AI SFM tables otherwise retained. |
| Thrust anchor | 35,000 lbf per engine converted to N; assumed dry thrust 103 kN | R25 gives a **thrust class**, not an exact installed maximum. No measured dry-thrust value adopted as fact. |
| Thrust deck | Eight-point Mach factors; pressure ratio exponent 0.70, inverse square-root temperature ratio; up to 30% high-alpha inlet reduction | Entire deck/lapse/inlet loss is assumed. No compressor map, inlet recovery, ram drag decomposition, inlet sideslip effects, nozzle pressure-ratio/efficiency map or verified installation losses. |
| Engine transient/display scales | 44 s start, 18 s ignition, normalized idle fan/core 0.67/0.70; 1.6/1.2 s running lags; AB 0.8/0.25 s; idle 6 kN; throttle military detent 0.85 | Simulation assumptions; start timing partly retained from inherited code. Shaft scales 12,000/18,000 RPM, temperature curve 450–900 °C with 4 s lag, core thrust fraction 0.7 and gain are assumed interface/display proxies, not F119 instrumentation data. Ignition inhibited at integrity ≤0.25 is an assumed failure rule. |
| Fuel flow | Assumed SFC `2e−5 + 3e−5 × AB` kg/(N·s), plus pressure-dependent idle flow | No measured F119 fuel-flow deck. Range/endurance cannot yet be claimed. |
| Nozzles | ±20°; 40°/s; common pitch command | Travel R25; historical no-load rate R126. Loaded rates, hydraulic supply, nozzle area control and production command schedule unverified. TVC availability uses assumed EAS/alpha blends, not a hard Mach switch. |
| Other effectors | Tails −25°/+30° at 60°/s; ailerons ±25° and flaperons −20°/+35° at 70°/s; rudders ±30° at 80°/s; LEF 0–35° at 30°/s | R126 historical diagram, explicitly **no-load**. LEF state is a normalized 0–35° command. Rudder cant and actual hinge geometry are simplified into effective forces. |
| Force arms / derivatives | Fixed positions; eight effective area/slopes 27,27,8,8,12,12,15,15 m²/rad | Assumed; engine locations inherited as an unverified starting point. Not derived from detailed surface geometry or wind-tunnel derivatives. |
| Aerodynamic tables | CL slope 3.6→2.4/rad; CD0 0.018→0.038 over Mach 0–2.4; attached/separated blend 15–50° | Assumed surrogate arrays. Separated `CL = 1.30 sin(2α)` and drag/sideforce/rate/static-moment coefficients are also assumed. Mach outside table range clamps to the endpoints. |
| Configuration increments | Induced-drag factor 0.12; ground-effect factor 0.55→1 over half span; gear CD 0.08; brake CD 0.07; installed external station CD 0.008; control-induced CD coefficient 0.006 | Assumed; generic configuration increments supplement explicit surface forces. External-station count is a tank-drag proxy; tank type/shape, weapon, open-bay and pylon drag are not resolved. |
| Pitch command | +9/−3 commanded g; 25°/s direct-rate scale; 225–275 knot EAS blend; high-alpha blend 35–60°; 0.08 s load filter; 0.5 s mode blend; 0.30 s pitch-rate feedback time | Architecture inspired by R20/R65/R125; prototype thresholds are not production data. EAS is a substitute for prototype KCAS scheduling. +9 is a public broad capability; negative limit is a disclosed approximation informed by R174. These are demand bounds, **not guaranteed hard actual-load/structural protection**. |
| Lateral command/allocation | Roll schedule 200/160/90/30/10°/s at 0/15/30/60/90° alpha, Mach fade, 15°/s pedal scale; roll/yaw feedback times 0.25/0.40 s; pitch/roll/yaw weights 2/1.2/1, regularizer 0.002, 40 sweeps | Assumed controller tuning; no production gains or roll-rate envelope recovered. Damage reduces surface force independently; a jammed actuator holds its achieved position. Hydraulic networks/load-dependent rates are not simulated. |
| Fuel geometry / mass | Approximate 8200 kg internal capacity; inherited 25 kg unusable reserve; internal fuel at origin; external fuel at supplied station positions | Capacity R153. No actual distributed tank/feed schedule. Point pieces have zero **intrinsic** MOI; host receives their position and owns CG/parallel-axis updates. Contract interpretation needs DCS confirmation, especially negative mass addition/refueling. Host quantity setters do not also enqueue mass changes. |
| Ground/configuration | Gear 4 s; brake deployment ~1.43 s; LEF alpha/Mach schedule; landing flap schedule; steering taper from 60° at rest to zero at 60 knots ground speed; low-fuel warning 1500 kg | Assumed approximations. Core DCS suspension supplies contact forces/braking. No verified full F-22 gear-speed restrictions, tire/brake thermal model, load-dependent actuator limits or deceleration-command brake controller. |
| Buffet/visuals | Alpha/transonic shake and bounded LERX visual fade; two stable independent spline buffers; shaft phase from normalized RPM | Cosmetic assumptions, not measured buffet/condensation thresholds. Density is not a humidity sensor. Surface/nozzle animation signs and EDM argument scaling need visual confirmation. |
| Life support / wake interface | Retained constant oxygen supply 101,000 Pa and flow velocity 10 m/s | Placeholders, not an OBOGS/ECS or exhaust-flow calculation. The bundled header defines oxygen as pressure; older public copies have different unit comments. Runtime confirmation is required. |
| Host fallback | 28,000 kg and diagonal inertia 30,000/180,000/170,000 kg·m² only until host supplies valid mass data | Assumed fallback; not asserted F-22 inertias. Full tensor cross products are not supplied through the bundled mass callback. |

The Chinese model/control papers and unscaled CFD plots remain useful methodological references. They do not turn reconstructed coefficients into measured production F-22 data. CombatACE [R177](RESOURCES.md#r177) is a Strike Fighters 2 visual approximation, not flight-model evidence; its files were not imported.

## Verification actually performed

Release CMake build and three CTest suites pass on GNU C++ 13.3/Linux:

- Physics properties: full alpha/beta sweep, aerodynamic work sign, zero speed, old discontinuity boundaries, thrust-vector magnitude/moment, fuel/refueling conservation, engine state, trims, actuator travel/rate, jam state and equal-duration impulse consistency.
- DCS callback contract tests: engine units, fuel/mass events, proportional independent brakes, small/null draw buffers, repair/immortality/release, low-AGL airborne contact and wind handling. The Linux test-only `windows.h` stub intentionally provides **no CockpitBase DLL**; it does not emulate DCS.
- Independent quaternion rigid-body scenarios: twelve 30-second longitudinal runs at initial speeds 100/150/250/400 m/s and masses 22/28/34 tonnes; a 0.2 pitch pulse at seconds 10–12; plus short roll/yaw direction, settling and sideslip checks. Atmospheric density/pressure remain fixed for these numerical cases; they are not representative test cards or flight-envelope clearance.

Selected 28-tonne outputs, with fixed sea-level atmospheric properties and initial geometric altitude 3000 m in the numerical harness:

| Initial speed (m/s) | Final speed (m/s) | Final alpha (deg) | Final pitch rate (deg/s) | Final body-normal g |
| --- | --- | --- | --- | --- |
| 100 | 106.438 | 6.522 | 0.0052 | 0.9404 |
| 150 | 151.923 | 3.022 | 0.1806 | 0.9977 |
| 250 | 233.471 | 0.800 | 0.0334 | 0.9990 |
| 400 | 295.919 | 0.179 | 0.0178 | 0.9978 |

AddressSanitizer and UndefinedBehaviorSanitizer builds also pass these suites with `ASAN_OPTIONS=detect_leaks=0`. The first local attempt failed inside LeakSanitizer's process/thread inspection in this environment; leak detection was therefore disabled locally. This is not a leak-check pass. CI retains normal sanitizer settings on Ubuntu.

Both changed Lua files pass Lua 5.1 syntax checking. [GitHub Actions run 40079669800](https://github.com/Ethanw05/DCS-F22/actions/runs/40079669800) also built `bin/F22.dll` with MSVC 19.44.35229 on Windows 2022 and passed all three suites there; its Linux sanitizer job passed with normal leak-detection settings. The initial Windows job failed because `windows-latest` had migrated to VS2026; pinning the VS2022 runner resolved configuration. Successful compilation/callback tests do not establish DCS loading, current runtime ABI compatibility or flight accuracy.

## Accuracy and integration still to establish

1. Load the CI-built Windows DLL on a recorded DCS version. Verify force/moment signs, mass changes, engine instrument/sound scaling, surface animation, shutdown, repair/rearm/respawn and ground contact.
2. Check normal flight and approach response across weight/CG/altitude/configuration, including mode transitions and actuator saturation. Add pilot task evaluations; the numerical harness is not a PIO assessment.
3. Obtain legitimate quantitative data with mass/configuration/atmosphere and uncertainty. Fit thrust and drag jointly to several acceleration, climb and steady-flight points. Public supercruise/Mach/ceiling labels alone cannot identify the model. No calibrated top speed, climb, sustained-turn, takeoff/landing, fuel range or full post-stall accuracy is claimed.
4. Replace coefficient/engine assumptions as evidence improves. Detailed high-alpha/beta, departure/spin, compressibility/buffet, asymmetric stores/drag, inlet effects, hydraulic failures and ground performance remain substantial work.
5. Complete the independent avionics path separately. The replacement physics has no F-15 code dependency, but the normal aircraft still registers with `MAC_flyable`; that avionics dependency is **not removed by this EFM rewrite**. See [standalone investigation](STANDALONE_FOLLOWUP.md).
