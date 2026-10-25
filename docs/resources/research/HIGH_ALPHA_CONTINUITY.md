# High-alpha vortex correction: numerical discontinuity removal

## Read before code

[02 aerodynamics audit](../../audit/02-aerodynamics.md) AER02 reproduced the existing F-22 mod's discontinuity: at 100 m/s, rho=1.225, alpha 65° →65.0001° the *unchanged old code* body-Y force jumped from approx. **1,062,271 N to 899,661 N**. The existing formula also activates a nonzero vortex correction abruptly as absolute alpha crosses 15°. Neither threshold is compatible with continuous aerodynamic response unless an impulsive aerodynamic regime change is explicitly intended and supported by measured data.

[Existing R127/R128 high-alpha research](../../RESOURCES.md#r127) examines F-22 nonlinear high-alpha response, but does not disclose a production-ready absolute aerodynamic coefficient surface. Therefore we are **not importing new coefficients** or pretending to identify the F-22 flight model. No CFD.

## Implemented scope

Extracted a pure C++ `RaptorAero::VortexLiftCorrection(alpha_degrees)` into `EFM/source/HighAlpha.h`. It preserves existing empirical peak **0.72 at 35°** and Gaussian width. At 15–20° the correction smoothly fades in; at 60–65° it smoothly fades out. The `SmoothUnit(t)=t²(3−2t)` is continuous with zero endpoint slope. Values are nonnegative, symmetric in alpha, bounded at ≤0.72, exactly zero at and outside the former activation interval and for invalid NaN. This fixes numerical discontinuity but the peak shape remains unsupported as production aircraft data.

## Validation

`tests/test_high_alpha.cpp` exercises the **same function used by `RAPTOR.cpp`**, sweep −180° to +180° at 0.01° resolution, symmetry and bounds, peak and endpoint values, small perturbations across 15°,20°,60°,65°. Windows CI now runs `ctest --test-dir out/build/x64-release -C Release --output-on-failure` after EFM build, independent of DCS runtime.

**Limits**: `drag_direction` still has an unrelated discontinuity at ±100° angle of attack; body-axis/relative-flow derivation is not verified, so it is not altered on an unsupported guess. Other stabilizer moment terms remain artificial and uncalibrated. Need DCS force telemetry, high-alpha recovery and full flight-envelope validation before judging handling improvements.
