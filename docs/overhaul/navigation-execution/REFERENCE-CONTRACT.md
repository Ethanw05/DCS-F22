# Cockpit reference and indication contract

Owner: navigation/cockpit. No second physical, air-data or GINS integrator is added.

| Field | Provider and units | Admission |
| --- | --- | --- |
| IAS | Existing EFM calibrated pitot airspeed, m/s to knots | Current physical and ADC sample, finite 0..1500m/s; same declared generic indicated-speed adaptation as the HUD |
| TAS | EFM air-data TAS, m/s to knots | Its own finite value and current ADC sample |
| Mach | EFM air-data Mach | Independent finite 0..10 value and current ADC sample |
| AoA | Synchronous host AoA observation, radians to degrees | Finite +/-pi; conservative shared-primary-ADC policy, health0 required |
| G | Synchronous host normal-load observation, g | Current full physical group and finite +/-1000 software guard; no raw fallback when unavailable |
| Slip | Synchronous host slip observation, radians | Current full physical group and finite +/-pi |
| Vertical speed | EFM world-up velocity, m/s to ft/min | Independent current world-kinematics gate; uppercase `VV` only |
| Height | Existing Altitude_Snapshot radar feet | Original World sample lease and source validity; no host-sensor bypass |
| Primary heading | Selected GINS NAV resource, true radians | Current schema2 generation, independent heading-valid flag and selected true/magnetic reference |
| Standby heading | Selected GINS SFG resource, true radians | Independent SFG heading flag and selection; common ADC fields do not become independent backup sensors |
| HUD heading | Selected GINS HUD resource, true radians | Same admission; owns the HUD heading number/tape and cannot be overwritten by Avionics NAV |

The broad numeric guards above are software/formatting domains, not F-22 limits.
The CAS/IAS adaptation and two shared-observation GINS resources remain declared
simulation estimates; these tests do not calibrate production aircraft sensors.

## Source clocks and reset

The existing physical group retains schema1, generation1..uint32max and spawn
clock kind1. Cockpit publication adds `EFM_PHYSICAL_WORLD_CLOCK_KIND=2` and
`EFM_PHYSICAL_WORLD_STAMP`, sampled from the existing matched World model-time
export before the physical VALID commit. Missing/nonfinite clock publishes
unavailable time and release withdraws the clock kind. No new clock lookup,
allocation, wait or integrator runs inside the recurring callback.

The navigation currentness reader requires finite independent World time,
physical currentness and explicit clock kind2. Its publication lease is .25s,
with .01s future tolerance. An unchanged publication timestamp never renews age.
ADC original spawn-sample age is added to World publication age. GINS carries its
own original synchronous observation World time, so a copy cannot reset either
source lease. A World rewind requires a higher physical generation;
retired lower generations cannot return. These are transport policies, not sensor
specifications or proof of actual DCS callback ordering.

GINS schema2 adds `F22_GINS_GENERATION`, `F22_GINS_WORLD_CLOCK_KIND=2` and
`F22_GINS_WORLD_STAMP`. VALID is withdrawn before its payload; the reader captures
sequence/both clocks/generation before payload and rechecks them
afterwards, including equality to the current physical generation. A source
generation change retires previous alignment; explicit startup/reset determines
the new initial alignment state. No old schema1 frame is accepted implicitly.

Native magnetic declination uses schema1, odd/even sequence2..16777214,
physical generation, World clock kind2 and original World sample time.
Declination is finite radians with abs<1.57, preserving the existing adapter
domain. Every required native setter and parameter epoch is checked before the
even commit. A failed conversion is not zero. The Lua reader checks the full
tuple and .25s age. Requested magnetic reference becomes unavailable if that
tuple is unavailable; it never silently displays true heading. Degree/radian
roundtrip errors within1e-9 degree are snapped only to prevent integer-boundary
flicker; the heading tape keeps its continuous scale.

Native receiver/context ownership and private allocator/callback lifetime remain
P-NAV-003 qualification work. The isolated DLL and function-table tests do not
establish supported-host lifetime, threading, 2D/VR presentation or multiplayer.
