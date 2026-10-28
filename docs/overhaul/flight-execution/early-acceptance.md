# Independently specified early acceptance

Declared before applying `early-validity-reset.patch`. Original sources:
R-FLT-001, R-FLT-013, D-R-INT-001; VS-001, VS-REQ-FLT-013, DVS-INT-001;
local EFM callback declarations and parameter API return contract. The audit
reproductions identify triggers; their expected assertions are not copied.

Use the rebuilt common native/cockpit/model-clock ports after HARNESS_READY.
Tests must load the actual safely built DLL. No production native function is
reimplemented by the fixture. Initial values come from callbacks/selections,
not fabricated healthy output parameters.

## Atmosphere and independent sources

Set 25,000 kg, 5,000 kg internal fuel, altitude 10,000 m, temperature 223 K,
sound speed 300 m/s, density 0.4135 kg/m3, pressure 26,436 Pa; world velocity
200 m/s north with independently valid body/world motion. Use a declared
sealed-canopy input and hot running source. Record original/physical/model
clocks separately; invoke the actual combat update for native altimetry.

1. Healthy baseline: finite truthful pressure, healthy environment/air data;
   world velocity and ground-speed publication retain the supplied 200 m/s.
2. Change one of eight atmosphere arguments at a time to NaN, +/-infinity and
   an out-of-domain finite value. No substituted pressure/temperature may carry
   healthy full flight/environment/OBOGS authority. With valid world motion,
   the independent kinematics gate and 200 m/s velocity remain healthy.
3. Inspect the actual HUD owner with that frame: ground speed and eligible FPM
   survive; CAS/wind and wind-arrow gates withdraw. No styling/geometry changes.
4. ADC-only failure with healthy atmosphere: primary air data/baro withdraw;
   independent standby remains valid at the same pressure-derived altitude.
5. Shared invalid pressure with healthy standby fault input: standby validity
   withdraws without a fresh manufactured sea-level observation. Restore the
   original atmosphere; eligible groups recover without resource refill.
6. Independent stored oxygen retains finite supply and consumes its own reserve
   during atmospheric loss; OBOGS must not be inferred from fallback values.
7. Invalid world motion withdraws kinematics independently. Release clears both
   gates; fresh generation requires current callbacks. Missing native conversion
   remains the separately owned P-INT-008 subcase, never a valid zero reading.

Status/identity/event counts compare exactly. Transported numeric values use
abs(error) <= max(1e-6, 1e-9*abs(expected)) SI. These tolerances concern software
transport, not atmospheric sensor accuracy or F-22 calibration.

## Generation-local input equivalence

For every cold/hot/air-hot spawn entry, compare achieved rudder traces at equal
new-generation times and identical valid callback inputs. Prior histories are:
neutral, held keyboard left then explicit matching release, held keyboard right
then explicit matching release, held analog yaw then analog zero, and prior
release followed by spawn. Issue the same new left, right or analog-zero input.
The independent oracle is equality across histories, not a copied yaw gain or
target angle. Use actual draw arguments 17/18 and current generation outputs.

Verify nonzero keyboard ramp under pressure separately from equality; opposite
late releases cannot cancel a current opposite key, and keyboard release cannot
take ownership from the analog axis. Invalid/zero dt and draw-only calls must
not advance the trace; source restoration must not replay released commands.
Compare traces to 1e-6 normalized draw units and exact gate/command counts.

State review: raw pitch/roll/yaw, keyboard modes, prior surface/vector commands,
integrals, pitch/roll smoothers, trim owner, AFCS output and achieved angles are
already reset in the shared reset path. Yaw smoothing is the demonstrated
omission. Gear/airbrake selections are assigned by each spawn entry. Host fuel
may arrive before spawn and is deliberately retained until release; physical
generation-local source validity is reset by VehicleContext. Dead/write-only
g_assist state and obsolete timers belong to their own cleanup gates and must
not be mistaken for active filter ownership.

Native fixtures establish callback-contract behavior only. Actual DCS re-slot
ordering, airborne handling and 2D/VR presentation remain separate qualification.
