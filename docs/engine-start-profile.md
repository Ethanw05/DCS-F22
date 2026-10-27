# Engine start and protection profile

VEH-05 uses one EFM controller and one instrument/thermal model per engine.
Cockpit code submits selections and reads a coherent snapshot. It does not
integrate spool, fuel, temperature, starter duty or protection timers.

## Evidence and applicability

[Pratt & Whitney's F119 description](https://www.rtx.com/prattwhitney/products/military-engines/f119)
supports an augmented twin-spool engine with digital engine/nozzle control and
diagnostics. It does not supply a start schedule, channel topology or recovery
limits. [Eaton, April 2014](https://www.eaton.com/content/dam/eaton/markets/aerospace/Lockheed-Martin-Boeing-FA22-Raptor-capabilities-brochure.pdf)
supports F-22 APU/start and fueldraulic equipment roles, not the provisional
left/right aircraft-hydraulic nozzle supply map retained here.

The locally retained ED Viper guide, **31 March 2020**, pp80–82, supplies the
named workflow analogue: motor first, introduce fuel at sufficient rotor speed,
confirm light-off and monitor temperature. The ED Hornet guide, **24 March
2024**, pp57–59/61, supplies the APU-assisted starting/source analogue. Neither
establishes F119 procedures. These are the passages actually read; a newer
indexed manual and the inaccessible 2025 Chuck guides are not substituted for
them. Logical NORMAL/DEGRADED/UNAVAILABLE control states below are simulation
policies, without a claim about production FADEC hardware channels.

## Estimated parameters

All values are mod calibration, including values that resemble the analogue.
Core is normalized indicated spool, not a recovered F119 shaft-speed schedule.

| Parameter | Value |
| --- | --- |
| Fuel admission / self-sustaining core | 0.20 / 0.40 |
| Unlit admission timeout | 10 s |
| Burning start timeout | 45 s |
| Hot-start cutoff / restart below | 900 / 600 °C |
| Fuel-off purge exposure | 5 s with core ≥0.12 |
| Starter continuous duty / rest reset | 60 / 15 s |
| Windmill relight eligibility | Airborne, core ≥0.15, TAS ≥90 m/s |
| Degraded maximum core / vector authority | 0.95 / 0.50; augmentation inhibited |
| Hung-start core targets | 0.35 lighting, 0.60 acceleration |
| Injected hot-start extra thermal target | 1,400 °C |
| Motoring / ordinary non-burning cooling lag | 8 / 22 s |
| Nozzle area slew | 60 percentage points/s toward achieved augmentation |
| APU fuel draw | 0.04 + 0.015 per engaged starter kg/s |

Healthy automatic cold starting retains the initial 11/18/15 s phase rates.
Warm and windmill starts enter at achieved rotor state. Fuel flow, actual
delivered fuel, temperature, oil and nozzle area share the achieved engine
state. Unlit metered fuel is explicitly discharged overboard and debited by
the existing fuel/mass ledger; the purge exposure is not an invented reservoir
of retained engine fuel. Starter load therefore increases cold-start APU fuel
consumption. Healthy running thrust and combustion-flow calibration is retained.

## Pilot workflow and recovery

| Action | Achieved result / guard |
| --- | --- |
| Apply electrical power and qualify APU start source | Enables powered controls and starter assistance |
| Select starter ON with fuel OFF | Dry crank, no combustion flow or thrust; starter duty advances |
| At sufficient rotor speed select ignition ON and fuel ON | Valve admits fuel only with feed, control and source guards satisfied |
| Confirm LIGHTING, ACCELERATING, RUN | Temperature/oil follow the sole instrument model; automatic starter disengages |
| Deselect ignition after established combustion | Running combustion remains; this does not cut fuel |
| Fuel OFF / existing engine stop | Cuts metered fuel and combustion; rotor winds down or windmills |
| No light, hot/hung start, full control loss or exhausted starter duty | Latches the diagnosed fault and cuts fuel; failed combustion produces no thrust |
| Restore fault producer / repair | Repairs equipment only; leaves protection latch and restart consent intact |
| Fuel OFF, cool below restart threshold, dry crank until purge is complete | Clears exposure through achieved rotor motion, with finite starter duty/rest |
| Starter OFF, healthy powered controls, purge complete and starter rested; press reset | Clears protection only when RESET READY; does not start the engine |
| Select/start explicitly again | Re-enters the same guards |

Feed loss closes the achieved valve and clears the fuel request. Restoring feed
cannot restart an engine. Repeated start commands or fuel off/on requests in
one physics step cannot reset the no-light/hung-start deadline. An augmentation
failure removes its fuel, thrust and area target while dry combustion survives.

## Interface

Unbound keyboard/joystick entries preserve saved bindings. Commands take explicit
0/OFF and 1/ON: 11719/20 left/right starter, 11721/22 fuel, 11723/24 ignition;
11725/26 reset on a press of 1. **11727/28 remain reserved.** Existing automatic
engine-start and stop commands use the same controller.

`EFM_ENGINE_CONTROL_SCHEMA=1` and per-side `EFM_L_`/`EFM_R_` fields are published
inside the existing physical snapshot, before `EFM_PHYSICAL_VALID` commits it.
Generation and clock semantics remain those in
[vehicle-state-contract.md](vehicle-state-contract.md): clock kind 1 is
spawn-relative, seconds, with the `F22_AP_CLOCK` epoch.

| Suffix | Quantity |
| --- | --- |
| STARTER_SELECTED / STARTER_ENGAGED | Requested / achieved, numeric 0 or 1 |
| FUEL_SELECTED / FUEL_VALVE | Requested / achieved, numeric 0 or 1 |
| IGNITION_SELECTED | Requested, numeric 0 or 1 |
| START_FAULT | 0 none, 1 no light, 2 hung, 3 hot, 4 control loss, 5 duty, 6 invalid data |
| ENGINE_CONTROL | 0 normal, 1 degraded, 2 unavailable |
| CONTROL_AVAILABLE / AUG_AVAILABLE | Achieved eligibility, numeric 0 or 1 |
| PURGE_S / START_ELAPSED_S | Seconds |
| START_RESET_READY | Actual reset guards satisfied with a latched fault, numeric 0 or 1 |

Existing ENGINE_PHASE and START_REJECTION enumerations retain their first
values; added rejection meanings are declared in `EngineStart.h`.
`Engine_Status.lua` reads this snapshot and publishes `F22_ENGINE_L/R_STATUS`,
`F22_ENGINE_L/R_CONTROL` and `F22_ENGINE_L/R_STATUS_VALID`. Invalid payload,
schema, epoch or stale owner produces UNKNOWN with validity 0; it never falls
back to a second controller. Navigation integration owns placement of these
strings on START/reference/engine displays.

Fourteen additional disabled-by-default planned failures cover independent
left/right starter, ignition, hung start, hot start, degraded control, failed
control and augmentation. Their exact bounded IDs are in `VehicleFaults.h` and
registered once each in `F-22A.lua`.

## Verification boundary

`engine_start_and_failure_workflow` exercises normal/manual/automatic starts,
dry crank, delivery, source loss, windmill restart, protection and recovery.
`vehicle_overhaul_callbacks` exercises the built DLL, planned producers, finite
fuel/mass debit and independent engine outcomes. `test_engine_status.py` checks
the Lua 5.1 consumer, invalid/stale generations, indications and all 33 failure
registrations. These checks establish the implemented policy, not F119 limit
authenticity or actual DCS switch/display qualification. Flights are excluded
by the user's instruction. Fire-isolation topology, production relight limits
and physical nozzle supply remain open in VEH-05.
