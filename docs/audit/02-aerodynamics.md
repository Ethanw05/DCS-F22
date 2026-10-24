# 02 — Aerodynamics, air data and performance

## Applicable resources

| Reference | Application | Limit |
| --- | --- | --- |
| [R20–R22](../RESOURCES.md#r20), [R125–R129](../RESOURCES.md#r125) | Handling-quality goals, configuration effects and high-alpha development. | Separate YF-22, EMD and production aircraft. |
| [R27/R29](../RESOURCES.md#r27), [R131/R153](../RESOURCES.md#r131) | Geometry and conditioned public performance checkpoints. | Headline speed or demo targets cannot identify a full coefficient model. |
| [R162](../RESOURCES.md#r162), [R166–R168](../RESOURCES.md#r166) | Unsteady identification, high-alpha validation and propulsion coupling. | Chinese research methods are not released F-22 production data. |
| [R163–R164](../RESOURCES.md#r163) | F-22-like CFD studies with control/configuration variations. | Reconstructed geometry, limited conditions and proposed alternate tails; no measured full-aircraft validation. |

## Code scope and findings

Reviewed [RAPTOR.cpp:269–388](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/EFM/source/RAPTOR.cpp#L269), force/moment helpers, rate/limiter forces, state callbacks, `FM_DATA` tables and `F-22A.lua` aerodynamic/AI data.

- **AER01 — C/I:** The model blends Mach-based tables, clipped lift, a Gaussian vortex addition, scalar alpha drag, and direct surface forces. It does not expose a documented six-coefficient aerodynamic database with consistent reference chord/span, nondimensional rate derivatives and control derivatives. Define whether coefficients are body-axis or wind-axis quantities before correcting transformations; naming a variable `Lift` alone does not prove its axis convention.
- **AER02 — C/R:** [The vortex boost](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/EFM/source/RAPTOR.cpp#L326) is abruptly removed above 65° absolute alpha. In extracted unchanged `ed_fm_simulate`, rho=1.225 kg/m³, speed=100 m/s, gear/slats/flaps/airbrake zero, no engines, g=1: total body-Y force changed from **1,062,270.622 N at 65°** to **899,660.987 N at 65.0001°**. This identifies a numerical discontinuity, not a real-aircraft maneuver result. Replace hard switches with a justified continuous model.
- **AER03 — C/I:** [Drag direction](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/EFM/source/RAPTOR.cpp#L322) flips sign at 100° alpha. It should follow the declared relative-flow/force-axis model through reversed flow, rather than a detached scalar switch. Explicitly assess work/energy, sideslip and negative-alpha symmetry.
- **AER04 — C/I:** [Rate limiting moments](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/EFM/source/RAPTOR.cpp#L944) add large pressure-independent constants and a sixth-power roll limiter. Identify these as artificial stabilization/limits and evaluate them with the controller. Do not calibrate aerodynamic derivatives to hide their effect.
- **AER05 — C/U:** [Mass-state callback](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/EFM/source/RAPTOR.cpp#L990) stores CG but ignores supplied mass/inertia; DCS still integrates rigid-body dynamics. This is not evidence that aircraft mass is ignored by DCS. Our controller cannot explicitly schedule against that state until it is retained. Validate acceleration/gravity convention for `g = ay/9.81 + 1` across bank, pitch, inverted flight and free fall.
- **AER06 — C:** The EFM reference area is 78.06 m² while [the Lua aircraft table](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/F-22A.lua#L104) says 56.5 m². Lua and C++ engine/aerodynamic tables also differ. Reconcile AI/player configuration without assuming Lua SFM fields directly drive the player EFM.
- **AER07 — C/I:** Equivalent-speed approximation `V*sqrt(rho/rho0)` is used as “IAS,” including gear/mode decisions. It does not model compressible pitot calibration at high Mach. Declare EAS versus IAS/CAS and apply the correct quantity for each schedule.

## Rewrite and validation scope

Use an explicit body/wind-axis convention, continuous coefficient surfaces and a separately defined controller. Include configured stores/doors/gear/LEF/flaperon effects once. Retain source provenance and uncertainty for every fitted coefficient. Neither the Chinese F-22-like models nor the unscaled plots in R127 justify importing coefficients as measured aircraft data.

Future checks: zero/reversed flow; alpha/beta continuity; force work/energy; trim and linearized responses; clean/tank loadouts; multiple masses/altitudes; dry/AB acceleration, climb and turn performance. Record atmosphere, mass, configuration, speed definition and input history. Do not fit only top speed or use demo profiles as sustained-turn charts.
