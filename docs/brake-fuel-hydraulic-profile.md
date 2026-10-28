# Brake, tank and utility demand follow-through

Implemented simulation profile, 27 October 2026. Native DCS runway calibration
remains unqualified; the user excluded flight testing in this run.

## Brakes and tires

DCS owns suspension contact, native anti-skid and baseline rolling/sliding
friction. The 24,000 Nm main-wheel limit and 0.605 m radius remain unchanged in
`FM/config.lua`. The former +0.60 aerodynamic drag addition and its hidden
airbrake-animation override are removed. Pressure and per-wheel thermal
effectiveness now multiply only the SDK relative wheel brake moment. No second
slip controller is added, and airborne forces/control gains are unchanged.

The two-node disc/tire model uses explicit **estimates**: 60/30 kJ/K thermal
capacities, 80 W/K disc-to-tire conductance, disc cooling 50+3|V| W/K and tire
cooling 20+|V| W/K. Fade is continuous from full at 450 C to 25% at 1000 C.
Tire heat damage latches at 200 C; it limits brake effectiveness to 35% of its
current faded value and adds incremental rolling resistance of 0.06 times the
contact reaction magnitude. The force opposes local longitudinal ground motion
at that wheel's contact point, vanishes at rest/unloaded, and can produce yaw
when damage is asymmetric. This is a reduced tire consequence, not a claimed
native burst animation, tire-pressure change or destroyed landing gear.

`WORK_UPPER_J` remains a commanded work envelope: the lesser of requested torque
over radius and contact reaction magnitude, multiplied by ground speed and dt.
It is **not measured anti-skid work** and may overestimate heat on a wet runway.
Wheel feedback expires after 0.1 s; airborne/unloaded/stale samples add no brake
work. A held brake at rest adds none. Raw `wheel_speed_X` remains unconverted
because the installed SDK does not specify its units. Heat continues to soak
into tires after stopping and cools independently of pressure. Repair replaces
damaged tires at ambient temperature and preserves brake disc heat.

Read-only outputs: existing `EFM_L/R_BRAKE_TEMP_EST_C` and
`EFM_L/R_BRAKE_WORK_UPPER_J`, plus `EFM_L/R_BRAKE_EFFECTIVENESS`,
`EFM_L/R_TIRE_TEMP_EST_C` and `EFM_L/R_TIRE_FAILED`. These are physical model
states, not a claim of installed F-22 cockpit temperature sensors.

## Tanks and mass

Absolute host fuel callbacks set contents without queuing host-owned loadout
mass again. Negative/nonfinite quantities and out-of-range station/position
inputs are rejected. Zero contents retain a known station and its position.
An initially empty callback can record a candidate tank, but cannot create
refueling capacity until current native carriage inventory confirms it.

The weapon device observes wing stations 1/9 in its zero-based native API.
Fuel-tank CLSIDs or native fuel-tank type 43 identify carriage; count is the
number of carried stores, never kilograms. EFM matches the callback's physical
left/right position, avoiding an assumed SDK station-number conversion.
Only an observation newer than the station's last absolute callback can confirm
installation/removal. Stale, missing, servicing and invalid observations cannot
remove a tank or authorize external refill. Removal drops contents from the EFM
total without a second jettison mass debit. DCS owns store removal mass.

The 64-entry ledger rejects nonfinite sums, cancels zero-net locations to reclaim
capacity, and atomically refuses both legs of a transfer when capacity is
exhausted. Failed transactions retain fuel. Refueling accepts available capacity
only; negative/nonfinite transfer or refill requests cannot withdraw fuel.
Geometry, cell splits, native MOI and separate SES-bottle mass remain the
previously documented estimates/qualification limits.

## Utility demand

`Vehicle_Stores_Adapter.lua` observes the weapon owner's achieved main/side/gun
door positions. Estimated flow weights are 0.30/0.15/0.15/0.10 times achieved
travel divided by nominal rate*dt, capped per consumer. Confirmed native magazine
decrement adds 0.25 times expended rounds/(100*dt), capped at 0.25. Rearm,
invalid ammunition and changed physical generation reset the baseline. This
round-based estimate does not claim measured motor RPM, dry spin-up or coast-down.
Held doors and an unchanged trigger produce no invented motion demand.

The frame carries `F22_HYD_DEMAND_SCHEMA=1`, current physical generation,
spawn-relative `STAMP`, integer `SEQUENCE`, 0..1 left/right loads and `VALID`.
The producer clears VALID before writing and commits it last. The EFM accepts
only matching sequence/VALID samples, current generation, <=0.25 s age and
<=0.05 s future skew. Tank inventory has a separate <=0.5 s observation stamp.
Invalid/stale demand withdraws to zero. Logical right/System 2 supplies normal
utilities; selected ground maintenance transfer loads the supplying left circuit
when it has greater pressure. This logical side routing and flow response are
estimates, not a recovered production circuit schematic.

## Evidence and checks

- [Eaton, April 2014, pp2, 5–7](https://www.eaton.com/content/dam/eaton/markets/aerospace/Lockheed-Martin-Boeing-FA22-Raptor-capabilities-brochure.pdf): bay motors, hydraulic gun drive/port/purge doors, fuel boost, four pumps and ground maintenance utility switching. Ratings do not establish this model's load weights.
- [F-22 rescue description, 2006, printed pp6/10](https://www.0x4d.net/files/AF1/R11%20Segment%2012.pdf): post-stop wheel/brake heat hazard and feed/transfer roles. Its waiting time is not a thermal coefficient; its inconsistent capacity table is not adopted.
- ED F/A-18C guide, 24 March 2024, pp58–59, and ED F-16C guide, 31 March 2020, pp87–91 (retained extracts in `build-flight/sources/`): native anti-skid/finite reserve analogue and taxi brake heating. Hornet speed thresholds and the conflicting Viper parking RPM are not copied as F-22 values.
- Installed `D:/DCS/API/include/FM/wHumanCustomPhysicsAPI.h`: suspension feedback, brake moment, anti-skid and loadout/refuel callbacks. No thermal/tire parameter is exposed here; hidden host behavior and wheel-speed units remain runway qualification work.

Focused checks use asserted Debug native model/DLL callbacks, Lua 5.1 owner
workflows, Lua lint and MSVC /W4 /analyze. They cover normal/empty/full/invalid
fuel, ledger exhaustion/recovery, fresh/stale/rearm topology, pressure loading
and recovery, no pedal-created aerodynamic drag, heat/fade/soak, persistent tire
force and repair preserving brake heat. They do not establish a DCS stopping
distance, wet-runway thermal calibration or production F-22 coefficients.
