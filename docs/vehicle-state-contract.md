# Physical aircraft contract — VEH-01–15, AUX-01/02

Implementation branch: `codex/flight-resource-verification`, based on
`f22-overhaul-start-2026-10-27` (`c5ebbcc`). This is a source-limited simulation
profile. Package progress and remaining work are in
[vehicle-implementation.json](overhaul/vehicle-implementation.json).
Recorded checks are in [vehicle-verification.json](overhaul/vehicle-verification.json).
The [288-condition callback grid](overhaul/vehicle-bench/callback-envelope.csv)
and [bench plot](overhaul/vehicle-bench/callback-envelope.png) reconcile sampled
force, mass, specific excess power and delivered fuel at declared conditions.
They impose motion and do not establish level equilibrium or sustained flight.

## Resource recheck, 27 October 2026

All 17 packages and their 96 tasks were compared with the collected sources and
integrated code at `a70f525`. That initial review found 33 tasks implemented
within the declared simulation profile, 41 partial, 17 awaiting host
qualification and 5 missing. Engine start/control follow-through subsequently
brings the current package notes to **36 implemented, 40 partial, 17 awaiting
host qualification and 3 missing**. **The assignment
is not fully implemented or release qualified.** Unknown production coefficients
are not counted as demonstrated errors.

| Package | Checked behavior; remaining boundary |
| --- | --- |
| VEH-01 lifecycle | Single ownership and bounded updates; corrected release outputs/queue. Host ordering/thread behavior remains unqualified. |
| VEH-02 air data | SFTE relationships and separate sensed health; Nz, probe heat and icing remain unconfirmed. |
| VEH-03 fuel/mass | Feed/transfer roles and delivered-kg ledger; empty-at-install tanks, native MOI and SES bottle mass accounting remain incomplete. |
| VEH-04 power/APU/SES | Finite sources and analogue shutdown policy; corrected live GPU sampling. Full consumer loads, AC topology and APU-door integration remain incomplete. |
| VEH-05 engines | Separate starter/fuel/ignition, dry crank, no-light/hot/hung protection, logical control failures and guarded recovery now implemented; production limits, fire isolation topology and nozzle supply remain open. See [engine profile](engine-start-profile.md). |
| VEH-06 hydraulics | Four pumps, inventories, APU and tow-service abstractions; full consumer routing and bay/gun demand remain incomplete. |
| VEH-07 FCS | Historical surface groups and pitch-priority allocation; selectable single-engine law, weight-aware bounds and resettable FCS faults remain incomplete. |
| VEH-08 performance | Fixed force locations, wind invariance and table continuation; sustained calibration and native ground effect/store drag/MOI remain unqualified. |
| VEH-09 gear/NWS/hook | Common guards and finite emergency/hook requests; scalar locks do not establish individual leg/door behavior or cable capture. |
| VEH-10 brakes | Parking and pressure reserve; deceleration controller, stop-assist replacement, heat soak/fade and tire consequences are not implemented. |
| VEH-11 ECS | Causal cooling/cabin/fog estimates; native seal/visibility and actual equipment loads remain incomplete. |
| VEH-12 oxygen | Historical versus modern source behavior; corrected manual selection and independent backup. Capacity, production schedule and SDK response remain unqualified. |
| VEH-13 canopy/escape | Native ownership preserved; hold/lock/no-power/escape behavior remains uncharacterized. |
| VEH-14 damage/repair | All 33 mission IDs match, including independent engine start/control producers; corrected destroyed forces, release and missing-rudder effects. Geometry/page and resettable FCS coverage remain incomplete. |
| VEH-15 verification | Owner/DLL and source checks; full normal/degraded DCS mission and flight qualification remain open. |
| AUX-01 refueling | Accepted host fuel/mass changes; pilot door/ready/contact/disconnect and argument mapping remain integration/native work. |
| AUX-02 lights | Owned intensity and source-loss memory; actual emitter dimming, photometry and emitter-specific loads remain unqualified. |

Seven corrected defects concerned manual oxygen selection, independent oxygen
backup with invalid environment data, cached GPU availability, force validity
with invalid mass/CG, forces regenerated after destruction, stale release
outputs/queued mass, and missing-rudder braking/sideforce. Owning-model and DLL
regressions pass; the healthy 288-condition grid is unchanged. Integration also
corrected the two earlier cockpit payload findings.

The saved rescue/SAB PDFs and official ED analogue pages were reread. The 2025
Chuck guides were not newly available; prior planning access is not presented
as a new read. VS12's catalogue title was corrected to W. Hewitt Phillips,
*Journey Into Space Research*, NASA/SP-2005-4540; printed pp17-18 still support
the inertia relationship.

The [held roll comparison and regression](roll-input-ownership.md) records
the earlier GitHub input behavior and the corrected release ownership boundary.
A keyboard release cannot take ownership from a held joystick axis or clear
the opposite keyboard direction. The actual event stream from the reported
flight has not been captured.

## Ownership and timing

`VehicleContext` and the existing RAPTOR physical state have one producer:
`ed_fm_simulate` on the simulation thread. Lua always sends pilot power requests
and consumes achieved supply only from a coherent, fresh physical snapshot.
The duplicate Lua battery, generator, APU and auto-shutdown integrators have
been removed with `Electrical_Computer.lua`. Missing or malformed supply is
unavailable to the adapter; it cannot establish power or advance an APU.
Recorded start/run/stop audio follows qualified rotation and spin-down. An APU
spring release is neutral and cannot reverse START or undo automatic shutdown.
Existing command IDs and recorded assets remain in use.

The update order is host input/health → source availability → bounded hydraulic
and fuel transfer → achieved configuration/control surfaces → engine state and
actual delivered combustion fuel → forces/mass ledger → ECS/oxygen/thermal
state → publication. Coupled sources use the previous completed engine sample.
There are at most 50 substeps of at most 20 ms per call; time beyond one second
is rejected and accumulated in `EFM_PHYSICAL_DROPPED_TIME_S`. Zero/invalid dt and
draw calls cannot advance state.

`EFM_PHYSICAL_VALID` is cleared during publication and committed last.
`EFM_PHYSICAL_GENERATION` changes on spawn; `EFM_PHYSICAL_CLOCK_KIND=1` declares
`EFM_PHYSICAL_STAMP` as spawn-relative RAPTOR seconds, equal to `F22_AP_CLOCK`.
It is **not** absolute `get_model_time`; never compare these epochs directly.
Consumers must read validity, generation and stamp before and after a snapshot
and reject a changing/incomplete frame. This is a parameter-API protocol, not a
claim that arbitrary concurrent DCS API access is independently qualified.
Individual source validity remains separate from publication validity.
`EFM_FORCE_VALID=0` accompanies a deliberate zero-force fallback for missing or
out-of-range physical producers; computational input bounds are not aircraft
operating limits. Valid host input restores the normal force path.
Mass/CG validity participates in force qualification. The declared destroyed
state keeps its zero-force/zero-moment result through the end of the calculation.
Forces stay withheld until a valid host mass callback arrives for the new spawn;
actual DCS ordering of that first callback remains a host qualification item.

Power requests use `F22_POWER_REQUEST_VALID` and an integer
`F22_POWER_REQUEST_SEQUENCE` committed after the four request fields. The EFM
accepts a stable sequence only. Requests persist until replaced by a complete
request frame; actual energy and source health continue evolving independently.
The host GPU connection is sampled each physics step, outside this transaction.

Degraded air data holds the last healthy Mach/EAS control schedule, freezes
automatic configuration/trim integration and withdraws AFCS authority. With no
qualified sample, an explicitly estimated 200 m/s sea-level schedule is used.
`EFM_FCS_AIRDATA_REVERSION` identifies this state; it does not replace true force
airflow or pretend that the held values are healthy sensor observations.
Legacy `EFM_TRIM_IAS_KTS` retains EAS semantics; new named channels distinguish it.

## Provider and consumer interface

All booleans are numeric 0/1. Missing/nonfinite new native fault readings fail
closed; failed API conversion is checked. New handles are prebound in a fixed
array. The exact channel list is [VehicleSignals.h](../EFM/source/VehicleSignals.h).

| Quantity | Input / producer | Output / units and meaning |
| --- | --- | --- |
| Power switches | Lua: `F22_BATTERY_REQUEST`, `F22_L_GEN_REQUEST`, `F22_R_GEN_REQUEST`, `F22_APU_REQUEST`; host `GROUND_POWER` | EFM: existing MAIN/BATTERY/L_GEN/R_GEN/APU_POWER, APU_RPM_STATE 0..4; `F22_BATTERY_SOC` 0..1, `F22_DC_VOLTS` V, `F22_ESSENTIAL_POWER` is usable DC, with no claimed AC conversion or receiver-specific feed |
| Limited ground APU | EFM APU, battery, finite SES and common feed | `EFM_APU_HYD_AVAILABLE`, `EFM_APU_AIR_AVAILABLE`, `EFM_APU_ABORT`, `EFM_APU_AUTO_SHUTDOWN`; `EFM_MAIN_POWER_SOURCE`: 0 absent, 1 engine generator, 2 GPU, 3 ground APU |
| Mission equipment | Source distribution | `EFM_MISSION_POWER_AVAILABLE` excludes APU-only service. Integration must use it for high-load mission consumers rather than infer unrestricted APU capacity from legacy MAIN_POWER. |
| SES | EFM normalized air/start-fuel inventories | `EFM_SES_AIR`, `EFM_SES_FUEL`, 0..1; actual capacities remain unknown |
| Air data | Host truth; `F22_AIRDATA_HEALTH_REQUEST`, `F22_AIRDATA_CAS_BIAS_MPS` | `EFM_AIRDATA_VALID/STAMP/TAS_MPS/EAS_MPS/CAS_MPS/MACH/STATIC_PA/IMPACT_PA/HEALTH`; health 0 healthy, 1 invalid, 2 frozen, 3 biased. Frozen sample keeps its original stamp. Physics retains true airflow; AFCS refuses degraded sensed authority. |
| Normal load | Host body callback | `EFM_BODY_AY_MPS2` raw diagnostic; legacy `EFM_TRIM_NZ` convention retained pending host gravity experiment, not authenticated signed Nz |
| Fuel | Host initial/installed station/refuel callbacks; EFM cells, supply and burn | Existing internal/external/total kg and engine flow kg/s; `EFM_L_FEED_KG`, `EFM_R_FEED_KG`, `EFM_COMMON_FEED_KG`, `EFM_FUEL_BOOST/PRESSURIZATION` 0..1; feed available/low and bingo are distinct |
| Mass properties | Host current-mass callback | `EFM_MASS_VALID`, `EFM_MASS_KG`, `EFM_CG_X_M/Y_M/Z_M`, `EFM_INERTIA_X_KGM2/Y_KGM2/Z_KGM2`; x forward/roll, y up/yaw, z right/pitch. Inertia is retained, not supplemented with an unqualified second contribution. |
| Engines | Unified guarded start/stop commands | `EFM_L/R_ENGINE_PHASE`: 0 OFF, 1 CRANKING, 2 LIGHTING, 3 ACCELERATING, 4 RUNNING, 5 SHUTTING_DOWN, 6 WINDMILLING. `EFM_L/R_START_REJECTION`: 0 none, 1 fuel, 2 power, 3 starter, 4 damage, 5 isolation. Existing core/fan, oil, temperature, thrust and nozzle exports remain. |
| Hydraulics | Four pump statuses, APU, circuit leak faults, local and declared bay/gun demand | Existing left/right psi and actuator authority; `EFM_L/R_HYD_PUMP_1/2`, `EFM_L/R_HYD_INVENTORY` normalized, `EFM_BRAKE_RESERVE` normalized stored pressure. `F22_HYD_DEMAND_VALID` qualifies `F22_L/R_HYD_LOAD` 0..1 from integration. Circuit inventories are independent. |
| FCS/configuration | Achieved gear and receptacle door; existing stick/trim | `EFM_FCS_CONFIGURATION`: 0 cruise, 1 approach, 2 refuel. `EFM_SINGLE_ENGINE_APPROACH` identifies one-engine approach eligibility, not adoption of the 1998 selectable law. `EFM_APPROACH_AOA_DEG=12` retains the normal reference. Trim remains dimensionless ±0.2; achieved surface/vector fields remain degrees. |
| Gear/NWS/hook | Existing gear requests, new physical commands | `EFM_GEAR_REJECTION`: 0 accepted, 1 WOW, 2 estimated overspeed, 3 source, 4 alternate latched, 5 invalid air data; GEAR_UNSAFE, DOWN_LOCKED/UP_LOCKED scalar proxies, ALTERNATE_GEAR, NWS_SELECTED, HOOK_POSITION. Independent leg locks and cable arrestment remain unqualified. |
| Brakes | Independent normalized wheel requests and native anti-skid | Actual relative brake moments remain pressure-qualified. `EFM_PARK_HELD` differs from `F22_PARK_REQUEST`; repeated set/release is idempotent. TEMP_EST_C and WORK_UPPER_J are diagnostic demand-based estimates, not measured work or qualified fade. Native wheel limiting remains sole anti-skid authority. |
| ECS/oxygen | Selected engine bleed, ground APU, source faults, canopy provider | `EFM_ENVIRONMENT_VALID`, CABIN_ABSOLUTE_PA/OVERPRESSURE_PA, CONDITIONED_AIR_AVAILABLE, OBOGS_AVAILABLE, OXYGEN_BACKUP_ACTIVE/RESERVE/DELIVERY_PA, EQUIPMENT/COOLANT/FUEL_TEMP_C, THERMAL_FAULT, CANOPY_FOG. SDK cabin increment is withheld until native canopy validity exists. Healthy SDK oxygen baseline remains 101000 Pa pending host response characterization; source/reserve outputs do not claim clinical effects. |
| Fire | Planned fire producer, isolation, separate discharge | `EFM_L/R_FIRE_DETECTED/ISOLATED`, FIRE_BOTTLE_AVAILABLE, FIRE_DISCHARGE_ATTEMPT. Isolation removes fuel, generator and bleed paths. Discharge consumes the estimated single inventory and does not prove extinction. |
| AUX-01 | Integration: `F22_REFUEL_DOOR_REQUEST/DISCONNECT_REQUEST` | Achieved `EFM_REFUEL_DOOR_POSITION`, READY, TRANSFER. Transfer means an accepted host fuel delta in the last 0.5 s, including ground service; it never establishes tanker contact. Native contact/door argument mapping remains with integration. |
| AUX-02 | Existing formation/AAR preferences and actual bus | `EFM_FORMATION_INTENSITY`, `EFM_REFUEL_INTENSITY` 0..1, also external args 606/609. Supply loss stops emission without erasing the preference. Actual EDM photometry remains unqualified. |

## Fuel and physical budgets

The fuel owner has three feed roles and five transfer roles. Total internal
capacity is 8200 kg. The 1000/1500/1500/900/900/900/750/750 kg split, positions,
40 kg/s transfer bound, normalized boost/pressurization and 100 kg feed-low
threshold are **estimates**, not recovered hardware values. No inconsistent
rescue-table capacity is adopted. External-first transfer is proportional across
up to 16 host-reported installed stations. A zero station callback retains its
legacy removal meaning; initially empty installation identity still requires a
separate observed host adapter. A tank emptied by consumption remains installed.

Transfers atomically queue opposite fixed-position mass deltas; burn/refill queue
only delivered/accepted mass. The fixed 64-slot ledger coalesces positions and
refuses mutations on overflow. Initial host fuel callbacks do not debit mass a
second time. Start combustion, main burners, augmentation and APU draw finite
fuel. Engine flow explicitly includes augmentation. Unlimited fuel computes
current delivered flow while suppressing quantity/mass changes. Feed or transfer
failure can starve an engine with fuel remaining elsewhere; restoration requires
a new engine-start request after a flameout.

Normal utility supply uses the right logical hydraulic circuit as an explicitly
estimated System2 mapping; `EFM_UTILITY_AVAILABLE` differs from redundant
flight-control supply. Ground maintenance transfer can select the surviving
circuit and clears airborne. The complete production consumer schematic remains
unknown. Integration must select the applicable route for bays and gun demand.

Aerodynamic points are fixed to the airframe, apart from the retained AoA shift.
CG translation therefore changes moments. The high-Mach sentinel-zero thrust
entries now use a labelled bounded continuation of the last nonzero legacy
anchor to Mach 2.4; this does not calibrate supercruise or authenticate an F119
deck. Ground effect, store drag, stopping assist and native contact behavior
must be characterized before replacing/duplicating host contributions.

The 17:13 flight log exposed a turn-authority regression in `12cf760`: fixing
wing forces directly around model-origin zero discarded the inherited wing
coefficient reference. Full stick saturated the elevator while AP was off and
actuator availability remained one. The correction captures the first qualified
physics-step CG as the wing's fixed spawn datum; repair and subsequent mass
changes do not move it. This is an explicit calibration estimate, not recovered
F-22 geometry. At a declared 1 m spawn CG, the actual DLL regression restores
the pre-overhaul +1,167,636 Nm pitch moment from +58,199 Nm with identical force,
surfaces and thrust; subsequent CG translation still changes moment by the force
cross-product. The test failed before the correction and all 29 native checks
passed afterward. The Release DLL was installed on 27 October at 17:21 MDT;
the existing simulator process requires a restart. Corrected DCS turn performance
has not yet been observed.

## Pilot inputs and servicing

Physical commands 11700–11729 are separate from navigation's 11600 AFCS and
11800 entry transaction range. Keyboard and joystick menus add unbound commands;
existing saved bindings are retained. The sequence is battery/APU request →
achieved APU supply → guarded engine start → generator qualification. Direct
keyboard, click and automatic starts reach the same EFM guard.

| Command | Meaning |
| --- | --- |
| 11700 | SES alternate gear; one air debit, latched extension, no normal retraction |
| 11701 | NWS select/release, value 1/0 |
| 11702 | Pneumatic hook extend/retract, value 1/0; one debit per changed request |
| 11703/11704 | Left/right fire isolation |
| 11705 | Separate selected-compartment discharge; finite estimated inventory |
| 11706 | Ground service SES and oxygen reserves with main engines not burning |
| 11707/11708 | Left/right bleed select, value 1/0 |
| 11709/11710/11711 | ECS/defog/manual backup select, value 1/0 |
| 11714 | Adjust pilot bingo by signed kg delta; menu steps ±100 kg |
| 11716 | Ground hydraulic fluid servicing with main engines not burning |
| 11717 | Explicit ground tow/hand-pump brake-reserve service |
| 11718 | Ground maintenance hydraulic transfer select, value 1/0; clears airborne |

| Lifecycle event | Contract |
| --- | --- |
| Cold/hot/air spawn | New generation; transient controls/faults reset, hot instruments/sources seeded appropriately; host-loaded fuel/tanks retained; no duplicate mass transaction |
| Repair | Restore supported structure/utility fault contract and suppression inventory; preserve fuel, battery charge, SES/oxygen depletion, hydraulic fluid loss and brake heat; never start engines |
| Refuel/rearm | Fuel callback changes only accepted fuel/mass; no implicit equipment repair; station callback owns installation identity |
| FCS reset / caution acknowledge | Does not repair structure, refill resources, or extinguish a fire |
| Pause / draw | Zero physics dt and repeated drawing do not consume resources or move effectors |
| Release | Invalidate owned publications, clear installed-station tracking and bounded queues, reset native owners through the retained callbacks; reject further simulation until spawn |

`ed_fm_on_planned_failure` supports the exact bounded ID table in
[VehicleFaults.h](../EFM/source/VehicleFaults.h). `ed_fm_need_to_be_repaired`
reports structural/equipment faults, not normal resource depletion. Mission UI
registration in shared `F-22A.lua` declares the exact 33 bounded IDs with
failures disabled by default. Actual mission-editor activation remains host
qualification; callback and registration tests establish the source chain.

The [engine start profile](engine-start-profile.md) defines independent
starter/fuel/ignition commands, protection/recovery, control degradation and
the schema-qualified read-only cockpit status interface. Its numeric limits
are estimates with dated ED workflow analogues, not F119 operating data.

## Evidence, estimates and verification boundary

Functional sources: [F119 manufacturer](https://www.rtx.com/prattwhitney/products/military-engines/f119),
[Eaton April 2014](https://www.eaton.com/content/dam/eaton/markets/aerospace/Lockheed-Martin-Boeing-FA22-Raptor-capabilities-brochure.pdf),
[1998 EMD paper](https://man.fas.org/dod-101/sys/ac/docs/f-22-emd-paper.htm),
[2006 rescue description](https://www.0x4d.net/files/AF1/R11%20Segment%2012.pdf),
[2012 public SAB report](https://www.airandspaceforces.com/PDF/DocumentFile/Documents/2012/AFSAB_Oxygen_020112.pdf),
and [2013 ABOS account](https://www.edwards.af.mil/News/Article/394043/edwards-airmen-vital-to-raptors-return/).
Air-data equations follow [SFTE sections 4.1/4.4](https://society-of-flight-test-engineers.github.io/quarto-handbook/04-pitot-statics.html).

Selected analogue passages were read from the installed **24 March 2024** ED Hornet manual,
pp57–59/61/65/67, and the locally retained **31 March 2020** ED Viper guide,
pp80–82/87–91. The requested 2025 Chuck guides returned HTTP403 in this run;
they are not claimed as newly read. The chosen 60-second dual-generator APU
rule is a Hornet-derived simulation choice. Neither its topology nor Viper
cranking thresholds are declared F119 specifications. Other equipment lags,
capacities, thermal conductances and trigger thresholds are documented estimates
in their owning headers. The 600-second oxygen-reserve normalization is an
independent mod calibration, not the historical EOS duration or ABOS capacity.
Manual backup selection can use the finite reserve while OBOGS remains
available; availability and selected delivery are different states. Invalid
canopy/thermal inputs cannot disable the independent stored oxygen source.

Verification uses the actual MSVC DLL plus a test-only CockpitBase parameter API,
isolated numerical tests, Lua 5.1 device tests, and pinned luacheck. DCS flights,
native probe weather effects, canopy/escape behavior, cable capture, wheel heat,
airframe icing, inertia/contact ownership and full performance calibration are
not established. The user's later instruction excludes flight tests in this run.

Coding exceptions: the retained monolithic legacy force callback and legacy Lua
device still exceed function-size/complexity targets; focused physical helpers
bound new work and avoid a mass rewrite. Legacy CockpitManager/native adapters
still allocate strings/use pre-existing native interfaces; this patch does not
claim whole-DLL allocation or lifetime compliance. New physical model code is
fixed-capacity and statically analyzed. Pinned lizard checked 134 focused
physical functions in the initial patch: maximum cyclomatic complexity 13 and maximum 33 non-comment
lines. Six functions exceed the preferred complexity 10; none exceed the hard
limit 15. The 288-condition callback CSV is identical before and after the
complexity refactor. Branch coverage is not measured because
a coverage tool was not available. See the package evidence for actual results.
The engine/control follow-through covers 177 focused helper functions with the
same maxima; the release invalidation helper is complexity 6 and 22 non-comment
lines. Current source hashes and exact combined test totals are in the
verification JSON.

Reproduce with CMake/VS18 x64 Debug in an isolated build directory, then
`ctest -C Debug --output-on-failure`. Python tooling is pinned in
`tools/requirements-vehicle.txt`; run Python with UTF-8 output on Windows.
`tools/check_vehicle_lua.py` accepts a luacheck v1.2.0 clone and report path.
`tools/check_vehicle_complexity.py` checks the declared physical header set and
optionally writes a JSON report with source hashes.
`tools/diagnostics/sample_vehicle_envelope.py` requires explicit test CockpitBase
and EFM DLL paths; `plot_vehicle_envelope.py` renders the resulting directory.
The initial complete tag snapshot had 25 failing Python checks (105/130).
Obsolete display routes, uncalled format factories, old graph names/scales and
superseded UFC entry assumptions were subsequently migrated to current owners.
Three fully superseded UI tests were retired with their replacement coverage
mapped in [tests/README.md](../tests/README.md). Numerical and physical model
checks were retained. The verification JSON records the actual final combined
result; source tests do not establish DCS flight qualification.
