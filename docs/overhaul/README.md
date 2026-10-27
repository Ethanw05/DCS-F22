# F-22 Mod Overhaul Plan

A system-by-system guide to the changes needed for a faithful F-22 simulation. Follow documented F-22 behavior where available; use an explicitly chosen aircraft analogue or estimate where details remain unknown. The [audit](../audit/F22-Fidelity-Audit.html) contains the underlying comparisons.

The user's current implementation requirement is to remove obsolete production
paths, duplicate simulation owners and compatibility workarounds by migrating
their callers to the shared current contracts. Trace callers before deletion,
preserve saved controls/HUD/recordings through the migration, and verify complete
workflows. Historical evidence and useful regression fixtures remain evidence;
the actual DCS Lua 5.1 and supported native ABI remain host requirements.

## Fix first

| Change | Work item |
| --- | --- |
| Separate the light-command IDs from the AFCS command range; verify light inputs cannot change autopilot state. | [UI-01](#pkg-ui-01) |
| Allow radar cursor control on every display that can host the radar, while retaining the intended global ACM commands. | [UI-01](#pkg-ui-01) |
| Fix heading-entry units and request-correlated acknowledgement, including same-ID waypoint edits and stores entries. | [UI-02](#pkg-ui-02) |
| Separate the countermeasure bank being edited from the bank executed by normal dispense; complete MAN/SEMI/AUTO behavior. | [SEN-08](#pkg-sen-08) |
| Keep release consent, station generation and actual launch/inventory outcomes consistent through rearm, target changes and cancellation. | [SEN-09](#pkg-sen-09) |
| Expire warning-audio authority consistently so a stale warning owner cannot indefinitely suppress seeker tones. | [ALR-02](#pkg-alr-02) |

## Aircraft configuration

| Area | Recommended choice |
| --- | --- |
| Base aircraft | A public-evidence F-22 capability profile with a declared equipment/weapon list. Select later automatic backup oxygen for ordinary operation; make the earlier manual system a historical option. |
| Approach cues | Retain the historically supported 12° normal reference. Treat the 11.5/12.5° fast/slow thresholds, exact glyph geometry and production scheduling as estimates until better evidence exists. |
| AFCS | Use a coherent Hornet-derived relief/coupled-steering workflow. Keep ordinary autopilot disconnect distinct from optional temporary override/recapture and from the chosen autothrottle takeover policy. |
| Countermeasures | Use the existing Hornet-like chaff/flare/repeat/interval schema, with separate editing, selected normal-dispense and direct-access programs. Add the documented F-22 manual, semiautomatic and automatic roles. |
| Radar | Model finite sensing/task service and honest observation age. Label APG-77 schedules, detection performance and degradation parameters as estimates where public evidence does not establish them. |
| Displays | Retain flexible layouts, duplicate formats and the preferred HUD styling. Correct authority, validity, alignment and readability problems. |
| Additional equipment | Put LITENING/Sniper-inspired targeting, HMD, IRDS/IRST and unsupported weapon families behind explicit equipment options. Each needs a complete sensor/control/display/effect chain. |
| Landing automation | Manual field recovery is core. Treat autoland and a selected automatic-GCAS implementation as separate capabilities with their own evidence and host-support requirements. Carrier ACLS is not a baseline F-22 requirement. |

## Implementation order

| Stage | Deliver |
| --- | --- |
| 1. Shared groundwork | Select equipment, settle units and state ownership, define power/repair/rearm/reset behavior, and prove required native interfaces. |
| 2. Aircraft and indications | Fuel/mass, engines, power/SES, hydraulics, FCS, air data and performance; correct the immediate input/entry/alert issues. |
| 3. Navigation and recovery | GINS, altimetry, TACAN/ILS, HUD/on-speed cues, route handling, AFCS and manual recovery. |
| 4. Mission systems | Radar, fusion, IFF/datalink/CNI, EW and countermeasure control. |
| 5. Weapons | Target/program handoff, station readiness, release acknowledgement, bays, seekers, gun and missile-support indications. |
| 6. Selected additions | Complete only the optional equipment chosen for the release profile. |
| 7. Integration | Run the affected normal, limit, failure and recovery cases, then the combined mission. |

Independent work can proceed in parallel. Each item’s expandable details list its actual prerequisites. Early transaction fixes in SEN-09 can start before the complete sensor chain is ready.

## Shared groundwork

<a id="pkg-arc-01"></a>

<a id="pkg-arc-02"></a>
<a id="case-ax02"></a>
<a id="record-p14"></a>

<a id="pkg-arc-03"></a>
<a id="record-c05"></a>
<a id="record-c09"></a>

<a id="pkg-veh-01"></a>
<a id="record-uv36"></a>

<a id="pkg-nav-wp01"></a>

<a id="pkg-sen-01"></a>
<a id="case-ae17"></a>
<a id="record-sc01"></a>
<a id="record-sc35"></a>

- Apply the [project Lua/C++ coding standard](../CODING_STANDARD.md) throughout the overhaul. Use the [implementation chat prompts](../handoffs/README.md) for ownership and starting instructions; radar has its own dedicated chat.
- Use one equipment definition across registration, stores, sensors, cockpit pages and mission defaults. Distinguish installed hardware, development announcements and deliberately simulated additions.
- Give each physical quantity one owner. Separate requested state, achieved state, valid measurement and presentation; declare units, reference frame, sample time and reset behavior.
- Separate physics truth from measured air data and navigation estimates. Keep planned intelligence distinct from live observations, identity evidence and weapon-support authority.
- Correlate commands with accepted results and committed values. A previous equal value or a successful dispatch call cannot acknowledge a new transaction.
- Define cold/hot/air start, page/power changes, pause, repair, rearm, refueling and mission restart once. Clear transient locks and consent; reload preplanned data only through the declared validated-data path.
- Prove native interface support before building dependent controls. Identify the source, DLL, assets and installed bindings used; preserve user bindings, HUD styling and recordings during migration.
- Move physical ownership gradually behind compatible adapters. Avoid two fuel, power, hydraulic or actuator integrators running at once.

Detailed tasks and source anchors for ARC-01, ARC-02, ARC-03, VEH-01, NAV-WP01, SEN-01 are retained in the [backlog](BACKLOG.json).

## Flight model and aircraft systems

Physical implementation and remaining qualification are tracked in the
[vehicle package notes](vehicle-implementation.json), with the provider and
lifecycle contract in [vehicle-state-contract.md](../vehicle-state-contract.md).
Implemented source behavior, estimated calibration and actual DCS qualification
remain separate statuses.

<a id="pkg-veh-02"></a>
<a id="case-pf20"></a>
<a id="case-vg02"></a>
<a id="case-vg03"></a>
<a id="case-vg08"></a>
<a id="case-vg11"></a>
<a id="case-vt01"></a>
<a id="record-uv08"></a>

### VEH-02 — Unify air-data semantics, sensor health and physical coordinates

True atmosphere and motion drive physics; a separately valid sensor frame drives HUD/FCS/AFCS schedules. CAS, EAS, TAS, Mach and signed normal load have explicit meanings.

- Implement a single SI calculation layer that exposes CAS/EAS/TAS/Mach/static/impact pressure and validity; migrate each threshold explicitly instead of changing every EAS gate to CAS by search/replace.
- Instrument level, banked, inverted and ballistic host callbacks to resolve whether body ay includes gravity. Set one documented signed-Nz convention for limiter and presentation; do not subtract/add 1 merely from a generic sensor article.
- Keep body and world wind transforms consistent; run airborne uniform wind/ground-velocity translation invariance at fixed achieved configuration with ground logic disabled.
- Introduce sensor channel states for invalid, frozen and biased inputs without changing true airflow. Feed measured health to selected control reversion and indicate which datum is degraded.
- Characterize native probe heat, ice/rain and weather interfaces. Implement a named estimated heater/test and sensor-degradation abstraction only for effects not already provided; separate sensor freezing from actual ice lift/drag effects.

**Keep:** World/body air-relative velocity subtraction; Compressible HUD/AFCS CAS calculation; Separate ground-speed data for ground operations.

<details>
<summary>Files, dependencies and references</summary>

- `EFM/source/RAPTOR.cpp` — replace duplicated IAS aliases with named quantities
- `EFM/source/Autopilot.h` — consume shared air-data frame
- `Cockpit/Scripts/Systems/HUD_FlightMath.lua` — align formula contract
- `Cockpit/Scripts/Systems/HUD_Flight_Data.lua` — consume valid measured values
- `EFM/source/AirData.h` — proposed shared calculation/state
- `tests/test_airdata_contract.cpp` — proposed analytic and failure fixtures

**Depends on:** [VEH-01](#pkg-veh-01).

**Audit findings:** [PF20](../audit/F22-Fidelity-Audit.html#auth-pf20), [VG02](../audit/F22-Fidelity-Audit.html#auth-vg02), [VG03](../audit/F22-Fidelity-Audit.html#auth-vg03), [VG08](../audit/F22-Fidelity-Audit.html#auth-vg08), [VG11](../audit/F22-Fidelity-Audit.html#auth-vg11), [VT01](../audit/F22-Fidelity-Audit.html#auth-vt01).

**Supporting records:** UV08.

**References:**

- [NASA Glenn, Relative Velocity](https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/relative-velocity/)
- [SBG Systems accelerometer reference](https://support.sbg-systems.com/sc/kb/latest/inertial-measurements-units/accelerometers)
- [SFTE Flight Test Handbook, Pitot Statics](https://society-of-flight-test-engineers.github.io/quarto-handbook/04-pitot-statics.html)
- [Chuck’s DCS F-16CM guide, 17 April 2025](https://chucksguides.com/aircraft/dcs/f-16cm/)
- [Eagle Dynamics DCS F/A-18C Early Access Guide, internally 24 March 2024](https://www.digitalcombatsimulator.com/en/downloads/documentation/)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Analytic pitot samples from subsonic through supersonic conditions agree across HUD, AFCS and code; declared configuration gates use the same named quantity. |
| Limit | Invalid pressure, speed-of-sound and nonfinite data invalidate the relevant channel; wind-translation invariance applies only airborne at fixed configuration. |
| Failure | Frozen probe/sensor data changes indications/control availability while force generation continues to use true air state; no double icing effect. |
| Recovery | Heater/source restoration changes sensor state using labelled estimated recovery, with stable transfer to normal control and no hidden trim impulse. |

</details>

<a id="pkg-veh-03"></a>
<a id="case-av08"></a>
<a id="case-av12"></a>
<a id="case-av20"></a>
<a id="case-av21"></a>
<a id="case-av22"></a>
<a id="case-av23"></a>
<a id="case-av35"></a>
<a id="case-vg01"></a>
<a id="record-v11"></a>
<a id="record-v12"></a>
<a id="record-v13"></a>
<a id="record-uv02"></a>
<a id="record-uv09"></a>
<a id="record-uv14"></a>
<a id="record-uv15"></a>
<a id="record-uv16"></a>
<a id="record-uv17"></a>

### VEH-03 — Build the fuel supply and mass transaction model

Fuel is conserved by location and supply path. Installed tanks survive empty contents, combustion and auxiliaries draw finite fuel, and refuel/rearm transactions update mass once.

- Keep authoritative total fuel while adding tank identity separately from quantity; distinguish an empty attached tank from an explicitly removed station using observed inventory evidence.
- Represent the documented feed/transfer roles with configurable cell groups, pressure/transfer paths, usable quantity, pump health, engine/APU/SES draw and rejected overflow. Do not adopt the inconsistent rescue-table capacities.
- Stage topology numerics: first preserve aggregate capacity and total ledger; then allocate group capacities/locations from public geometry or explicitly estimated configuration. Record unresolved splits instead of claiming recovered production values.
- Separate fuel requested, fuel delivered, main-burner flow and augmentation flow; charge fuel for burning start phases and APU/SES operation, and distinguish indicated flow from total mass burn.
- Add pilot-set bingo and feed-specific low-supply states with warning-owner handoff; exact F-22 thresholds remain configuration decisions, not Hornet values.
- Make burn/refill positions follow fixed configured cell geometry; verify DCS mass/CG/inertia callback behavior before emitting additional MOI contributions. Remove CG-following aerodynamic reference points in the performance package only after its moment-arm check.
- After hydraulic and bleed providers exist, connect boost/pressurization availability to delivery. Prevent total external quantity from directly feeding an isolated engine.

**Keep:** 8,200 kg internal simulation capacity consistent with rounded public figure; Bounded per-station external amounts and host-reported station IDs; Incremental refuel quantities and mass-change queue.

<details>
<summary>Files, dependencies and references</summary>

- `EFM/source/RAPTOR.cpp` — extract burn/refuel/host callbacks into one ledger
- `EFM/source/RAPTOR.h` — replace lump-only runtime state with configured roles
- `VLO Fuel Tank.lua` — retain installed tank definition and capacity provenance
- `Cockpit/Scripts/Systems/Avionics.lua` — consume owned fuel/advisory values
- `Cockpit/Scripts/Systems/MFD_System.lua` — consume group/feed/flow states
- `EFM/source/FuelSystem.h` — proposed model
- `tests/test_fuel_transactions.cpp` — proposed conservation tests

**Depends on:** [VEH-01](#pkg-veh-01), [VEH-02](#pkg-veh-02).

**Audit findings:** [AV08](../audit/F22-Fidelity-Audit.html#auth-av08), [AV12](../audit/F22-Fidelity-Audit.html#auth-av12), [AV20](../audit/F22-Fidelity-Audit.html#auth-av20), [AV21](../audit/F22-Fidelity-Audit.html#auth-av21), [AV22](../audit/F22-Fidelity-Audit.html#auth-av22), [AV23](../audit/F22-Fidelity-Audit.html#auth-av23), [AV35](../audit/F22-Fidelity-Audit.html#auth-av35), [VG01](../audit/F22-Fidelity-Audit.html#auth-vg01).

**Supporting records:** V11, V12, V13, UV02, UV09, UV14, UV15, UV16, UV17.

**References:**

- [Eaton F/A-22 capabilities brochure, April 2014](https://www.eaton.com/content/dam/eaton/markets/aerospace/Lockheed-Martin-Boeing-FA22-Raptor-capabilities-brochure.pdf)
- [USAF T.O. 00-105E-9, F-22 section, 1 February 2006](https://www.0x4d.net/files/AF1/R11%20Segment%2012.pdf)
- [USAF F-22 Raptor fact sheet](https://www.af.mil/About-Us/Fact-Sheets/Display/Article/104506/f-22-raptor/About-Us/f-22-raptor/)
- [NASA, William H. Phillips, Journey in Aeronautical Research, 2005](https://www.nasa.gov/wp-content/uploads/2023/04/sp-4540.pdf)
- [Chuck’s DCS F-16CM guide, 17 April 2025](https://chucksguides.com/aircraft/dcs/f-16cm/)
- [Chuck’s DCS F/A-18C guide, 25 April 2025](https://chucksguides.com/aircraft/dcs/fa-18c/)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | For start/run/APU/refuel scenarios, initial quantity + accepted additions - actual delivered consumption - explicit losses equals final quantity and queued host mass transactions. |
| Limit | Full/empty/partial tanks, asymmetric depletion, overfill and near-unusable fuel never create negative mass or fill removed stations. |
| Failure | Transfer/pressure/pump failure can starve a feed path with fuel still elsewhere; loss is indicated distinctly from total low/bingo. |
| Recovery | Restored transfer refills the correct feed path; refuel does not start an engine or repair a leak; empty attached tanks can be refilled after host identity is verified. |

</details>

<a id="pkg-veh-04"></a>
<a id="case-av02"></a>
<a id="case-av06"></a>
<a id="case-av14"></a>
<a id="case-av15"></a>
<a id="case-av31"></a>
<a id="case-vt05"></a>
<a id="record-v14"></a>
<a id="record-v15"></a>
<a id="record-uv01"></a>
<a id="record-uv03"></a>
<a id="record-uv04"></a>
<a id="record-uv05"></a>
<a id="record-uv06"></a>

### VEH-04 — Make battery, generator, APU and SES supplies functional

Battery/charger, engine generators, GPU, APU services and SES are distinct finite sources. The documented ground APU roles can supply declared consumers with engines stopped.

- Create a bus/load table for flight-control, essential indication, start controls, lights, fuel transfer and ECS consumers; assign only documented or explicitly estimated connections. Retain legacy MAIN_POWER/BATTERY_POWER outputs as derived compatibility values.
- Migrate battery/SOC and generator availability to the EFM physical owner in one cutover; Lua publishes requests and consumes availability, so cockpit update frequency cannot drain a second battery.
- Give APU ground electrical, hydraulic and conditioned-air service outputs distinct capacity/eligibility states. Keep a limited ground-service assumption, not full aircraft generator equivalence.
- Add finite SES air/fuel availability, recharge/servicing requests and declared dependencies for APU start, doors and alternate gear. Use normalized quantities until capacities are sourced; no Hornet hydraulic accumulator transplant.
- Choose an explicit estimated automatic APU shutdown policy and make its conditions match the comment/UI. Initial compatibility policy requires both generators and both engines continuously qualified for 60 seconds; mark this timer as a DCS-derived estimate, not F-22 documentation.
- Add abort/fault/reset/restart behavior, load shedding and source-transfer consequences. Keep cold-soak readiness a configurable estimate pending evidence; do not impose a universal preheat time.

**Keep:** Finite battery reserve and generator hysteresis; Requested switch state already differs from measured availability; Hot-start native power toggle fix.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/Engine_System.lua` — retain input/sound/cart adapter; migrate supply integration once
- `Cockpit/Scripts/Systems/Electrical_Computer.lua` — retain compatibility wrapper then retire duplicate physical integration
- `EFM/source/RAPTOR.cpp` — consume/publish one physical power snapshot
- `EFM/source/PowerSystem.h` — proposed model
- `EFM/source/AuxiliaryPower.h` — proposed SES/APU model
- `tests/test_vehicle_electrical.py` — retain adapter regression
- `tests/test_power_sources.cpp` — proposed physical tests

**Depends on:** [VEH-01](#pkg-veh-01), [VEH-03](#pkg-veh-03).

- Integration: CNI-01 and other consumers supply declared instance/load requirements; this is a load-table completion gate, not a reverse hard dependency for basic power integration.

**Audit findings:** [AV02](../audit/F22-Fidelity-Audit.html#auth-av02), [AV06](../audit/F22-Fidelity-Audit.html#auth-av06), [AV14](../audit/F22-Fidelity-Audit.html#auth-av14), [AV15](../audit/F22-Fidelity-Audit.html#auth-av15), [AV31](../audit/F22-Fidelity-Audit.html#auth-av31), [VT05](../audit/F22-Fidelity-Audit.html#auth-vt05).

**Supporting records:** V14, V15, UV01, UV03, UV04, UV05, UV06.

**References:**

- [Eaton F/A-22 capabilities brochure, April 2014](https://www.eaton.com/content/dam/eaton/markets/aerospace/Lockheed-Martin-Boeing-FA22-Raptor-capabilities-brochure.pdf)
- [USAF T.O. 00-105E-9, F-22 section, 1 February 2006](https://www.0x4d.net/files/AF1/R11%20Segment%2012.pdf)
- [USAF Scientific Advisory Board, Aircraft Oxygen Generation, SAB-TR-11-04, 1 February 2012](https://www.airandspaceforces.com/PDF/DocumentFile/Documents/2012/AFSAB_Oxygen_020112.pdf)
- [Eagle Dynamics DCS F/A-18C Early Access Guide, internally 24 March 2024](https://www.digitalcombatsimulator.com/en/downloads/documentation/)
- [USAF FY2009 MILCON shelter justification](https://www.saffm.hq.af.mil/Portals/84/documents/FY09/AFD-080204-065.pdf?ver=2016-08-22-141510-773)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Engines off/APU ready can power each declared ground consumer; GPU, generator and battery transitions publish availability and loads coherently. |
| Limit | Finite SOC/SES resources deplete under demand and recharge only from declared sources; threshold hysteresis prevents chatter. |
| Failure | Battery, generator, APU and source-transfer faults remove the intended consumers while alternate declared supplies survive; one generator cannot qualify a both-generator timer. |
| Recovery | Restoring GPU or servicing reserves permits valid restart; power restoration alone does not erase mechanical damage or reset every display mode. |

</details>

<a id="pkg-veh-05"></a>
<a id="case-av16"></a>
<a id="case-av17"></a>
<a id="case-av18"></a>
<a id="case-av19"></a>
<a id="case-av30"></a>
<a id="case-av32"></a>
<a id="case-av37"></a>
<a id="case-pf22"></a>
<a id="record-v08"></a>
<a id="record-v09"></a>
<a id="record-v10"></a>
<a id="record-uv10"></a>
<a id="record-uv11"></a>
<a id="record-uv12"></a>
<a id="record-uv13"></a>
<a id="record-uv30"></a>

### VEH-05 — Replace timer-only engine operation with causal engine states

Each engine separates shaft motion, starter source, fuel/ignition, combustion, augmentation, lubrication, control health and fire isolation; indications reflect the achieved physical state.

- Define OFF, CRANKING, LIGHTING, ACCELERATING, RUNNING, SHUTTING_DOWN and WINDMILLING states with source prerequisites; all keyboard/click/automatic requests enter the same authoritative guards.
- Separate start source from fuel introduction; use public F-22 evidence where available and a clearly documented DCS-analogue pilot sequence where unknown. Do not assert a Viper cranking RPM is F119 data.
- Charge ignition/start and AB fuel from actual combustion state; synchronize augmentation fuel, lightoff, thrust and nozzle state, while distinguishing total burn from selected instrument flow.
- Add air-driven rotor/windmill behavior and source-assisted restart with a tunable admissible envelope; do not implement identical 44-second ground and airborne starts as the final model.
- Keep finite lags as initial estimates, then link oil/temperature rise, delay/hysteresis, dry/hung/hot start and flameout outcomes. Add FADEC availability/diagnostic states with intentional recovery paths.
- Implement documented engine fire selection isolation of fuel/electric/ventilation/air, followed by separate ready/discharge inventory. Keep detector, isolation command and extinguishing result distinct; do not let a warning argument cause a fire.
- Resolve the nozzle actuator supply as an explicit decision using Eaton fueldraulics and further public evidence; preserve independent achieved TVC but do not claim the current aircraft-hydraulic side map is authenticated.

**Keep:** Independent left/right spool, temperature, oil and nozzle states; Physical engine/core exports and Engine_Data fallback; No combustion thrust after cutoff.

<details>
<summary>Files, dependencies and references</summary>

- `EFM/source/RAPTOR.cpp` — extract two duplicated engine state machines
- `EFM/source/VehicleSystems.h` — retain lag helpers and instrument state until replaced
- `Cockpit/Scripts/Systems/Engine_Data.lua` — add per-value validity and quantity semantics
- `Cockpit/Scripts/Systems/Engine_System.lua` — map start/cutoff commands to requests
- `Cockpit/Scripts/Systems/MFD_System.lua` — consume warning/limit states instead of display-local thresholds
- `EFM/source/EngineModel.h` — proposed two-instance model
- `EFM/source/EngineProtection.h` — proposed bounded simulation protection

**Depends on:** [VEH-01](#pkg-veh-01), [VEH-02](#pkg-veh-02), [VEH-03](#pkg-veh-03), [VEH-04](#pkg-veh-04).

**Audit findings:** [AV16](../audit/F22-Fidelity-Audit.html#auth-av16), [AV17](../audit/F22-Fidelity-Audit.html#auth-av17), [AV18](../audit/F22-Fidelity-Audit.html#auth-av18), [AV19](../audit/F22-Fidelity-Audit.html#auth-av19), [AV30](../audit/F22-Fidelity-Audit.html#auth-av30), [AV32](../audit/F22-Fidelity-Audit.html#auth-av32), [AV37](../audit/F22-Fidelity-Audit.html#auth-av37), [PF22](../audit/F22-Fidelity-Audit.html#auth-pf22).

**Supporting records:** V08, V09, V10, UV10, UV11, UV12, UV13, UV30.

**References:**

- [Pratt & Whitney F119](https://www.rtx.com/prattwhitney/products/military-engines/f119)
- [Eaton F/A-22 capabilities brochure, April 2014](https://www.eaton.com/content/dam/eaton/markets/aerospace/Lockheed-Martin-Boeing-FA22-Raptor-capabilities-brochure.pdf)
- [USAF T.O. 00-105E-9, F-22 section, 1 February 2006](https://www.0x4d.net/files/AF1/R11%20Segment%2012.pdf)
- [Chuck’s DCS F-16CM guide, 17 April 2025](https://chucksguides.com/aircraft/dcs/f-16cm/)
- [Chuck’s DCS F/A-18C guide, 25 April 2025](https://chucksguides.com/aircraft/dcs/fa-18c/)
- [Eagle Dynamics DCS F/A-18C Early Access Guide, internally 24 March 2024](https://www.digitalcombatsimulator.com/en/downloads/documentation/)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Cold start, cutoff, restart and independent throttle commands produce coherent core/fan/temperature/oil/fuel/nozzle indications and conserved fuel. |
| Limit | Throttle step and AB transitions have finite response; temperature/oil limits use labelled parameters and no false precision from F404/F110 decks. |
| Failure | No starter/ignition/fuel/source prevents the relevant transition; dry crank, hung start, AB failure and one-engine loss are distinguishable, with no thrust from a failed combustion path. |
| Recovery | Cutoff/abort allows the configured cooling/purge/restart path; fire discharge is finite and not replenished by a caution reset; repair does not automatically start the engine. |

</details>

<a id="pkg-veh-06"></a>
<a id="case-av03"></a>
<a id="case-av04"></a>
<a id="case-av05"></a>
<a id="record-v16"></a>
<a id="record-uv18"></a>

### VEH-06 — Model hydraulic sources, consumer segregation and stored fluid

Pump source status, circuit pressure/flow availability, routed consumer supply and accumulator energy are distinct; loss of one source has the correct declared survival behavior.

- Represent four main pump source statuses and an APU pump source, while retaining two logical independent system inventories. Separate pump rating/regulation from downstream pressure indication; do not change 3,950 psi solely to match a 4,100 psi component rating.
- Create a documented consumer routing table: normal utility/maintenance-switch distinction, rudder shuttle and other proved paths; mark incomplete mapping as simulation assumption rather than inferring a full schematic.
- Add bounded flow demand/pressure recovery or equivalent reduced-order capacity so simultaneous actuation and pump loss differ from static no-load pressure.
- Give reserve states pressure/fluid-volume roles and intentional leakage/recharge. Add the documented emergency tow-brake supply as a ground-service path, without forcing it to be the normal parking-brake architecture.
- Route each actuator’s command, power, available pressure, achieved position and fault separately. Couple fuel boost, gear and bay-door demand through interfaces owned by their respective packages.
- Use the nozzle-source decision from VEH-05 before changing TVC supply; retain a labelled temporary mapping if evidence remains incomplete.

**Keep:** Two achieved pressure indications already share EFM ownership with actuator authority; Rudder survives a healthy alternate source in the existing abstraction; Separate nozzle achieved states.

<details>
<summary>Files, dependencies and references</summary>

- `EFM/source/VehicleSystems.h` — extract Hydraulics into proposed HydraulicSystem.h
- `EFM/source/RAPTOR.cpp` — replace blanket shared availability at named consumers
- `Cockpit/Scripts/Systems/MFD_System.lua` — keep achieved indication consumption
- `EFM/source/HydraulicSystem.h` — proposed circuit/pump/consumer model
- `tests/test_vehicle_systems.cpp` — extend failure/demand cases

**Depends on:** [VEH-01](#pkg-veh-01), [VEH-04](#pkg-veh-04), [VEH-05](#pkg-veh-05).

**Audit findings:** [AV03](../audit/F22-Fidelity-Audit.html#auth-av03), [AV04](../audit/F22-Fidelity-Audit.html#auth-av04), [AV05](../audit/F22-Fidelity-Audit.html#auth-av05).

**Supporting records:** V16, UV18.

**References:**

- [Eaton F/A-22 capabilities brochure, April 2014](https://www.eaton.com/content/dam/eaton/markets/aerospace/Lockheed-Martin-Boeing-FA22-Raptor-capabilities-brochure.pdf)
- [USAF T.O. 00-105E-9, F-22 section, 1 February 2006](https://www.0x4d.net/files/AF1/R11%20Segment%2012.pdf)
- [Eagle Dynamics DCS F/A-18C Early Access Guide, internally 24 March 2024](https://www.digitalcombatsimulator.com/en/downloads/documentation/)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | No-load indication, pump availability and achieved actuator rates remain coherent; rudder retains the documented alternative-system survival behavior. |
| Limit | Simultaneous consumers and partial pump loss change capacity/rate without an instantaneous arbitrary all-consumer failure. |
| Failure | A circuit leak, pump depressurization, bus loss and actuator jam are distinct; a low-pressure warning is never fed back as a failed pump. |
| Recovery | Leak isolation or restored pumps recharge only healthy circuits/reserves; held or jammed surfaces recover according to the declared fault model. |

</details>

<a id="pkg-veh-07"></a>
<a id="case-av01"></a>
<a id="case-av27"></a>
<a id="case-av28"></a>
<a id="case-pf12"></a>
<a id="case-pf15"></a>
<a id="case-pf16"></a>
<a id="case-pf21"></a>
<a id="case-vg04"></a>
<a id="case-vg05"></a>
<a id="case-vg12"></a>
<a id="record-v01"></a>
<a id="record-v02"></a>
<a id="record-v03"></a>
<a id="record-v04"></a>
<a id="record-uv27"></a>
<a id="record-uv28"></a>
<a id="record-uv29"></a>

### VEH-07 — Make FCS configuration and achieved surface mixing explicit

Pilot intent, control mode, rate/load/AoA protection, allocation, power/supply and achieved surfaces form one chain; cruise, approach/refuel and engine-out configuration can differ.

- Define explicit CRUISE, POWER_APPROACH and REFUEL modes with source-tagged entry/exit logic; keep eligibility, mode and failed-system reversion distinct from AP engagement.
- Replace common speed-brake proxy commands with a mix that connects selected configuration to individual achieved surfaces and drag. Use the historical F-22 mix as the public best-known reference, with production applicability explicitly limited.
- Add an explicit single-engine approach configuration and cue reference shared by FCS/HUD/ATC consumers. Historical numerical choices remain profile parameters, not a claim of today’s automatic selection logic.
- Replace independent collective/differential clipping with an intentional bounded allocation policy. Initial estimate prioritizes pitch stabilization/protection, then pilot roll within residual authority; record tradeoff and test sign reversal/saturation.
- Implement a labelled rate/load/AoA command abstraction and configuration/weight-aware bounds without copying Hornet G numbers; do not claim the proprietary F-22 law has been recovered.
- Separate manual trim inhibit from AP disconnect, FCS resettable faults from structural loss, and any pilot override from equipment failure. Preserve existing trim rates until handling calibration supports a change.
- Coordinate approach law, E-bracket reference and optional ATC authority with navigation lane; manual approach is required, automatic landing is not assumed from analogue systems.

**Keep:** Pitch-only TVC and 20-degree physical bound; Elapsed-time held trim with release handoff; Achieved surface positions drive forces and drawings.

<details>
<summary>Files, dependencies and references</summary>

- `EFM/source/RAPTOR.cpp` — extract FCS laws and allocation from simulate
- `EFM/source/TrimControl.h` — retain controller; add inhibit contract
- `EFM/source/Autopilot.h` — preserve AFCS separation; coordinate with navigation owner
- `Cockpit/Scripts/Systems/HUD_Flight_Data.lua` — consume selected approach reference
- `EFM/source/FlightControls.h` — proposed mode/law controller
- `EFM/source/ControlAllocation.h` — proposed achieved effector allocation

**Depends on:** [VEH-01](#pkg-veh-01), [VEH-02](#pkg-veh-02), [VEH-05](#pkg-veh-05), [VEH-06](#pkg-veh-06).

**Audit findings:** [AV01](../audit/F22-Fidelity-Audit.html#auth-av01), [AV27](../audit/F22-Fidelity-Audit.html#auth-av27), [AV28](../audit/F22-Fidelity-Audit.html#auth-av28), [PF12](../audit/F22-Fidelity-Audit.html#auth-pf12), [PF15](../audit/F22-Fidelity-Audit.html#auth-pf15), [PF16](../audit/F22-Fidelity-Audit.html#auth-pf16), [PF21](../audit/F22-Fidelity-Audit.html#auth-pf21), [VG04](../audit/F22-Fidelity-Audit.html#auth-vg04), [VG05](../audit/F22-Fidelity-Audit.html#auth-vg05), [VG12](../audit/F22-Fidelity-Audit.html#auth-vg12).

**Supporting records:** V01, V02, V03, V04, UV27, UV28, UV29.

**References:**

- [Pratt & Whitney F119](https://www.rtx.com/prattwhitney/products/military-engines/f119)
- [Rainey and Kohn, F-22 flight-test program update, 1998](https://man.fas.org/dod-101/sys/ac/docs/f-22-emd-paper.htm)
- [Chuck’s DCS F-16CM guide, 17 April 2025](https://chucksguides.com/aircraft/dcs/f-16cm/)
- [Chuck’s DCS F/A-18C guide, 25 April 2025](https://chucksguides.com/aircraft/dcs/fa-18c/)
- [Eagle Dynamics DCS F/A-18C Early Access Guide, internally 24 March 2024](https://www.digitalcombatsimulator.com/en/downloads/documentation/)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Transitions between declared modes preserve trim and achieved position continuity; selected approach reference agrees across all cues. |
| Limit | Combined pitch/roll at saturation, high AoA and rapid configuration changes respect physical actuator bounds and an explicit priority policy. |
| Failure | Engine/source loss changes only the supported mode/authority; invalid air data chooses a declared degraded response, not true-state replacement. |
| Recovery | Trim release, resettable FCS reset and recovered supply restore the right functions without healing a jam or structural damage. |

</details>

<a id="pkg-veh-08"></a>
<a id="case-av13"></a>
<a id="case-pf01"></a>
<a id="case-pf02"></a>
<a id="case-pf03"></a>
<a id="case-pf04"></a>
<a id="case-pf05"></a>
<a id="case-pf06"></a>
<a id="case-pf07"></a>
<a id="case-pf08"></a>
<a id="case-pf09"></a>
<a id="case-pf10"></a>
<a id="case-pf11"></a>
<a id="case-pf13"></a>
<a id="case-pf14"></a>
<a id="case-pf17"></a>
<a id="case-pf19"></a>
<a id="record-v05"></a>
<a id="record-v06"></a>
<a id="record-v07"></a>
<a id="record-v20"></a>

### VEH-08 — Calibrate one coherent flight-performance model

Lift, drag, moments, thrust, mass and fuel burn explain performance together over declared conditions. Public F-22 bounds and physical consistency are separate from unknown numerical curves.

**Current issue ([PF07](../audit/F22-Fidelity-Audit.html#auth-pf07)):** The wing-force component is automatically recentered with mass CG instead of retaining an airframe-fixed reference. Other engine/tail force arms still provide some CG response; this is not a claim that all CG effects are absent.

- Publish the calibration grid and source tiers before tuning: mass/CG/loadout, altitude, temperature, Mach, AoA, configuration, throttle and engine health. Preserve old archived flights only with their original build/configuration labels.
- Remove unexplained high-Mach zero entries as accidental interpolation targets only after declaring a valid modeled envelope and a bounded nonzero extrapolation/decay policy. Do not replace them with invented F119 production thrust values.
- Fit dry/AB installed thrust, acceleration, sustained climb, transonic drag, steady level flight and fuel burn jointly. Public thrust class and dry supersonic capability supply loose bounds, not a unique performance deck.
- Use fixed airframe aerodynamic reference locations and explicit AoA/configuration-dependent center-of-pressure shifts; compare CG shifts at fixed force state. Verify host inertia response before adding point-mass inertia.
- Calibrate lift/drag across approach weight, maneuver load and configuration; retain useful AoA drag until data show how to replace it. External-store/open-bay drag must be host-qualified to avoid double counting.
- Validate high-alpha/post-stall force continuity, damping, sideslip/roll-yaw response, departure resistance and recovery qualitatively; numerical handling curves remain estimates where public data do not resolve them.
- Characterize host ground effect and wheel load. If absent, add one bounded height-dependent reduced-order term and calibrate flare/touchdown interaction; no duplicate ground effect.
- Report instantaneous versus sustained turn, transient versus sustained supersonic flight, and available versus commanded G distinctly. Do not turn unmeasured curves into a blanket inaccurate-FM verdict.

**Keep:** Existing continuous high-alpha correction is useful numerical regularization; Smooth airspeed-based installed-thrust blend avoids WOW force jump; AoA-dependent drag already creates lifting energy cost.

<details>
<summary>Files, dependencies and references</summary>

- `EFM/source/RAPTOR.h` — version coefficient and thrust tables with provenance
- `EFM/source/RAPTOR.cpp` — extract force/moment and installed-thrust calculation
- `EFM/source/HighAlpha.h` — retain continuity; calibrate effect separately
- `EFM/source/Aerodynamics.h` — proposed coefficient evaluation
- `EFM/source/PropulsionDeck.h` — proposed calibrated installed-force model
- `tests/test_performance_relations.cpp` — proposed physical-relationship tests

**Depends on:** [VEH-02](#pkg-veh-02), [VEH-03](#pkg-veh-03), [VEH-05](#pkg-veh-05), [VEH-07](#pkg-veh-07).

**Audit findings:** [AV13](../audit/F22-Fidelity-Audit.html#auth-av13), [PF01](../audit/F22-Fidelity-Audit.html#auth-pf01), [PF02](../audit/F22-Fidelity-Audit.html#auth-pf02), [PF03](../audit/F22-Fidelity-Audit.html#auth-pf03), [PF04](../audit/F22-Fidelity-Audit.html#auth-pf04), [PF05](../audit/F22-Fidelity-Audit.html#auth-pf05), [PF06](../audit/F22-Fidelity-Audit.html#auth-pf06), [PF07](../audit/F22-Fidelity-Audit.html#auth-pf07), [PF08](../audit/F22-Fidelity-Audit.html#auth-pf08), [PF09](../audit/F22-Fidelity-Audit.html#auth-pf09), [PF10](../audit/F22-Fidelity-Audit.html#auth-pf10), [PF11](../audit/F22-Fidelity-Audit.html#auth-pf11), [PF13](../audit/F22-Fidelity-Audit.html#auth-pf13), [PF14](../audit/F22-Fidelity-Audit.html#auth-pf14), [PF17](../audit/F22-Fidelity-Audit.html#auth-pf17), [PF19](../audit/F22-Fidelity-Audit.html#auth-pf19).

**Supporting records:** V05, V06, V07, V20.

**References:**

- [Pratt & Whitney F119](https://www.rtx.com/prattwhitney/products/military-engines/f119)
- [USAF F-22 Raptor fact sheet](https://www.af.mil/About-Us/Fact-Sheets/Display/Article/104506/f-22-raptor/About-Us/f-22-raptor/)
- [USAF supercruise announcement, 21 July 1999](https://man.fas.org/dod-101/sys/ac/docs/n19990721_991378.htm)
- [Lee and Peron, F-22 high-AoA testing, May 2000](https://sfte-ec.org/sfteecold/data/Abstract/A2000-II-02.pdf)
- [NASA Glenn, Relative Velocity](https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/relative-velocity/)
- [NASA, William H. Phillips, Journey in Aeronautical Research, 2005](https://www.nasa.gov/wp-content/uploads/2023/04/sp-4540.pdf)
- [FAA Pilot’s Handbook, chapter 5](https://www.faa.gov/sites/faa.gov/files/regulations_policies/handbooks_manuals/aviation/phak/07_phak_ch5.pdf)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | At fixed configuration/AoA, more mass requires higher dynamic pressure for equilibrium; energy rate agrees with net force/power and consumed fuel. |
| Limit | Table boundaries, Mach transitions, near-zero/backward relative velocity and high-alpha endpoints remain finite and continuous inside the declared numerical envelope. |
| Failure | One-engine thrust/TVC asymmetry, damaged surfaces and changed mass alter the appropriate forces/moments without a hidden compensating assist. |
| Recovery | Recovery to ordinary flight from saturated/high-alpha/engine-out conditions is stable within declared simulation conditions; unsupported real-aircraft envelope claims remain ungraded. |

</details>

<a id="pkg-veh-09"></a>
<a id="case-av07"></a>
<a id="case-av25"></a>
<a id="case-av26"></a>
<a id="case-av33"></a>
<a id="record-uv21"></a>
<a id="record-uv22"></a>
<a id="record-uv23"></a>

### VEH-09 — Complete gear, steering and arresting-gear physical workflows

Gear requests, doors, struts, locks, WOW, steering and pneumatic emergency/recovery hardware have coherent commanded and achieved states.

- Capture model/EDM door and leg motion against the existing scalar first. Add separate physical phases/locks/asymmetric states only where required; do not assume missing door variables prove wrong visual motion.
- Make toggle, explicit up and explicit down use one request guard with WOW and declared speed-limit semantics. Replace the hidden minimum-speed asymmetry with an explicit estimated policy plus rejection reason.
- Introduce normal and SES-air alternate extension, resource use and unsafe/locked indication. Do not import Hornet rotate/pull controls or assume pneumatic supply excludes gravity/aerodynamic assistance.
- Add explicit steering selection/status and a continuous estimated speed/pressure authority schedule. Keep pedal yaw and steering demands separate across liftoff/touchdown.
- Implement the documented pneumatically commanded arresting-gear extend/retract workflow, supply limitation and cockpit state. Qualify DCS ground-cable interaction before claiming arrestment performance.

**Keep:** Native suspension compression preferred over altitude fallback; Unbraked nosewheel and independent main-wheel exports; Existing animation mapping can be retained if EDM phases already sequence correctly.

<details>
<summary>Files, dependencies and references</summary>

- `EFM/source/RAPTOR.cpp` — replace common gear/steering guards with named state machine
- `FM/config.lua` — retain host contact model; calibrate ground properties
- `Cockpit/Scripts/Systems/Engine_System.lua` — gear input adapter
- `Cockpit/Scripts/Systems/Avionics.lua` — consume gear/steering status
- `EFM/source/LandingGear.h` — proposed independent lock/sequence model
- `EFM/source/GroundControl.h` — proposed steering/hook state

**Depends on:** [VEH-01](#pkg-veh-01), [VEH-02](#pkg-veh-02), [VEH-04](#pkg-veh-04), [VEH-06](#pkg-veh-06).

**Audit findings:** [AV07](../audit/F22-Fidelity-Audit.html#auth-av07), [AV25](../audit/F22-Fidelity-Audit.html#auth-av25), [AV26](../audit/F22-Fidelity-Audit.html#auth-av26), [AV33](../audit/F22-Fidelity-Audit.html#auth-av33).

**Supporting records:** UV21, UV22, UV23.

**References:**

- [Eaton F/A-22 capabilities brochure, April 2014](https://www.eaton.com/content/dam/eaton/markets/aerospace/Lockheed-Martin-Boeing-FA22-Raptor-capabilities-brochure.pdf)
- [USAF T.O. 00-105E-9, F-22 section, 1 February 2006](https://www.0x4d.net/files/AF1/R11%20Segment%2012.pdf)
- [Eagle Dynamics DCS F/A-18C Early Access Guide, internally 24 March 2024](https://www.digitalcombatsimulator.com/en/downloads/documentation/)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Normal gear transit, down/up lock indication, taxi steering and commanded hook motion follow achieved states and supply. |
| Limit | Low-speed requests, WOW bounce, partial gear transit and speed-gate boundaries behave consistently across bindings without gear/steering jumps. |
| Failure | One leg/door jam, SES loss, hydraulic failure and sensor failure produce distinct unsafe states; no aggregate scalar falsely reports all locked. |
| Recovery | Alternate extension or restored healthy source reaches the defined lock path; retraction after emergency action follows a documented simulation policy. |

</details>

<a id="pkg-veh-10"></a>
<a id="case-av09"></a>
<a id="case-av24"></a>
<a id="case-av34"></a>
<a id="case-pf18"></a>
<a id="case-vg07"></a>
<a id="case-vg09"></a>
<a id="record-v17"></a>
<a id="record-uv19"></a>
<a id="record-uv20"></a>
<a id="record-uv24"></a>
<a id="record-uv25"></a>
<a id="record-uv26"></a>

### VEH-10 — Replace brake assistance with a declared brake/thermal chain

Pedal demand commands a declared deceleration response through one brake authority; wheel slip, reference motion, supply, brake energy and tire condition remain distinct.

- Characterize host wheel speed/anti-skid, touchdown spin-up protection, friction, brake torque and tire thermal/failure behavior with controlled runway tests; choose either native wheel limiting or custom wheel limiting, never both independently.
- Add a reduced-order deceleration demand controller with separate left/right inputs, measured/navigation reference health and wheel-slip limiting through the supported interface. Treat historical delta-deceleration intent as guidance, not the old deadband defect.
- Replace the +0.60 aerodynamic drag step with physically attributed wheel torque and actual commanded surface drag. Keep baseline stop capability until replacement traces justify the cutover.
- Separate fluid consumed by applications/leakage from energy dissipated at the wheels. Accumulator display must correspond to a defined stored-pressure state.
- Implement parking set/release/pressure-qualified status and emergency mode as declared simulation choices. Do not copy an unresolved Viper RPM release threshold or Hornet anti-skid thresholds as F-22 facts.
- Add finite per-wheel thermal energy, cooling/heat soak, fade and tire consequence only for portions not already host-owned. Use estimated parameters, no rescue waiting time as a real thermal coefficient.

**Keep:** Proportional left/right demands and no nose brake; Enabled native anti-skid may already provide valuable wheel-level control; Finite reserve behavior is a starting point.

<details>
<summary>Files, dependencies and references</summary>

- `EFM/source/RAPTOR.cpp` — remove unexplained drag assistance after equivalent braking is validated
- `EFM/source/VehicleSystems.h` — separate hydraulic reserve from brake heating
- `Cockpit/Scripts/Systems/Engine_System.lua` — make parking commands idempotent and mode-aware
- `FM/config.lua` — qualify host brake/rolling/contact values
- `EFM/source/BrakeSystem.h` — proposed controller/reserve/thermal model
- `tests/test_brake_system.cpp` — proposed controller and energy fixtures

**Depends on:** [VEH-02](#pkg-veh-02), [VEH-05](#pkg-veh-05), [VEH-06](#pkg-veh-06), [VEH-09](#pkg-veh-09).

**Audit findings:** [AV09](../audit/F22-Fidelity-Audit.html#auth-av09), [AV24](../audit/F22-Fidelity-Audit.html#auth-av24), [AV34](../audit/F22-Fidelity-Audit.html#auth-av34), [PF18](../audit/F22-Fidelity-Audit.html#auth-pf18), [VG07](../audit/F22-Fidelity-Audit.html#auth-vg07), [VG09](../audit/F22-Fidelity-Audit.html#auth-vg09).

**Supporting records:** V17, UV19, UV20, UV24, UV25, UV26.

**References:**

- [Eaton F/A-22 capabilities brochure, April 2014](https://www.eaton.com/content/dam/eaton/markets/aerospace/Lockheed-Martin-Boeing-FA22-Raptor-capabilities-brochure.pdf)
- [Rainey and Kohn, F-22 flight-test program update, 1998](https://man.fas.org/dod-101/sys/ac/docs/f-22-emd-paper.htm)
- [USAF T.O. 00-105E-9, F-22 section, 1 February 2006](https://www.0x4d.net/files/AF1/R11%20Segment%2012.pdf)
- [USAF F-22 cold-weather brake test, 29 November 2007](https://www.af.mil/News/Article-Display/Article/125003/f-22-endures-3-week-cold-weather-test-at-eielson/)
- [Eagle Dynamics DCS F/A-18C Early Access Guide, internally 24 March 2024](https://www.digitalcombatsimulator.com/en/downloads/documentation/)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Declared dry-runway runs show coherent pedal demand, achieved torque, wheel loading, deceleration and dissipated energy; asymmetric braking produces corresponding yaw. |
| Limit | Wet/low-friction, crosswind, bounce and repeated-stop scenarios have bounded slip and heat; brake hold at rest does not consume energy as if rolling. |
| Failure | Reference/supply loss, one brake failure, hot fade and tire damage are distinguishable; no discontinuous aerodynamic deceleration replaces failed brakes. |
| Recovery | Pressure recharge and cooling recover their own capacities on their own timescales; parking release does not erase brake heat and repair does not refill every resource implicitly. |

</details>

<a id="pkg-veh-11"></a>
<a id="case-av36"></a>
<a id="case-vg10"></a>
<a id="case-vt02"></a>
<a id="case-vt04"></a>
<a id="record-p17"></a>
<a id="record-v19"></a>
<a id="record-uv31"></a>

### VEH-11 — Add reduced-order ECS, equipment cooling, cabin pressure and defog

Conditioned-air supply, coolant/fuel heat removal, cabin pressure and visibility follow causal sources and loads; engine EGT alone cannot represent them.

- Model left/right engine bleed and ground APU conditioned-air availability, shutoff/isolation and ram fallback with explicit power and flight-condition dependencies.
- Use a small thermal network for equipment heat, fuel heat sink, coolant and refrigerated/ram-air removal. Publish equipment thermal health to electrical/avionics owners; do not recreate rejected EMD branch-control defects.
- Add cabin absolute pressure from ambient plus seal/valve/source-dependent increment; define leakage/decompression and pressure-altitude indication. Do not treat the SAB upstream pressure as cabin or SDK oxygen pressure.
- Add interior canopy fog/defog airflow as a separate effect from external rain removal and tint. Determine native rendering first, and label estimated moisture/thermal response.
- Expose intentional controls and source-loss indications through actual cockpit commands; exact modern F-22 switch layout, regulation schedule and trip temperatures remain configuration evidence decisions.

**Keep:** Ambient engine-temperature dependence remains useful for the engine model; SDK provides a separate cabin-pressure increment export; Existing tint/visor controls remain cosmetics.

<details>
<summary>Files, dependencies and references</summary>

- `EFM/source/RAPTOR.cpp` — add cabin additional-pressure output and source snapshot
- `Cockpit/Scripts/Systems/MFD_System.lua` — replace cabin argument copy with owned valid pressure indication
- `Cockpit/Scripts/Systems/Avionics.lua` — consume cooling/cabin alerts through warning owner
- `EFM/source/EnvironmentalSystem.h` — proposed reduced-order air/thermal model
- `Cockpit/Scripts/Systems/Canopy_Effects.lua` — proposed effect adapter only if host replacement is needed

**Depends on:** [VEH-01](#pkg-veh-01), [VEH-03](#pkg-veh-03), [VEH-04](#pkg-veh-04), [VEH-05](#pkg-veh-05).

**Audit findings:** [AV36](../audit/F22-Fidelity-Audit.html#auth-av36), [VG10](../audit/F22-Fidelity-Audit.html#auth-vg10), [VT02](../audit/F22-Fidelity-Audit.html#auth-vt02), [VT04](../audit/F22-Fidelity-Audit.html#auth-vt04).

**Supporting records:** P17, V19, UV31.

**References:**

- [Eaton F/A-22 capabilities brochure, April 2014](https://www.eaton.com/content/dam/eaton/markets/aerospace/Lockheed-Martin-Boeing-FA22-Raptor-capabilities-brochure.pdf)
- [Rainey and Kohn, F-22 flight-test program update, 1998](https://man.fas.org/dod-101/sys/ac/docs/f-22-emd-paper.htm)
- [USAF Scientific Advisory Board, Aircraft Oxygen Generation, SAB-TR-11-04, 1 February 2012](https://www.airandspaceforces.com/PDF/DocumentFile/Documents/2012/AFSAB_Oxygen_020112.pdf)
- [Chuck’s DCS F-16CM guide, 17 April 2025](https://chucksguides.com/aircraft/dcs/f-16cm/)
- [Chuck’s DCS F/A-18C guide, 25 April 2025](https://chucksguides.com/aircraft/dcs/fa-18c/)
- [Eagle Dynamics DCS F/A-18C Early Access Guide, internally 24 March 2024](https://www.digitalcombatsimulator.com/en/downloads/documentation/)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Ground APU and engine bleed can support declared cabin/cooling functions; cabin indication agrees with ambient plus the exported increment. |
| Limit | High load, low airflow, hot/cold atmosphere and low fuel change heat-rejection margin without instantly failing unrelated devices. |
| Failure | Bleed shutoff/leak, cooling loss and canopy leak yield different cabin/thermal/visibility consequences; faults do not create historical workaround requirements. |
| Recovery | Restored source or ram airflow improves the corresponding state over labelled estimated time; warm equipment and fog do not reset merely by clearing a caution. |

</details>

<a id="pkg-veh-12"></a>
<a id="case-av10"></a>
<a id="case-av11"></a>
<a id="record-v18"></a>
<a id="record-uv32"></a>
<a id="record-uv33"></a>

### VEH-12 — Implement source-dependent oxygen and era-aware automatic backup

Primary oxygen availability depends on conditioned supply and cabin environment; modern automatic backup is a separate finite source. Export unit semantics and host effects remain explicitly qualified.

- Represent conditioned-air input health, OBOGS production availability, selected backup source, reserve quantity and delivery pressure separately from concentration. Avoid an arbitrary fraction in the pressure API.
- Implement automatic backup transfer for the modern public-source simulation profile; keep the pre-ABOS 2012 report as architecture context, not the default failure procedure.
- Expose reserve servicing/depletion and restoration as separate states. Select any unsourced capacity only in the explicit simulation calibration register; do not reuse the old EOS duration as ABOS capacity.
- Perform a controlled host export test to determine accepted pressure-reference/response behavior before changing the 101,000 Pa healthy baseline. SDK alone does not identify mask partial pressure or the clinical effect.
- Default to source/reserve indications and aircraft-system consequences; no claimed human incapacitation timing is required for fidelity completion.

**Keep:** SDK establishes oxygen pressure in Pa; Separate cabin pressure convention is already explicit; 2013 ABOS behavior supersedes the old absence-of-backup premise.

<details>
<summary>Files, dependencies and references</summary>

- `EFM/source/RAPTOR.cpp` — replace constant oxygen export after convention qualification
- `EFM/include/FM/wHumanCustomPhysicsAPI.h` — read-only API contract
- `EFM/source/LifeSupport.h` — proposed source/reserve/controller model
- `Cockpit/Scripts/Systems/Pilot_Warning_System.lua` — handoff source/fault status; coordinate warning owner

**Depends on:** [VEH-01](#pkg-veh-01), [VEH-04](#pkg-veh-04), [VEH-11](#pkg-veh-11).

**Audit findings:** [AV10](../audit/F22-Fidelity-Audit.html#auth-av10), [AV11](../audit/F22-Fidelity-Audit.html#auth-av11).

**Supporting records:** V18, UV32, UV33.

**References:**

- [USAF Scientific Advisory Board, Aircraft Oxygen Generation, SAB-TR-11-04, 1 February 2012](https://www.airandspaceforces.com/PDF/DocumentFile/Documents/2012/AFSAB_Oxygen_020112.pdf)
- [Edwards Airmen vital to Raptor’s return, 17 April 2013](https://www.edwards.af.mil/News/Article/394043/edwards-airmen-vital-to-raptors-return/)
- [Eagle Dynamics DCS F/A-18C Early Access Guide, internally 24 March 2024](https://www.digitalcombatsimulator.com/en/downloads/documentation/)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Healthy primary supply and declared backup transitions publish coherent source state and valid pressure-unit data. |
| Limit | Low reserve and marginal/invalid conditioned supply use bounded estimates and do not become pressure/fraction unit confusion. |
| Failure | Primary interruption transfers automatically in the selected modern profile; independent backup failure remains visible. |
| Recovery | Primary recovery, reserve exhaustion and ground servicing follow the declared source-priority and inventory policy without magic refill. |

</details>

<a id="pkg-veh-13"></a>
<a id="case-vt03"></a>
<a id="record-p31"></a>
<a id="record-p32"></a>

### VEH-13 — Qualify canopy motion, locking and native escape integration

Canopy command, position, hold, secondary lock, power availability and warning/seal status form an intentional chain.

- Observe inherited keyboard/click canopy motion, intermediate hold, power-off behavior, warning/lock and host damage effects before declaring functionality missing.
- Choose a native adapter if required position/hold/lock states are available; otherwise implement one owned state model and disable the competing native writer.
- Connect up/hold/down and secondary lock to physical permission, and publish position/seal/lock separately to ECS and warning owners.
- Provide a bounded ground no-power/manual servicing abstraction if native support permits. Do not add rescue tooling or canopy-jettison engineering detail to normal pilot flows.
- Trace ejection-handle click/bind/press/release/repeat through the existing native action 83 and the actual host result/event into seat/canopy presentation, aircraft control ownership and teardown. Verify asset references before claiming they work. Add an edge/sequence adapter only if measured callback semantics require it; no unsupported real F-22 envelope, interlock or seat engineering is specified.

**Keep:** Inherited host canopy controls may already work; Existing external canopy animation and warning argument can be adapted.

<details>
<summary>Files, dependencies and references</summary>

- `Input/F-22A/keyboard/default.lua` — retain native control until measured
- `Cockpit/Scripts/clickabledata.lua` — add/verify actual canopy controls
- `Cockpit/Scripts/mainpanel_init.lua` — preserve animation contract
- `Cockpit/Scripts/Systems/Avionics.lua` — replace inferred warning with achieved/lock state if needed
- `EFM/source/CanopySystem.h` — proposed only if native model cannot expose required states

**Depends on:** [VEH-01](#pkg-veh-01), [VEH-04](#pkg-veh-04).

**Audit findings:** [VT03](../audit/F22-Fidelity-Audit.html#auth-vt03).

**Supporting records:** P31, P32.

**References:**

- [USAF T.O. 00-105E-9, F-22 section, 1 February 2006](https://www.0x4d.net/files/AF1/R11%20Segment%2012.pdf)
- [Chuck’s DCS F/A-18C guide, 25 April 2025](https://chucksguides.com/aircraft/dcs/fa-18c/)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Open, hold, close and lock produce consistent physical motion/indication; hold retains intermediate position. |
| Limit | Command reversals, partial travel and missing electrical supply are bounded and have clear state. |
| Failure | Secondary lock inhibits the documented normal actuation paths; canopy/lock sensor failures are not confused with actual position.; Native escape integration deliberately handles the measured host action sequence; release/repeated callback delivery cannot create an unintended local activation. |
| Recovery | Unlock or restored power permits appropriate motion; cabin seal status changes from achieved closure, not solely the switch request.; After a host escape/aircraft lifecycle transition, subsequent mission initialization clears the appropriate control/native references without inventing an airborne recovery path. |

</details>

<a id="pkg-veh-14"></a>
<a id="case-av29"></a>
<a id="case-vg06"></a>
<a id="record-p16"></a>
<a id="record-uv07"></a>
<a id="record-uv34"></a>
<a id="record-uv35"></a>

### VEH-14 — Connect damage, equipment faults, reset and repair

Registered structural/equipment failures affect the corresponding owned capability; reset, servicing and repair restore only the appropriate states.

- Create a cell-to-capability and mission-failure table with one explicit fault producer per supported battery/generator/APU/hydraulic/engine/air-data/cooling input.
- Wire registered aileron/elevator damage to the matching owned force/effectiveness and achieved state. Keep aerodynamic, actuator jam and electrical failure as distinguishable abstractions. Trace command -> achieved angle -> external argument -> FCS page -> force under saturation, pressure loss and damage; the cockpit page does not authenticate the surface schedule by itself.
- Replace precedence-dependent left/right destruction logic with an explicit symmetric or deliberately documented rule. Do not infer that every destroyed visual part means total-aircraft force zero.
- Implement separate resettable FCS faults, repairable equipment faults, persistent resource depletion and structural damage; a caution acknowledgment never repairs any of them.
- Extend repair/rearm/respawn coverage to new model states and exported validity; preserve fuel, brake heat or reserve according to the documented servicing action, not a generic reset-all call.

**Keep:** Derived integrities, destruction flags and queued damage are already repaired; Native damage cells and engine integrity paths exist.

<details>
<summary>Files, dependencies and references</summary>

- `EFM/source/RAPTOR.cpp` — map registered effector damage to achieved force/authority
- `F-22A.lua` — review cell/function map and mission failures
- `Cockpit/Scripts/Systems/MFD_System.lua` — keep FCS reset separate from mechanical repair
- `EFM/source/VehicleFaults.h` — proposed health/failure mapping
- `tests/test_vehicle_damage.cpp` — proposed asymmetric and repair scenarios

**Depends on:** [VEH-01](#pkg-veh-01), [VEH-03](#pkg-veh-03), [VEH-04](#pkg-veh-04), [VEH-05](#pkg-veh-05), [VEH-06](#pkg-veh-06), [VEH-07](#pkg-veh-07), [VEH-09](#pkg-veh-09), [VEH-10](#pkg-veh-10), [VEH-11](#pkg-veh-11), [VEH-12](#pkg-veh-12), [VEH-13](#pkg-veh-13).

**Audit findings:** [AV29](../audit/F22-Fidelity-Audit.html#auth-av29), [VG06](../audit/F22-Fidelity-Audit.html#auth-vg06).

**Supporting records:** P16, UV07, UV34, UV35.

**References:**

- [Pratt & Whitney F119](https://www.rtx.com/prattwhitney/products/military-engines/f119)
- [USAF T.O. 00-105E-9, F-22 section, 1 February 2006](https://www.0x4d.net/files/AF1/R11%20Segment%2012.pdf)
- [Chuck’s DCS F/A-18C guide, 25 April 2025](https://chucksguides.com/aircraft/dcs/fa-18c/)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Healthy start and no-damage behavior are unchanged by the mapping; each supported declared failure has a producing event and visible consequence. |
| Limit | Left/right mirrored damage and combined partial failures give explainable symmetric outcomes or explicit documented asymmetry. |
| Failure | Destroyed effector cannot keep full owned aerodynamic authority; loss of a producer cannot masquerade as a healthy zero or resettable transient. |
| Recovery | Repair restores the supported damaged functions without automatic engine start; FCS reset cannot heal structure; rearm/refuel preserve unrelated failures. |

</details>

## Navigation, landing and flight guidance

<a id="pkg-nav-wp02"></a>
<a id="case-an01"></a>
<a id="case-an02"></a>
<a id="case-an12"></a>
<a id="case-an13"></a>
<a id="case-ng03"></a>
<a id="case-ng04"></a>
<a id="record-n01"></a>
<a id="record-n02"></a>
<a id="record-n03"></a>
<a id="record-n04"></a>
<a id="record-n05"></a>
<a id="record-n06"></a>
<a id="record-n07"></a>
<a id="record-n08"></a>
<a id="record-h10"></a>
<a id="record-nav-24"></a>
<a id="record-nav-25"></a>
<a id="record-nav-26"></a>
<a id="record-nav-27"></a>

### NAV-WP02 — Build independent GINS references, alignment and degraded navigation

The pilot can select and identify two independent references, observe alignment/aiding quality, retain valid manual radio navigation through position loss and recover a declared source without truth impersonating a failed sensor.

- Replace the single readiness flag with per-channel power, alignment, attitude, heading and position health. Share healthy simulator inputs while allowing independent declared failures; provide independent HUD/SFG source selection.
- Implement normal and retained-heading alignment, movement rejection, progress/quality and a separate accelerated profile. Name provisional 8-minute/90-second timings as Hornet-derived estimates.
- Separate aiding availability and valid observations from the pilot enable setting. Define loss, coast, unavailable velocity, reacquisition, correction and long-outage states.
- Keep estimated solution error separate from uncertainty. Use declared deterministic simulation bias/fault fixtures, preserve bounded correction and make no production drift-rate claim.
- Show navigation quality and age of the last positive-position check. Crosschecks can establish position without editing an INS filter; the dated 90-minute operating rule must not become an automatic navigation disconnect.
- Preserve independent manual ILS/TACAN where their own heading, receiver and power inputs remain valid. Position-dependent consumers use the selected valid estimate rather than hidden truth.
- Optional: add one chosen alternate POS or FIX/ACAL workflow after independent observations exist. Freeze, inspect, accept and reject affect the intended estimate, never QNH or stored waypoint elevation.

**Keep:** Retain bounded aiding correction and rejection of simulator truth-position jumps while coasting.; Preserve manual received radio guidance through IRS readiness loss..

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/INS_Model.lua`
- `Cockpit/Scripts/Systems/Navigation_System.lua`
- `Cockpit/Scripts/Systems/Flight_Guidance.lua`
- `Cockpit/Scripts/Systems/Nav_Guidance.lua`
- `Cockpit/Scripts/Systems/UFC_Controller.lua`
- `Proposed: independent navigation/reference state owner`
- `Root-owned UFD/SFG/attitude displays`

**Depends on:** [NAV-WP01](#pkg-nav-wp01), [VEH-02](#pkg-veh-02), [VEH-04](#pkg-veh-04).

**Audit findings:** [AN01](../audit/F22-Fidelity-Audit.html#auth-an01), [AN02](../audit/F22-Fidelity-Audit.html#auth-an02), [AN12](../audit/F22-Fidelity-Audit.html#auth-an12), [AN13](../audit/F22-Fidelity-Audit.html#auth-an13), [NG03](../audit/F22-Fidelity-Audit.html#auth-ng03), [NG04](../audit/F22-Fidelity-Audit.html#auth-ng04).

**Supporting records:** N01, N02, N03, N04, N05, N06, N07, N08, H10, NAV-24, NAV-25, NAV-26, NAV-27.

**References:**

- [AFMAN 11-2F-22A Volume 3, Operations Procedures](https://static.e-publishing.af.mil/production/1/af_a3/publication/afman11-2f-22av3/afman11-2f-22av3.pdf) — p26 §4.1.3; p36 §7.9.1.1–.2
- [Brower, F-22 Avionics, The Avionics Handbook, chapter 32](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf) — p10 §32.3.6; p11 §32.4
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf) — pp116–118
- [Chuck’s DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf) — p85
- [Chuck’s DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf) — pp751–753, 760–761

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Normal alignment follows the selected timer. Retained heading is available only after a previous full alignment with no movement.; HUD and SFG can use opposite references; bias in one produces a detectable disagreement.; Removing aiding causes declared coasting; enabling a setting does not itself produce HIGH quality. |
| Limit | Movement rejects the stored-heading shortcut. Short and long outages follow the retention policy.; Airborne recovery follows declared aiding/health conditions; the existing 30-second convenience is confined to the assisted profile.; Large aiding corrections have an explicit correction/coupling state and do not silently jump a coupled route. |
| Failure | Fail one GINS, then GNSS, then both position channels. Independent attitude/radio functions remain only where their own health permits.; Loss of coasting velocity invalidates position. A growing uncertainty budget alone does not count as demonstrated position drift. |
| Recovery | Select the healthy reference and restore the failed one through the declared alignment policy.; Reacquire aiding with visible correction/quality progress; AP requires pilot reselection after loss.; Optional FIX/ACAL rejection preserves state; acceptance updates only the selected datum. |

</details>

<a id="pkg-nav-wp03"></a>
<a id="case-an08"></a>
<a id="case-an09"></a>
<a id="case-ng07"></a>
<a id="case-ng08"></a>
<a id="case-nt01"></a>
<a id="case-nt02"></a>
<a id="record-l31"></a>
<a id="record-nav-03"></a>
<a id="record-nav-04"></a>

### NAV-WP03 — Unify pressure/radar/standby altitude and preserve independent validity

Pressure altitude, QNH/STD, radar height, selected HUD altitude and standby reversion remain consistent under weather and component failures. Healthy barometric altitude can remain visible after CAS calculation fails.

- Preserve pressure-height calculation and saved QNH/STD behavior. Move healthy HUD barometric publication outside the CAS-success branch under the selected component-validity policy; shared ADC/static faults still invalidate their explicitly affected outputs.
- Give primary pressure, standby pressure and radar measurement separate health, time and reason fields. Add a generic independent standby recovery path without inventing a F-22 pneumatic lever.
- Declare measurement/sanity, display, warning-entry and AFCS envelopes separately. Keep the current 20 km check only as an explicit numerical policy, not a verified 65,000 ft equipment capability. Do not impose a generic 5,000 ft display cutoff.
- Default to BARO and provide explicit RDR selection with labelled barometric fallback. Any flashing fallback symbol is a chosen Hornet-derived convention.
- Supply fresh radar measurement and validity to NAV-WP07. Geometric AGL remains a separate physics/terrain quantity and cannot impersonate a healthy receiver.
- Add active HUD pressure confirmation. If adopting the Hornet interaction, use its 5-second confirmation and stated approach redisplay conditions while retaining existing UFD visibility.
- Preserve normal weather-related pressure/geometric disagreement. Do not adjust QNH to force truth agreement or infer automatic cold compensation. Decide signed minima separately from signed waypoint elevation.

**Keep:** Retain pressure physics, the second atmospheric layer, freshness checks, saved QNH/STD and unit conversion.; Retain NT01’s pressure/geometric distinction and separate warning settings..

<details>
<summary>Files, dependencies and references</summary>

- `EFM/source/NativeAltimetry.cpp`
- `EFM/source/NativeAltimetry.h`
- `Cockpit/Scripts/Systems/Altitude_Settings.lua`
- `Cockpit/Scripts/Systems/Altitude_System.lua`
- `Cockpit/Scripts/Systems/HUD_Flight_Data.lua`
- `Cockpit/Scripts/HUD/page.lua`
- `Cockpit/Scripts/Systems/UFC_Controller.lua`
- `EFM/source/RAPTOR.cpp`
- `Proposed: standby air-data state adapter`

**Depends on:** [NAV-WP01](#pkg-nav-wp01), [VEH-02](#pkg-veh-02), [VEH-04](#pkg-veh-04).

**Audit findings:** [AN08](../audit/F22-Fidelity-Audit.html#auth-an08), [AN09](../audit/F22-Fidelity-Audit.html#auth-an09), [NG07](../audit/F22-Fidelity-Audit.html#auth-ng07), [NG08](../audit/F22-Fidelity-Audit.html#auth-ng08), [NT01](../audit/F22-Fidelity-Audit.html#auth-nt01), [NT02](../audit/F22-Fidelity-Audit.html#auth-nt02).

**Supporting records:** L31, NAV-03, NAV-04.

**References:**

- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf) — pp48–49, 54, 64, 78
- [Chuck’s DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf) — p54
- [FAA Pilot’s Handbook of Aeronautical Knowledge, chapter 8, Flight Instruments](https://www.faa.gov/sites/faa.gov/files/regulations_policies/handbooks_manuals/aviation/phak/10_phak_ch8.pdf) — Chapter 8, pitot/static and pressure-altimeter paragraphs
- [FAA AIP, Cold Temperature Barometric Altimeter Errors](https://www.faa.gov/air_traffic/publications/atpubs/aip_html/chap7_section_3.html) — Chapter 7 §3, temperature/error paragraphs
- [AFTC, Combined Altitude Radar Altimeter Begins Testing](https://www.aftc.af.mil/News/On-This-Day-in-Test-History/Article-Display-Test-History/Article/2490213/march-2-1983-combined-altitude-radar-altimeter-begins-testing/) — Complete historical capability paragraphs
- [Extant Aerospace AN/APN-232 Combined Altitude Radar Altimeter](https://extantaerospace.com/products/nav/alt_radar.html) — Complete product description and platform list
- [AFMAN 11-2F-22A Volume 3, Operations Procedures](https://static.e-publishing.af.mil/production/1/af_a3/publication/afman11-2f-22av3/afman11-2f-22av3.pdf) — p36 §7.9.1.1

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Change QNH through inHg/hPa entry; HUD, UFD and BALT use the same pressure indication. STD returns to saved QNH.; Invalid CAS with healthy baro leaves altitude valid; invalid baro with healthy CAS blanks only the affected altitude path.; RDR failure produces the selected BARO fallback and label without changing pressure or silently engaging another AP mode. |
| Limit | Check below-sea-level pressure altitude, pressure-entry limits, the second pressure layer and nonstandard temperature.; A healthy radar measurement above 5,000 ft does not become invalid solely because RALT targets stop there; an explicit Hornet instrument profile may use a different display limit.; Pressure confirmation uses model time and handles time reset. |
| Failure | Age pressure/radar publications and fail pressure, standby and supply inputs independently.; A standby path sharing the same failed input cannot claim independent health.; Invalid radar input prevents or ends RALT through its own mode contract, with no geometric fallback. |
| Recovery | Fresh source data restores indication without reengaging AP.; Power and STD/QNH round trips follow declared persistence rules. Preserve the last fresh healthy publication while solving the next sample. |

</details>

<a id="pkg-nav-wp04"></a>
<a id="case-an04"></a>
<a id="case-an05"></a>
<a id="case-an06"></a>
<a id="case-an07"></a>
<a id="case-ng10"></a>
<a id="record-l01"></a>
<a id="record-l02"></a>
<a id="record-l03"></a>
<a id="record-l04"></a>
<a id="record-l05"></a>
<a id="record-l06"></a>
<a id="record-l07"></a>
<a id="record-l08"></a>
<a id="record-l10"></a>
<a id="record-l11"></a>
<a id="record-l12"></a>
<a id="record-l13"></a>
<a id="record-h01"></a>
<a id="record-h02"></a>
<a id="record-h03"></a>
<a id="record-h04"></a>
<a id="record-h08"></a>
<a id="record-h09"></a>

### NAV-WP04 — Complete calibrated flight/landing HUD and contextual cage behavior

FPM, AoA landing cues, reference labels and cage/off-glass behavior have explicit meanings. Qualify installed angular geometry while separating the historical F-22 reference center from estimated band widths.

**Current issue ([AN04](../audit/F22-Fidelity-Audit.html#auth-an04)):** The fixed mod center agrees with that historical normal reference. It does not implement the source-described condition-dependent reference, and its optical geometry/band remain unverified.

- Retain the ground-velocity FPM and separate attitude, nose and heading references. Separate computed validity from drawing visibility; publish a declared off-glass state rather than silently converting clipping into sensor failure.
- Route NAV cage to FPM/ghost presentation and weapon cage to the seeker. A single press must not command both contexts.
- Retain the 12-degree normal center. Label 11.5/12.5-degree flag edges as estimates. Keep reference selection, glyph geometry and indexer bands separate; an optional EMD alternate reference requires explicit profile/configuration selection.
- Use actual down-and-locked, WOW, AoA health and power from the agreed configuration contract. Finite AoA alone is not proof of a healthy ADC.
- Measure FPM, E-bracket, ladder and ILS cue angles against known rays in 2D and VR. Preserve the planar/polar projection distinction; project tolerances are QA criteria rather than F-22 optical specifications.
- Declare landing declutter and master-mode retention. Hide drawings without stopping healthy sources. Label wind numbers TRUE and preserve wind-from numbers versus flow-arrow meaning.

**Keep:** Preserve ground-flight-path projection, the independent producer and correct planar/polar conversion.; Retain the complete visible E-bracket and historical 12-degree reference anchor..

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/HUD_Flight_Data.lua`
- `Cockpit/Scripts/Systems/HUD_FlightMath.lua`
- `Cockpit/Scripts/Systems/HUD_Projection.lua`
- `Cockpit/Scripts/HUD/landing.lua`
- `Cockpit/Scripts/HUD/page.lua`
- `Cockpit/Scripts/HUD/navigation.lua`
- `Cockpit/Scripts/HUD/layout.lua`
- `Cockpit/Scripts/HUD/optics.lua`
- `Cockpit/Scripts/HUD/glass.lua`
- `Cockpit/Scripts/Systems/Combat_Logic.lua`
- `Cockpit/Scripts/Systems/Combat_System.lua`
- `Cockpit/Scripts/device_init.lua`

**Depends on:** [NAV-WP01](#pkg-nav-wp01), [NAV-WP02](#pkg-nav-wp02), [NAV-WP03](#pkg-nav-wp03), [NAV-WP05](#pkg-nav-wp05), [VEH-07](#pkg-veh-07).

**Audit findings:** [AN04](../audit/F22-Fidelity-Audit.html#auth-an04), [AN05](../audit/F22-Fidelity-Audit.html#auth-an05), [AN06](../audit/F22-Fidelity-Audit.html#auth-an06), [AN07](../audit/F22-Fidelity-Audit.html#auth-an07), [NG10](../audit/F22-Fidelity-Audit.html#auth-ng10).

**Supporting records:** L01, L02, L03, L04, L05, L06, L07, L08, L10, L11, L12, L13, H01, H02, H03, H04, H08, H09.

**References:**

- [Rainey and Kohn, F-22 Flight Test Program Update](https://man.fas.org/dod-101/sys/ac/docs/f-22-emd-paper.htm) — Full selected single-engine test paragraphs, lines27–29
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf) — pp44–45, 77–78
- [Chuck’s DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf) — p41; pp770–773
- [AFMAN 11-2F-22A Volume 3, Operations Procedures](https://static.e-publishing.af.mil/production/1/af_a3/publication/afman11-2f-22av3/afman11-2f-22av3.pdf) — p36 §7.9.1.1

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | At the chosen AoA center the bracket remains visible and aligned to FPM; equal positive/negative error gives the correct direction.; Crosswind separates flight path from nose. Cage shows a true ghost without changing the aircraft state.; Known wind direction produces consistent numbers and flow arrow. |
| Limit | Cross angular/glass limits without false healthy centered cues or source-health flicker.; Exercise gear transit, WOW bounce, invalid AoA and retained A/G mode during landing.; Measure angular alignment across head translation, aspect ratios and both VR eyes against declared tolerances. |
| Failure | Fail AoA only: landing AoA cues invalidate while healthy attitude and altitude remain.; Fail the HUD: remaining healthy SFG/reference presentation follows the root display plan. |
| Recovery | Restored flight data brings cues back under their validity rules without changing the selected reference or automatically changing weapon mode.; Context changes do not replay a held cage command into a different system. |

</details>

<a id="pkg-nav-wp05"></a>
<a id="case-an03"></a>
<a id="case-an27"></a>
<a id="case-ng01"></a>
<a id="case-ng02"></a>
<a id="record-l14"></a>
<a id="record-l15"></a>
<a id="record-l16"></a>
<a id="record-l17"></a>
<a id="record-l18"></a>
<a id="record-l19"></a>
<a id="record-l20"></a>
<a id="record-n15"></a>
<a id="record-n16"></a>
<a id="record-n17"></a>
<a id="record-nav-06"></a>
<a id="record-nav-07"></a>
<a id="record-nav-08"></a>
<a id="record-nav-09"></a>
<a id="record-nav-10"></a>

### NAV-WP05 — Qualify manual ILS/TACAN and make component/datum behavior consistent

Manual runway ILS and TACAN remain usable through unrelated position/display loss. Component validity, mode effects, datum, scale and identification agree across formats, with host signal behavior established before broader claims.

- Retain independent LOC/GS flags and publication before the missing-ownship return. Preserve explicit native power/version failure invalidity; identify which heading functions actually require position/reference data.
- Make REC, T/R and A/A bearing/range consequences consistent. Retain range-only DME without inventing bearing, and do not synthesize DME in REC. Verify host behavior before duplicating a receiver model.
- Use a named Hornet-derived angular TACAN CDI with 4-degree inner and 8-degree outer references. Keep waypoint NM cross-track separate and labelled.
- Add station course-reference metadata distinct from ownship magnetic variation. For the chosen Hornet convention, unknown station metadata produces labelled magnetic-course fallback. Display-reference changes preserve the physical course.
- Trace host ILS/TACAN ident and marker audio. Expose supported monitor/volume/status or explicit unavailability; missing adapter fields alone do not prove there is no sound.
- Qualify LOC/GS sign, sensitivity and independent validity using controlled offsets, LOC-only and station-loss cases. Publish a frontcourse/backcourse support policy. Raw deviations are not a command-steering law.
- Use actual transmissions/component flags for signal health, rather than station geometry as proof of reception. Keep carrier ICLS/ACLS separate.

**Keep:** Retain the narrow manual ILS match, independent receiver flags and explicit native availability.; Retain legal tuning, mode controls and landing cue acquisition independent from route steering..

<details>
<summary>Files, dependencies and references</summary>

- `EFM/source/NativeNavigation.cpp`
- `EFM/source/NativeNavigation.h`
- `Cockpit/Scripts/Systems/TACAN_Native.lua`
- `Cockpit/Scripts/Systems/Navigation_Power.lua`
- `Cockpit/Scripts/Systems/Flight_Guidance.lua`
- `Cockpit/Scripts/Systems/Nav_Guidance.lua`
- `Cockpit/Scripts/Systems/Navigation_System.lua`
- `Cockpit/Scripts/Systems/Nav_Display_Controls.lua`
- `Cockpit/Scripts/Systems/UFC_Controller.lua`
- `Cockpit/Scripts/HUD/navigation.lua`
- `Proposed: station metadata/ident monitor adapter`

**Depends on:** [NAV-WP01](#pkg-nav-wp01), [NAV-WP02](#pkg-nav-wp02), [VEH-04](#pkg-veh-04).

**Audit findings:** [AN03](../audit/F22-Fidelity-Audit.html#auth-an03), [AN27](../audit/F22-Fidelity-Audit.html#auth-an27), [NG01](../audit/F22-Fidelity-Audit.html#auth-ng01), [NG02](../audit/F22-Fidelity-Audit.html#auth-ng02).

**Supporting records:** L14, L15, L16, L17, L18, L19, L20, N15, N16, N17, NAV-06, NAV-07, NAV-08, NAV-09, NAV-10.

**References:**

- [AFMAN 11-2F-22A Volume 3, Operations Procedures](https://static.e-publishing.af.mil/production/1/af_a3/publication/afman11-2f-22av3/afman11-2f-22av3.pdf) — p14 §3.8.4; p26 §4.1
- [Brower, F-22 Avionics, The Avionics Handbook, chapter 32](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf) — p11 §32.4
- [Chuck’s DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf) — pp770–772
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf) — pp48, 138, 140
- [Chuck’s DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf) — p700

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Legal tuning updates the receiver owner and every readback once.; Healthy LOC/GS remains manually usable with IRS not ready or ownship position unavailable.; Range-only TACAN shows DME in main NAV and DATA, without invented bearing/AP track.; Known station course references agree at nonzero variation. |
| Limit | Exercise LOC-only, GS-only, front/rear quadrants, zero DME and unknown station metadata.; Equal angular errors at different ranges produce the same TACAN CDI response; waypoint NM scaling remains separate.; Qualify all five exposed TACAN modes and paired air-to-air operation in the host; successful setMode calls alone do not prove behavior. |
| Failure | Lose receiver power, adapter binding or one received component. Drawing, audio and coupling follow the affected component without hiding unrelated healthy data.; Lose magnetic conversion data; DME/ILS remain where independent while true-bearing conversion is unavailable. |
| Recovery | Restore or retune the station: valid components reacquire without AP engagement or INS rewriting.; Restoring position during manual ILS does not trigger automatic coupling. |

</details>

<a id="pkg-nav-wp06"></a>
<a id="case-an21"></a>
<a id="case-an28"></a>
<a id="case-an29"></a>
<a id="record-n09"></a>
<a id="record-n10"></a>
<a id="record-n11"></a>
<a id="record-n12"></a>
<a id="record-n13"></a>
<a id="record-n14"></a>
<a id="record-n18"></a>
<a id="record-n19"></a>
<a id="record-n20"></a>
<a id="record-nav-05"></a>
<a id="record-nav-19"></a>
<a id="record-nav-20"></a>
<a id="record-nav-21"></a>
<a id="record-nav-22"></a>
<a id="record-nav-23"></a>

### NAV-WP06 — Implement coherent route sequencing, mark storage and arrival timing

Route, direct, course, overfly, mark, timing and weapon designation remain distinct pilot intents. Mark creation preserves the active leg, and destination events drive deliberate AFCS transitions.

- Retain route capacity, import, undo and explicit MSL/AGL conversion. Qualify the first-point-origin assumption against mission routes, empty/single-point data and unresolved terrain elevation.
- Add explicit route/direct/course/arrived/AUTO/OVERFLY state. Predict turns only in the chosen fly-by mode; preserve one-point-per-update protection.
- Send explicit destination-passage events to AFCS: direct/final arrival holds current heading, selected course continues outbound, AUTO chooses the next leg and OVERFLY delays the outbound turn.
- Add an independent cyclic mark bank, provisionally nine slots as a named Hornet analogue. Capture ownship or valid designation only after acceptance, without selecting the mark or creating direct-to as a side effect.
- Keep mark storage, weapon designation and timing destination separate. Retain coordinate-snapshot acknowledgement for weapon designation; coordinate complete waypoint/heading accepted-value feedback with root.
- Add desired Zulu arrival, timing destination and required ground speed using a declared remaining-route distance model. Keep direct TTG labelled separately; past/unachievable arrival requests show status.
- Support signed waypoint elevation through the active transaction where needed. Publish units/datum and actual accepted values. Offset/VIP/VRP are separate optional choices.

**Keep:** Retain route import, capacity, undo, sanitized names and AGL terrain conversion.; Preserve the designation request/acknowledgement chain and honestly labelled direct TTG..

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/Nav_Computer.lua`
- `Cockpit/Scripts/Systems/Navigation_System.lua`
- `Cockpit/Scripts/Systems/Nav_Entry.lua`
- `Cockpit/Scripts/Systems/Nav_Guidance.lua`
- `Cockpit/Scripts/Systems/Nav_Display.lua`
- `Cockpit/Scripts/Systems/Nav_Display_Controls.lua`
- `Cockpit/Scripts/Systems/UFC_Controller.lua`
- `Cockpit/Scripts/Systems/ICP_System.lua`
- `Cockpit/Scripts/Systems/AG_Mark_System.lua`

**Depends on:** [NAV-WP01](#pkg-nav-wp01), [NAV-WP02](#pkg-nav-wp02).

**Audit findings:** [AN21](../audit/F22-Fidelity-Audit.html#auth-an21), [AN28](../audit/F22-Fidelity-Audit.html#auth-an28), [AN29](../audit/F22-Fidelity-Audit.html#auth-an29).

**Supporting records:** N09, N10, N11, N12, N13, N14, N18, N19, N20, NAV-05, NAV-19, NAV-20, NAV-21, NAV-22, NAV-23.

**References:**

- [AFMAN 11-2F-22A Volume 3, Operations Procedures](https://static.e-publishing.af.mil/production/1/af_a3/publication/afman11-2f-22av3/afman11-2f-22av3.pdf) — p26 §4.1.3–.4
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf) — pp140, 147–148
- [Chuck’s DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf) — pp675–676, 691–693
- [Chuck’s DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf) — p672; pp760–761

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Create a mark during AUTO/CPL; route and selection stay unchanged until explicit selection.; The tenth mark overwrites the first slot under the chosen cyclic policy and reports actual acceptance.; Direct, selected-course and AUTO passage produce their different outcomes.; TOT destination can differ from weapon TGT without changing designation. |
| Limit | Exercise empty/full routes, co-located points, sharp turns, very low speed, passed-fix corridor boundaries and negative elevation.; Same-ID coordinate edits require accepted-value acknowledgement; rejection retains the draft and prior route.; Midnight, expired and unachievable arrival requests produce explicit timing status. |
| Failure | Position loss stops estimate-dependent sequencing; simulator truth must not continue the failed solution.; Missing terrain conversion leaves unresolved AGL/MSL status rather than a false zero.; Failed mark/point commit cannot announce MARK STORED or retask the route. |
| Recovery | Restored position retains route/marks under a declared resumption policy and cannot sequence uncontrolled points at once.; Undo restores the accepted prior path. Power, reload and new-slot storage follow the published policy. |

</details>

<a id="pkg-nav-wp07"></a>
<a id="case-an14"></a>
<a id="case-an15"></a>
<a id="case-an16"></a>
<a id="case-an17"></a>
<a id="case-an18"></a>
<a id="case-an19"></a>
<a id="case-an20"></a>
<a id="case-an22"></a>
<a id="case-an23"></a>
<a id="case-ng05"></a>
<a id="case-ng09"></a>
<a id="record-l28"></a>
<a id="record-l32"></a>
<a id="record-l33"></a>
<a id="record-nav-02"></a>
<a id="record-nav-11"></a>
<a id="record-nav-12"></a>
<a id="record-nav-13"></a>
<a id="record-nav-14"></a>
<a id="record-nav-15"></a>
<a id="record-nav-16"></a>
<a id="record-nav-17"></a>

### NAV-WP07 — Refactor AFCS into independent axes with consistent capture and pilot takeover

HSEL/CPL can command roll with manual pitch. BALT captures indicated pressure altitude once and RALT uses healthy receiver height. Permanent disconnect, temporary CPL override and optional recapture have distinct authority and annunciation.

- Refactor active/axis state so vertical OFF does not forbid lateral AP. HSEL/CPL preserve vertical selection or manual pitch rather than implicitly engaging BALT.
- Capture BALT/RALT at one data owner using indicated pressure altitude or valid radar height. Remove geometric UFC capture and unit mismatch; keyboard and physical controls use the same accepted snapshot.
- Retain current-attitude capture and separate heading/ground-track feedback. Ordinary paddle permanently disconnects AP. Retain current AP/A-T OFF as an explicit mod takeover policy, without claiming the cited Hornet documentation proves the A/T part.
- Implement temporary CPL lateral stick override and declared resumption on release. Vertical behavior follows its independent mode. Do not add Viper ATT recapture to the selected core.
- NAV freshness/geometry loss decouples lateral control and retains a healthy independent vertical mode under the declared policy. Latch uncommanded loss until acknowledgement; pilot OFF is different. Pressure/radar failures affect modes using those quantities.
- Consume explicit route-arrival events. Retain 30-degree NAV bank; add 60-degree TAC only as a selected, qualified option.
- Apply consistent entry and update rules for stick neutrality, held trim, power, configuration and envelope. Ineligible selection reports rejection rather than unexplained immediate dropout.
- Show limiting or insufficient authority for unreachable targets. Define measured capture/steady-response criteria against the mod flight model before tuning; do not claim production F-22 gains.

**Keep:** Retain ATTH capture, heading/track separation, fresh NAV gating and bounded-output intent.; Preserve post-adoption native barometric failure protection.; Credit the existing permanent ordinary paddle path instead of calling it wrong solely because Viper behavior differs..

<details>
<summary>Files, dependencies and references</summary>

- `EFM/source/Autopilot.h`
- `EFM/source/RAPTOR.cpp`
- `Cockpit/Scripts/Systems/Flight_Guidance.lua`
- `Cockpit/Scripts/Systems/UFC_Controller.lua`
- `Cockpit/Scripts/Systems/Combat_Logic.lua`
- `Cockpit/Scripts/Systems/Combat_System.lua`
- `Cockpit/Scripts/Systems/Nav_Guidance.lua`
- `Input keyboard/joystick AP/paddle bindings`
- `tests/test_autopilot.cpp`

**Depends on:** [NAV-WP01](#pkg-nav-wp01), [NAV-WP02](#pkg-nav-wp02), [NAV-WP03](#pkg-nav-wp03), [NAV-WP05](#pkg-nav-wp05), [NAV-WP06](#pkg-nav-wp06), [VEH-07](#pkg-veh-07), [UI-02](#pkg-ui-02).

**Audit findings:** [AN14](../audit/F22-Fidelity-Audit.html#auth-an14), [AN15](../audit/F22-Fidelity-Audit.html#auth-an15), [AN16](../audit/F22-Fidelity-Audit.html#auth-an16), [AN17](../audit/F22-Fidelity-Audit.html#auth-an17), [AN18](../audit/F22-Fidelity-Audit.html#auth-an18), [AN19](../audit/F22-Fidelity-Audit.html#auth-an19), [AN20](../audit/F22-Fidelity-Audit.html#auth-an20), [AN22](../audit/F22-Fidelity-Audit.html#auth-an22), [AN23](../audit/F22-Fidelity-Audit.html#auth-an23), [NG05](../audit/F22-Fidelity-Audit.html#auth-ng05), [NG09](../audit/F22-Fidelity-Audit.html#auth-ng09).

**Supporting records:** L28, L32, L33, NAV-02, NAV-11, NAV-12, NAV-13, NAV-14, NAV-15, NAV-16, NAV-17.

**References:**

- [AFMAN 11-2F-22A Volume 3, Operations Procedures](https://static.e-publishing.af.mil/production/1/af_a3/publication/afman11-2f-22av3/afman11-2f-22av3.pdf) — p36 §7.9.1.2
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf) — pp47–48, 147–148
- [Chuck’s DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf) — p659
- [Chuck’s DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf) — pp669–672

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Select CPL/HSEL from AP OFF with manual pitch, then select BALT and observe independent axes.; Changed QNH produces identical indicated-altitude capture through UFC and keyboard, without a climb to geometric height.; Ordinary paddle disconnects permanently; CPL stick input temporarily overrides under the declared policy.; Heading hold maintains heading in wind, while route coupling maintains ground course with crab. |
| Limit | Exercise north crossing, high vertical speed, stick/trim held at selection, power/configuration limits, stale time and preset boundaries.; A numerically valid but unreachable target shows limiting without runaway accumulation or false capture.; Receiver height outside the RALT operating envelope rejects/ends RALT without declaring the whole radar measurement failed. |
| Failure | NAV loss decouples roll and latches its reason while healthy BALT remains.; Invalid pressure inhibits BALT; unrelated CAS failure cannot manufacture a barometric fault.; Loss of achieved control power/integrity ends unavailable AP authority and identifies remaining pilot control. |
| Recovery | Restoring a source does not autoengage AP. Acknowledgement clears annunciation rather than engaging a mode.; Temporary CPL release resumes according to its contract; optional recapture does not change ordinary paddle behavior.; Restore trim/control supply without releasing hidden accumulated AP commands. |

</details>

<a id="pkg-nav-wp08"></a>
<a id="case-an24"></a>
<a id="case-an25"></a>
<a id="case-ng06"></a>
<a id="record-l21"></a>
<a id="record-l26"></a>
<a id="record-l27"></a>
<a id="record-nav-18"></a>

### NAV-WP08 — Complete honest cruise A/T feedback; isolate optional approach AoA assistance

CAS/Mach cruise assistance clearly distinguishes selected target, engagement, limiting, failed selection and disengagement. Optional approach AoA control has its own validity/configuration chain.

- Keep explicit CAS and Mach labels and throttle-only operation. Stepping one quantity must not silently alter the other stored target.
- Separate failed engagement and automatic loss from pilot OFF. Use the chosen Hornet-derived 10-second indication, distinct from the CPL loss latch.
- Define joystick-axis takeover, throttle split, configuration, power and air-data loss as game input states. Do not equate normalized axis delta with a real force or actuator-angle threshold.
- Show actual thrust/output authority and unreachable-speed limiting. Agree idle/MIL/AB interfaces with the engine owner before changing normalized output bounds.
- Optional: specify approach AoA control with valid AoA, achieved landing configuration, WOW, engine/control availability, pilot override and exit states. Do not transplant the Hornet 27-degree flap gate literally.
- Keep approach ATC, flight director, automatic ILS, AGCAS and flare/rollout separate. AoA throttle control cannot announce autoland.

**Keep:** Retain separate bounded A/T output, throttle-only assistance, preset state and pilot takeover.; Current gear-down-ineligible CAS/Mach hold is not represented as existing approach AoA ATC..

<details>
<summary>Files, dependencies and references</summary>

- `EFM/source/Autopilot.h`
- `EFM/source/RAPTOR.cpp`
- `Cockpit/Scripts/Systems/Flight_Guidance.lua`
- `Cockpit/Scripts/Systems/UFC_Controller.lua`
- `Cockpit/Scripts/Systems/HUD_Flight_Data.lua`
- `Cockpit/Scripts/HUD/page.lua`
- `Input throttle/A-T bindings`

**Depends on:** [NAV-WP01](#pkg-nav-wp01), [NAV-WP03](#pkg-nav-wp03), [NAV-WP04](#pkg-nav-wp04), [NAV-WP07](#pkg-nav-wp07), [VEH-05](#pkg-veh-05).

**Audit findings:** [AN24](../audit/F22-Fidelity-Audit.html#auth-an24), [AN25](../audit/F22-Fidelity-Audit.html#auth-an25), [NG06](../audit/F22-Fidelity-Audit.html#auth-ng06).

**Supporting records:** L21, L26, L27, NAV-18.

**References:**

- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf) — p76 complete approach/cruise paragraphs
- [Chuck’s DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf) — p665
- [Chuck’s DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf) — pp669–672, 770–773
- [AFMAN 11-2F-22A Volume 3, Operations Procedures](https://static.e-publishing.af.mil/production/1/af_a3/publication/afman11-2f-22av3/afman11-2f-22av3.pdf) — p26 §4.1

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | CAS/Mach assistance works with pitch AP OFF and displays the controlled quantity and independent target memory.; Pilot OFF is normal; failed selection or automatic loss produces the chosen timed feedback.; Manual throttle takeover ends assistance without an axis fight. |
| Limit | Switch quantities with existing presets, encounter output limits and change vertical mode or engine spool state.; Exercise configuration/WOW changes and axis jitter around the declared takeover threshold.; Optional AoA assistance is measured across declared masses/configurations without a donor-gain or production-fit claim. |
| Failure | Invalid airspeed or engine/control availability ends the affected assistance with a reason, while independent healthy AP/radio functions remain.; Rejected engagement preserves accepted targets and unrelated AP axes. |
| Recovery | Restored data/configuration requires pilot reengagement; target persistence follows the declared policy.; Optional approach exit/go-around restores manual authority without unsolicited resume. |

</details>

<a id="pkg-nav-wp09"></a>
<a id="case-an10"></a>
<a id="case-an11"></a>
<a id="record-l29"></a>
<a id="record-l30"></a>
<a id="record-nav-01"></a>
<a id="record-nav-28"></a>

### NAV-WP09 — Separate minima, low-level repeats and advisory terrain recovery

Repeated gear-up radar-low warning and gear-down one-shot minima have separate reset/rearm rules. Advisory terrain context is independent from hidden steering-source choice and automatic control authority.

- Replace the shared floor queue with separate radar-low repeat, gear-down minima and declared barometric-floor states. Match the selected reset/disable distinction; any 100 ft hysteresis remains a mod value.
- Coordinate event acknowledgement with root. Playing one ALTITUDE clip cannot acknowledge a persistent low warning; one acknowledgement must not erase unrelated terrain/FCS/caution state.
- Create explicit approach/recovery context from pilot intent, achieved configuration, received signal and flight state. Remove the accidental need to select ILS steering when valid ILS is already displayed under another source.
- Review the current flat/stable landing exemption as a mod policy. Invalid signals, obstacles, rising terrain, unstable flight and go-around must not stay blanket-inhibited.
- Keep threat, cue direction, unavailable/no-escape and automatic authority separate. Preserve query bounds and fresh cues; a predicted recovery is not a guarantee of safety.
- Give missing terrain, pressure and radar data explicit mode-dependent indications. Root owns priority/muting/general alert policy; civil FAA examples remain optional design guidance.

**Keep:** Retain separate pressure/radar inputs, confirmed-playback commitment and priority interlocks.; Preserve live cue rotation, bounded queries and the explicit advisory-only terrain boundary..

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/Pilot_Warnings.lua`
- `Cockpit/Scripts/Systems/Pilot_Warning_System.lua`
- `Cockpit/Scripts/Systems/Terrain_Escape.lua`
- `Cockpit/Scripts/Systems/Terrain_Director.lua`
- `Cockpit/Scripts/Systems/Terrain_Recovery_Cue.lua`
- `Cockpit/Scripts/Systems/Altitude_System.lua`
- `Cockpit/Scripts/HUD/pilot_warnings.lua`
- `Root-owned alert/audio arbiter`

**Depends on:** [NAV-WP01](#pkg-nav-wp01), [NAV-WP03](#pkg-nav-wp03), [NAV-WP04](#pkg-nav-wp04), [NAV-WP05](#pkg-nav-wp05), [ALR-01](#pkg-alr-01), [ALR-02](#pkg-alr-02).

**Audit findings:** [AN10](../audit/F22-Fidelity-Audit.html#auth-an10), [AN11](../audit/F22-Fidelity-Audit.html#auth-an11).

**Supporting records:** L29, L30, NAV-01, NAV-28.

**References:**

- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf) — p70 complete radar-low warning paragraphs
- [Chuck’s DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf) — pp155–157
- [AFMAN 11-2F-22A Volume 3, Operations Procedures](https://static.e-publishing.af.mil/production/1/af_a3/publication/afman11-2f-22av3/afman11-2f-22av3.pdf) — p8 §2.4.2.3; p18 §3.15.3
- [Brower, F-22 Avionics, The Avionics Handbook, chapter 32](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf) — p11 §32.4

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Gear-up low radar height repeats until the selected reset/disable action. Gear-down crossing produces a separate one-shot event.; With unchanged received approach geometry, switching WYPT/TCN/ILS steering does not unexpectedly toggle the landing exemption.; Cue state updates while speech finishes, without obsolete roll commands replaying after the threat clears. |
| Limit | Exercise threshold oscillation, changes while below the setting, zero-disabled settings, gear transition and acknowledgement.; Rising terrain, obstacles, LOC-only reception, unstable approach and go-around do not gain an unqualified safe exemption.; Stale or over-budget terrain results show unavailable rather than clear. |
| Failure | Fail radar and pressure independently; selected warnings use their own healthy sources.; Lose terrain access or prediction inputs: the advisory shows unavailable and issues no flight-control command. |
| Recovery | Restore source validity under the declared crossing/rearm policy without replaying a stale event.; Go-around/approach exit clears the landing exemption as specified, without waiting for a source-selection change. |

</details>

<a id="pkg-nav-wp10"></a>
<a id="case-an26"></a>
<a id="record-l09"></a>
<a id="record-l22"></a>
<a id="record-l34"></a>
<a id="record-l35"></a>
<a id="record-l36"></a>
<a id="record-l37"></a>
<a id="record-l38"></a>
<a id="record-l39"></a>
<a id="record-l40"></a>
<a id="record-nav-29"></a>

### NAV-WP10 — Complete manual recovery, go-around and emergency landing interfaces

Complete supported manual field recovery under healthy/degraded navigation, including go-around, reconfiguration and vehicle emergency interfaces, without implying carrier capability or automatic landing.

- Define pilot-observable approach, recovery, go-around and touchdown state using achieved gear/lock, WOW, power, AoA, airspeed and receiver inputs. Keep procedure choice separate from automatic flight mode.
- Build controlled manual straight-in, overhead, ILS/LOC-only, TACAN and missed-approach scenarios from public/simulated capabilities. Declare unsupported procedures instead of inventing production F-22 techniques.
- Preserve complete dated Category E/conditional D criteria, separate CAS/TAS values and the hot/high caveat in training/reference material. The GINS terminal-use rule is not an automatic geofence or mode-deletion command.
- Qualify go-around reconfiguration: pilot thrust/pitch/gear actions change landing cues, exemptions, minima and assistance states according to the selected profile. Received ILS remains received data; no automatic TOGA is claimed.
- Handoff L34/L35 to vehicle AV09/PF18/AV34 work. Agree wheel-slip/navigation-deceleration inputs, achieved brake state and host anti-skid behavior. Evaluate the current drag-assist step before altering it; an enable flag alone cannot prove stopping accuracy.
- Handoff L36 to vehicle AV26/AV33 work. Public SES gear extension and pneumatic arresting gear require bounded game actions, finite energy and achieved locked/unsafe/hook feedback. Exact production controls, pressures and timing remain unknown.
- Make gear-command, position, downlock, WOW and approach thresholds intentional for each consumer. Do not replace them with one unqualified landing boolean.
- Coordinate brake, steering, SES and hook failure missions through the parent. This plan claims no observed host stopping or cable behavior.

**Keep:** Retain manual received ILS, gear/WOW cue gating, separate CAS/TAS and advisory-only terrain behavior.; Credit existing achieved brake outputs and native anti-skid publication until host behavior is qualified..

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/Nav_Guidance.lua`
- `Cockpit/Scripts/Systems/HUD_Flight_Data.lua`
- `Cockpit/Scripts/Systems/Flight_Guidance.lua`
- `Cockpit/Scripts/Systems/Pilot_Warning_System.lua`
- `EFM/source/RAPTOR.cpp`
- `EFM/source/VehicleSystems.h`
- `Vehicle-owned gear/SES/hook/braking model and controls`
- `docs/HUD_AND_SYSTEMS_TEST_PLAN.md`
- `Training/reference material and controlled recovery missions`

**Depends on:** [NAV-WP04](#pkg-nav-wp04), [NAV-WP05](#pkg-nav-wp05), [NAV-WP07](#pkg-nav-wp07), [NAV-WP08](#pkg-nav-wp08), [NAV-WP09](#pkg-nav-wp09), [VEH-09](#pkg-veh-09), [VEH-10](#pkg-veh-10).

**Audit findings:** [AN26](../audit/F22-Fidelity-Audit.html#auth-an26).

**Supporting records:** L09, L22, L34, L35, L36, L37, L38, L39, L40, NAV-29.

**References:**

- [AFMAN 11-2F-22A Volume 3, Operations Procedures](https://static.e-publishing.af.mil/production/1/af_a3/publication/afman11-2f-22av3/afman11-2f-22av3.pdf) — p26 §4.1; abnormal recovery context
- [T.O. 00-105E-9, historical F-22A rescue section](https://www.0x4d.net/files/AF1/R11%20Segment%2012.pdf) — Printed F-22A pp7, 10
- [USAF, F-22 endures 3-week cold-weather test at Eielson](https://www.af.mil/News/Article-Display/Article/125003/f-22-endures-3-week-cold-weather-test-at-eielson/) — Complete wheel-slip/navigation-deceleration paragraph
- [Chuck’s DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf) — pp770–773
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf) — pp48, 57

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Fly manual ILS with TCN steering retained and with IRS position unavailable; healthy cues remain and control stays manual.; Go around, reconfigure and reapproach without stuck minima, exemptions or hidden assistance.; Record normal rollout with declared mass/surface and achieved vehicle states. |
| Limit | Hot/high tests show distinct CAS/TAS and preserve full dated conditional criteria.; Crosswind, low friction, LOC-only and unavailable terrain have declared support limits.; Gear transit, WOW bounce and emergency extension cannot display down-and-locked early. |
| Failure | Engine/FCS or normal-extension failure uses the declared manual recovery/emergency chain, without automatic selection of 1998 test laws.; Lose primary navigation/display and verify independent remaining references.; Hook/brake unavailability is distinct from healthy ILS; host cable limits are documented. |
| Recovery | A new approach after go-around requires pilot intent and valid configuration; genuine minima events rearm.; SES depletion, repair and replenishment use the vehicle policy without infinite reserve or unsolicited reset. |

</details>

## Radar, fusion, electronic warfare and countermeasures

<a id="pkg-sen-02"></a>
<a id="case-as01"></a>
<a id="case-as02"></a>
<a id="case-as06"></a>
<a id="case-ae02"></a>
<a id="case-ae03"></a>
<a id="case-ae04"></a>
<a id="case-ae05"></a>
<a id="case-ae06"></a>
<a id="case-ae07"></a>
<a id="case-ae08"></a>
<a id="case-ae10"></a>
<a id="case-ae01"></a>
<a id="case-ae09"></a>
<a id="case-ae12"></a>
<a id="record-r01"></a>
<a id="record-r02"></a>
<a id="record-r03"></a>
<a id="record-r04"></a>
<a id="record-r12"></a>
<a id="record-r13"></a>
<a id="record-r14"></a>
<a id="record-r15"></a>
<a id="record-sc03"></a>

### SEN-02 — Represent finite AESA-like sensing service and degraded availability

Search coverage, selected-file service, passive cue requests, support load and degradation have visible finite update consequences without inventing measurements.

**Current issue ([AE01](../audit/F22-Fidelity-Audit.html#auth-ae01)):** A 2 s game scheduling phase is not an antenna-steering specification. Instantaneous Lua parameter changes also do not prove instantaneous detections. The previous audit had no explicit distinction.

- Separate electronic point-command response from measured detection, revisit and processing delay; do not force mechanical sweep traverse as an AESA identity feature.
- Define requested/achieved coverage and a finite game service budget for surveillance, selected/support tracks and cue dwells. Show restricted coverage when obligations cannot all be served.
- Document a mode-compatibility table for A/A search, STT and surface imaging. Either provide supported finite background service or explicitly indicate the retained native exclusive-mode restriction.
- Make manual centering, automatic centering, bias, preemption and recovery after target loss explicit; track memory is not proof of current sensor service.
- Connect normal/degraded/unavailable states to the declared damage/supply/cooling model. Characterize off-axis effects and LPI-like host observability before choosing qualitative game estimates.

**Keep:** Native cached samples and ages; Bounded RF cue dwell and manual authority; Real multi-ID support adapter.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/Radar_System.lua`
- `Cockpit/Scripts/Systems/Radar_Computer.lua`
- `Cockpit/Scripts/Systems/Radar_Sensor_Tasking.lua`
- `Cockpit/Scripts/Systems/Radar_Native.lua`
- `EFM/source/NativeSidewinder.cpp`
- Proposed: `Cockpit/Scripts/Systems/Radar_Service_State.lua`

**Depends on:** [SEN-01](#pkg-sen-01), [VEH-04](#pkg-veh-04), [VEH-11](#pkg-veh-11).

**Audit findings:** [AS01](../audit/F22-Fidelity-Audit.html#auth-as01), [AS02](../audit/F22-Fidelity-Audit.html#auth-as02), [AS06](../audit/F22-Fidelity-Audit.html#auth-as06), [AE02](../audit/F22-Fidelity-Audit.html#auth-ae02), [AE03](../audit/F22-Fidelity-Audit.html#auth-ae03), [AE04](../audit/F22-Fidelity-Audit.html#auth-ae04), [AE05](../audit/F22-Fidelity-Audit.html#auth-ae05), [AE06](../audit/F22-Fidelity-Audit.html#auth-ae06), [AE07](../audit/F22-Fidelity-Audit.html#auth-ae07), [AE08](../audit/F22-Fidelity-Audit.html#auth-ae08), [AE10](../audit/F22-Fidelity-Audit.html#auth-ae10), [AE01](../audit/F22-Fidelity-Audit.html#auth-ae01), [AE09](../audit/F22-Fidelity-Audit.html#auth-ae09), [AE12](../audit/F22-Fidelity-Audit.html#auth-ae12).

**Supporting records:** R01, R02, R03, R04, R12, R13, R14, R15, SC03.

**References:**

- [Ronald W. Brower, Lockheed F-22 Raptor, The Avionics Handbook chapter 32](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf) — p 8 section 32.3.2; p 11 recovery
- [NOAA NSSL, Research Tools: Phased Array Radar](https://www.nssl.noaa.gov/tools/radar/par/) — Electronic Steering/Rapid Scanning
- [Raytheon AN/APG-79 AESA Radar](https://www.rtx.com/raytheon/what-we-do/air/apg79aesa) — Multimode AESA overview
- [Chuck's DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf) — pp 187-190
- [Chuck's DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf) — pp 208-214

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Wider search or added service obligations produce the declared slower/restricted observation update while sensor ages remain honest.; Urgent selected/support service and manual input visibly affect remaining search coverage. |
| Limit | No number of designated files grants unlimited simultaneous beams; zoom and displayed range do not create contacts.; A/G INTL is not labeled A/A-plus-A/G concurrency without an active surviving A/A service. |
| Failure | Supply/cooling/resource faults cause the declared degraded availability; partial damage need not always equal total loss. |
| Recovery | Clearing load/fault restores service through the declared state transition without renewing old sample times. |

</details>

<a id="pkg-sen-03"></a>
<a id="case-as03"></a>
<a id="case-as05"></a>
<a id="case-as07"></a>
<a id="case-as04"></a>
<a id="case-as08"></a>
<a id="case-as09"></a>
<a id="case-ae13"></a>
<a id="record-r05"></a>
<a id="record-r06"></a>
<a id="record-r07"></a>
<a id="record-r08"></a>
<a id="record-r09"></a>
<a id="record-r10"></a>
<a id="record-r11"></a>
<a id="record-sc04"></a>
<a id="record-sc05"></a>
<a id="record-sc06"></a>

### SEN-03 — Complete track, acquisition and pilot selection behavior

Tentative, established, selected, acquired, coasting and expired targets remain distinct; primary/secondary and ACM controls have stable, explainable outcomes.

- Choose and document track promotion/missed-revisit rules; replace cumulative-hit-only maturity with the selected observable model while preserving actual sample timestamps.
- Separate displayed memory, eligible acquisition candidate and weapon-support authority. Publish age/quality consistently to scope, HUD and tactical join.
- Define ranked initial selection, stable cycle order, primary/secondary swap and return after loss; preserve actual native acquisition confirmation and timeout.
- Choose explicit ACM patterns. Retain useful current estimates under F-22-inspired names or adopt a named Hornet preset; resolve reference edition conflicts before claiming geometry parity.
- Keep target-centered expansion distinct from simple display zoom. Integrate all controls through the actually focused radar format, preserving weapon-global ACM commands.

**Keep:** Deduplication by native source and observation time; Native acquisition confirmation; Primary/secondary storage; Press/preview/release expansion behavior.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/Radar_Computer.lua`
- `Cockpit/Scripts/Systems/Radar_System.lua`
- `Cockpit/Scripts/Systems/Radar_Display.lua`
- `Cockpit/Scripts/Systems/Radar_STT.lua`
- `Cockpit/Scripts/Systems/Combat_Logic.lua`
- `Cockpit/Scripts/Systems/Sensor_Control.lua`

**Depends on:** [SEN-01](#pkg-sen-01), [SEN-02](#pkg-sen-02), [UI-01](#pkg-ui-01).

**Audit findings:** [AS03](../audit/F22-Fidelity-Audit.html#auth-as03), [AS05](../audit/F22-Fidelity-Audit.html#auth-as05), [AS07](../audit/F22-Fidelity-Audit.html#auth-as07), [AS04](../audit/F22-Fidelity-Audit.html#auth-as04), [AS08](../audit/F22-Fidelity-Audit.html#auth-as08), [AS09](../audit/F22-Fidelity-Audit.html#auth-as09), [AE13](../audit/F22-Fidelity-Audit.html#auth-ae13).

**Supporting records:** R05, R06, R07, R08, R09, R10, R11, SC04, SC05, SC06.

**References:**

- [Chuck's DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf) — pp 187-190
- [Chuck's DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf) — pp 208-220
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf) — pp 171-176
- [Ronald W. Brower, Lockheed F-22 Raptor, The Avionics Handbook chapter 32](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf) — p 8 multimode tracking role

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | A new return matures only from genuinely newer eligible observations; selected/secondary swap preserves identity.; Acquisition timeout and STT loss return to the declared saved mode. |
| Limit | Missed revisit differs from being outside searched coverage; a retained stale symbol is not a fresh hard lock.; Relocating the radar format does not change sensor controls or expansion commit semantics. |
| Failure | Lost/expired selected source clears or downgrades the correct state, without selecting an unrelated slot. |
| Recovery | Fresh reacquisition requires actual sensor evidence and restores the declared state, not cached identity alone. |

</details>

<a id="pkg-sen-04"></a>
<a id="case-as14"></a>
<a id="case-as16"></a>
<a id="case-as17"></a>
<a id="case-as18"></a>
<a id="case-sg03"></a>
<a id="case-as13"></a>
<a id="case-ae15"></a>
<a id="case-ae16"></a>
<a id="case-as15"></a>
<a id="record-p22"></a>
<a id="record-p23"></a>
<a id="record-p24"></a>
<a id="record-g01"></a>
<a id="record-g02"></a>
<a id="record-g03"></a>
<a id="record-g04"></a>
<a id="record-g05"></a>
<a id="record-g06"></a>
<a id="record-g07"></a>
<a id="record-g08"></a>
<a id="record-g09"></a>
<a id="record-g10"></a>
<a id="record-g11"></a>
<a id="record-g12"></a>
<a id="record-g13"></a>
<a id="record-g14"></a>
<a id="record-g15"></a>
<a id="record-g16"></a>
<a id="record-g17"></a>
<a id="record-g18"></a>
<a id="record-g19"></a>
<a id="record-sc23"></a>
<a id="record-sc24"></a>
<a id="record-sc25"></a>
<a id="record-sc26"></a>
<a id="record-g20"></a>

### SEN-04 — Surface radar, stabilized imagery and truthful ground designation

MAP/GMT/SEA/TA/AGR, EXP, HOLD/SIL and designation expose their actual sensing, geometry, age and fixed-point/object-track meaning.

- Retain source-referenced designation and distinct EXP1 snowplow versus EXP2/3 ground stabilization. Propagate native fixed/object result type so failed mover acquisition cannot masquerade as confirmed GMTT.
- Publish HOLD, transmitter inhibit, one active scan, reset and preview cancellation as separate state transitions; specify persistence across range/mode/master-mode changes.
- Characterize the renderer and latest EXP3 clearance geometry before selecting a SAR approximation. Add collecting/usable/held/degraded and image age if adopting a collection model; a preset alone does not prove SAR.
- Define moving/stopped target eligibility, acquisition failure, LOS memory and out-of-FOV return independently. Keep selected analogues and provisional memory values explicit.
- Differentiate FAST image quality/update, gain and PEN/FAN controls from true resolution. Keep TA as advisory sensing and AGR as qualified range, not an automatic avoidance controller.

**Keep:** Schema2 mode/range/epoch designation gate; Commit-on-release preview; Native LOS/object acquisition; Renderer-only EXP3 origin fix.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/AG_Radar_System.lua`
- `Cockpit/Scripts/Systems/AG_Radar_Modes.lua`
- `Cockpit/Scripts/Systems/AG_Radar_Computer.lua`
- `Cockpit/Scripts/Systems/AG_Mark_System.lua`
- `Cockpit/Scripts/Systems/MFD_Controls.lua`
- `EFM/source/NativeGroundSensor.cpp`
- `EFM/source/NativeGroundVideo.cpp`
- `EFM/source/GroundVideoView.h`

**Depends on:** [SEN-01](#pkg-sen-01), [SEN-02](#pkg-sen-02), [SEN-03](#pkg-sen-03), [VEH-02](#pkg-veh-02).

**Audit findings:** [AS14](../audit/F22-Fidelity-Audit.html#auth-as14), [AS16](../audit/F22-Fidelity-Audit.html#auth-as16), [AS17](../audit/F22-Fidelity-Audit.html#auth-as17), [AS18](../audit/F22-Fidelity-Audit.html#auth-as18), [SG03](../audit/F22-Fidelity-Audit.html#auth-sg03), [AS13](../audit/F22-Fidelity-Audit.html#auth-as13), [AE15](../audit/F22-Fidelity-Audit.html#auth-ae15), [AE16](../audit/F22-Fidelity-Audit.html#auth-ae16), [AS15](../audit/F22-Fidelity-Audit.html#auth-as15).

**Supporting records:** P22, P23, P24, G01, G02, G03, G04, G05, G06, G07, G08, G09, G10, G11, G12, G13, G14, G15, G16, G17, G18, G19, SC23, SC24, SC25, SC26, G20.

**References:**

- [Northrop Grumman F-22 SAR demonstration release](https://investor.northropgrumman.com/news-releases/news-release-details/northrop-grumman-completes-successful-demonstration-new) — 2008 SAR demonstration
- [NASA, Get to Know SAR - Overview](https://science.nasa.gov/mission/nisar/get-to-know-sar/) — Moving aperture/image formation
- [Chuck's DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf) — pp 237-254
- [Chuck's DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf) — pp 221,237,243

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Designating an on-screen patch produces coordinates from that exact mode/range/epoch and the indicated fixed/object source.; EXP modes retain their distinct stabilization; one active scan while silent returns to silence. |
| Limit | Frozen/stale/incompatible video cannot authorize a new coordinate from an unrelated scene.; Moving-target acquisition on empty terrain yields disclosed fixed hold/failure, never invented target motion. |
| Failure | Terrain masking, collection interruption and out-of-view loss show the declared degraded/memory state. |
| Recovery | Reset or reacquisition restores only the documented state; image preview cancellation does not fire or retarget a store. |

</details>

<a id="pkg-sen-05"></a>
<a id="case-as10"></a>
<a id="case-as11"></a>
<a id="case-as12"></a>
<a id="case-st01"></a>
<a id="record-r16"></a>
<a id="record-r17"></a>
<a id="record-r18"></a>
<a id="record-r19"></a>
<a id="record-d10"></a>
<a id="record-d11"></a>
<a id="record-sc07"></a>
<a id="record-sc08"></a>

### SEN-05 — Identification evidence and ownship transponder role

No reply, simulator-assisted classification, prior identity, donor evidence and contradictory identity remain distinguishable; ownship responding is independent from asking about contacts.

- Retain bare-STT nonresponse as no new hostile evidence. Mark complete native class values as simulator-assisted unless a declared game authentication/recognition event supplies the evidence.
- Add ambiguous/conflict presentation and evidence inspection with per-source age; maintain a separate friendly-protection policy instead of hiding contradictory evidence.
- Implement an abstract ownship responder state, incoming-reply indication and optional emergency-identification control through qualified host capabilities or explicitly labeled game events.
- Keep interrogation AUTO/SCAN/LOS requests separate from transponder state, PPLI and radar power; define surviving CNI behavior through the common supply/resource contract.
- Treat NCTR/Mode5 menus or detailed key controls as selected abstraction/research, with no real cryptography or copied Hornet recognition limits claimed as F-22 data.

**Keep:** Bare no-reply semantics; Timestamp-bounded scan/LOS acceptance; Continuous-track identity retention explicitly distinguished from new evidence.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/Radar_IFF.lua`
- `Cockpit/Scripts/Systems/Radar_System.lua`
- `Cockpit/Scripts/Systems/Tactical_Identity.lua`
- `Cockpit/Scripts/Systems/Tactical_Tracks.lua`
- `Cockpit/Scripts/Systems/UFC_Controller.lua`
- `Cockpit/Scripts/Systems/ICP_System.lua`
- Proposed: `Cockpit/Scripts/Systems/Identification_State.lua`

**Depends on:** [SEN-01](#pkg-sen-01).

**Audit findings:** [AS10](../audit/F22-Fidelity-Audit.html#auth-as10), [AS11](../audit/F22-Fidelity-Audit.html#auth-as11), [AS12](../audit/F22-Fidelity-Audit.html#auth-as12), [ST01](../audit/F22-Fidelity-Audit.html#auth-st01).

**Supporting records:** R16, R17, R18, R19, D10, D11, SC07, SC08.

**References:**

- [Ronald W. Brower, Lockheed F-22 Raptor, The Avionics Handbook chapter 32](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf) — pp 8-9 CNI
- [Chuck's DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf) — pp 639-646
- [Chuck's DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf) — pp 636-645
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf) — pp 62-63 and165
- [USAF FY2026 Aircraft Procurement Volume II, F-22 modification summary](https://www.saffm.hq.af.mil/Portals/84/documents/FY26/FY26%20Air%20Force%20Aircraft%20Procurement%20Vol%20II.pdf) — Mode5 modification listing

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Positive native friendly identity is distinct from no-positive reply; retained earlier classification is visibly identity memory.; Independent ownship responder availability/replies can be observed without issuing a contact interrogation. |
| Limit | No reply alone does not declare hostile; conflicting qualified sources become visibly ambiguous.; PPLI transmission is not displayed as proof of a transponder reply. |
| Failure | Expired identity and failed responder capability yield unknown/unavailable rather than invented authentication. |
| Recovery | Supply/resource restoration follows the declared identification state and does not replay old requests. |

</details>

<a id="pkg-sen-06"></a>
<a id="case-as25"></a>
<a id="case-as26"></a>
<a id="case-as27"></a>
<a id="case-ae14"></a>
<a id="case-sg06"></a>
<a id="record-r20"></a>
<a id="record-d01"></a>
<a id="record-d02"></a>
<a id="record-d03"></a>
<a id="record-d04"></a>
<a id="record-d05"></a>
<a id="record-d06"></a>
<a id="record-d07"></a>
<a id="record-d08"></a>
<a id="record-d09"></a>
<a id="record-d12"></a>
<a id="record-d13"></a>
<a id="record-d14"></a>
<a id="record-d15"></a>
<a id="record-sc02"></a>
<a id="record-sc09"></a>
<a id="record-sc10"></a>
<a id="record-sc11"></a>
<a id="record-sc12"></a>
<a id="record-sc13"></a>

### SEN-06 — Source-qualified fusion, datalink memory and donor-track interaction

Every displayed position/direction/identity has a source and age; an offboard target can be inspected and followed without silently becoming a local radar measurement or weapon authority.

- Carry receipt time and known/unknown observation time separately. Preserve source-local ages and distinguish measured, extrapolated and held states on TSD and DEF.
- Add a persistent awareness-only donor selection with source/age inspection, accept/reject and handoff request to actual local acquisition.
- Preserve ordinary Link 16 receive and declared custom peer exchange; version any optional external transmission extension separately.
- Keep participant/PPLI, target reports, exact-ID association and display capacity distinct. Publish overflow/filter behavior without discarding hidden sensing merely because a view is cluttered.
- Define reset/epoch, disconnect and source-conflict behavior. Never fill missing received target coordinates through world-object lookup or silently grant remote fire-control authority.

**Keep:** Message-derived target coordinates; Ordinary receive-only external link; Custom peer message subset; Source-local fields and age; No remote-track relay in local radar broadcast.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/Datalink_Tracks.lua`
- `Cockpit/Scripts/Systems/Tactical_Tracks.lua`
- `Cockpit/Scripts/Systems/Tactical_Situation.lua`
- `Cockpit/Scripts/Systems/Tactical_Picture.lua`
- `Cockpit/Scripts/Systems/Defensive_Overview.lua`
- `Cockpit/Scripts/Systems/EW_Defensive.lua`
- `EFM/source/NativeDatalink.cpp`

**Depends on:** [SEN-01](#pkg-sen-01), [SEN-05](#pkg-sen-05), [VEH-02](#pkg-veh-02).

**Audit findings:** [AS25](../audit/F22-Fidelity-Audit.html#auth-as25), [AS26](../audit/F22-Fidelity-Audit.html#auth-as26), [AS27](../audit/F22-Fidelity-Audit.html#auth-as27), [AE14](../audit/F22-Fidelity-Audit.html#auth-ae14), [SG06](../audit/F22-Fidelity-Audit.html#auth-sg06).

**Supporting records:** R20, D01, D02, D03, D04, D05, D06, D07, D08, D09, D12, D13, D14, D15, SC02, SC09, SC10, SC11, SC12, SC13.

**References:**

- [Ronald W. Brower, Lockheed F-22 Raptor, The Avionics Handbook chapter 32](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf) — pp 8-9 CNI roles
- [Chuck's DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf) — pp 603-607
- [Chuck's DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf) — pp 636-637
- [Matt Wagner/Eagle Dynamics Viper Primary Datalink Track tutorial](https://www.youtube.com/watch?v=qCEFHf01FvI) — Primary datalink track tutorial caption 12-30 s

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Donor-only target can be selected, inspected, followed and handed to local search; local acquisition still requires actual observations.; TSD and DEF consistently show coasting/held data and original versus receive-time provenance. |
| Limit | An old report newly received is not labeled a fresh observation when its observation time is unknown.; 64 received inputs, 16 DEF objects and filtered display count are separate capacity contracts. |
| Failure | Link loss and invalid/unsupported snapshots age or clear only their own evidence without granting live track authority. |
| Recovery | Reconnection/epoch change begins a new source lifecycle with no stale source selection or duplicated retransmission loop. |

</details>

<a id="pkg-sen-07"></a>
<a id="case-as19"></a>
<a id="case-as20"></a>
<a id="case-as23"></a>
<a id="case-as24"></a>
<a id="case-ae11"></a>
<a id="record-e01"></a>
<a id="record-e02"></a>
<a id="record-e03"></a>
<a id="record-e04"></a>
<a id="record-e05"></a>
<a id="record-e06"></a>
<a id="record-e07"></a>
<a id="record-e12"></a>
<a id="record-e13"></a>
<a id="record-e14"></a>
<a id="record-e15"></a>
<a id="record-sc14"></a>
<a id="record-sc15"></a>
<a id="record-sc16"></a>
<a id="record-e10"></a>
<a id="record-e11"></a>
<a id="record-sc22"></a>

### SEN-07 — Integrated passive warning with explicit optional jammer state

RF and passive IR warnings identify their source, uncertainty, fresh/coast state and escalation; optional jammer request is not confused with proven instantaneous radiation.

- Retain independently powered passive sensing while the radar is silent. Keep measured bearing/proximity, estimated stationary-ground location and optical warning roles separate.
- Characterize aperture masking and add declared detection/declaration/track/loss degradation without claiming calibrated ALR-94/AAR-56 performance or turning every warning into an aircraft IRST track.
- Provide distinct custom new-emitter/class/escalation audio and source-age inspection; respect the shared warning-priority contract and keep history advancing while muted.
- For optional active ECM, expose requested, host-enabled, qualified transmitting/unknown, pending and failed states. Do not copy Hornet radar blanking or pod-mode hardware as an F-22 fact.
- Keep EW location/radar cueing source-qualified; do not implement actual emitter-location, threat-library or countermeasure-effectiveness algorithms.

**Keep:** No coalition inferred from emitter-name mapping; RF direction qualification; MWS independent source; Audio history maintained while muted; Separate jammer request/readback/pending.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/RWR_System.lua`
- `Cockpit/Scripts/Systems/RWR_Native.lua`
- `Cockpit/Scripts/Systems/RWR_Computer.lua`
- `Cockpit/Scripts/Systems/RWR_Audio.lua`
- `Cockpit/Scripts/Systems/RWR_Bearings.lua`
- `Cockpit/Scripts/Systems/EW_Geolocation.lua`
- `Cockpit/Scripts/Systems/MWS_System.lua`
- `Cockpit/Scripts/Systems/MWS_Native.lua`
- `Cockpit/Scripts/Systems/EW_System.lua`
- `EFM/source/NativeMWS.cpp`

**Depends on:** [SEN-01](#pkg-sen-01), [SEN-05](#pkg-sen-05), [SEN-06](#pkg-sen-06).

**Audit findings:** [AS19](../audit/F22-Fidelity-Audit.html#auth-as19), [AS20](../audit/F22-Fidelity-Audit.html#auth-as20), [AS23](../audit/F22-Fidelity-Audit.html#auth-as23), [AS24](../audit/F22-Fidelity-Audit.html#auth-as24), [AE11](../audit/F22-Fidelity-Audit.html#auth-ae11).

**Supporting records:** E01, E02, E03, E04, E05, E06, E07, E12, E13, E14, E15, SC14, SC15, SC16, E10, E11, SC22.

**References:**

- [Ronald W. Brower, Lockheed F-22 Raptor, The Avionics Handbook chapter 32](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf) — pp 9-10 EW roles
- [BAE Systems AN/ALR-94 F-22 Electronic Warfare System](https://www.baesystems.com/en-us/product/an-alr-94) — Warning/location and targeting support
- [Chuck's DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf) — pp 575-599
- [Chuck's DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf) — pp 600-616

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Fresh RF and optical warnings feed the common mission picture with distinct meanings and source-local age.; Radar silence leaves qualified passive warnings available. |
| Limit | A coasting optical warning is not a fresh inbound declaration; RF intensity is not exact range.; Generic ECM status is host enabled unless instantaneous transmission semantics are qualified. |
| Failure | Masked/lost apertures and receiver failures produce visible limited/unavailable coverage under the selected game model. |
| Recovery | Recovery produces current warnings without replaying a mute backlog or refreshing old observations. |

</details>

<a id="pkg-sen-08"></a>
<a id="case-as21"></a>
<a id="case-as22"></a>
<a id="case-cp02"></a>
<a id="case-cp03"></a>
<a id="case-cp04"></a>
<a id="case-cp05"></a>
<a id="case-cp06"></a>
<a id="case-cp07"></a>
<a id="case-cp08"></a>
<a id="case-cp09"></a>
<a id="case-cp10"></a>
<a id="case-cp11"></a>
<a id="case-cp01"></a>
<a id="record-e08"></a>
<a id="record-e09"></a>
<a id="record-sc17"></a>
<a id="record-sc18"></a>
<a id="record-sc19"></a>
<a id="record-sc20"></a>
<a id="record-sc21"></a>

### SEN-08 — Complete the declared countermeasure control lifecycle

MAN/SEMI/AUTO, consent, selected/direct-access programs, editing, readiness and inventory have complete visible and recoverable game-state behavior.

**Current issue ([CP03](../audit/F22-Fidelity-Audit.html#auth-cp03)):** Changing the visible PROG selection changes which bank is edited, but not what the normal up action runs. Bank count itself has no verified F-22 specification.

- Adopt the existing flat Hornet-like CHAF/FLAR/INT/cycles schema as the initial substitute. Name total cycles explicitly; keep three extensible banks as a mod estimate. Independent Viper BQ/BI/SQ/SI is an optional schema extension, not a universal requirement.
- Implement draft/edit/validate/SAVE/cancel and separate edit selection, normal-dispense bank and direct-access bank. Committed running sequences retain an immutable snapshot.
- Add OFF/STBY/ready/self-test/failure state separate from inventory/API validity. Choose the supply for direct emergency/bypass separately; do not claim independence without a distinct path.
- Implement the publicly documented MAN/SEMI/AUTO roles using neutral scripted game events and user programs. Expose awaiting consent, authorized, executing and revoked; no operational threat-to-program selection recipe is specified.
- Define retrigger/stop/power interruption/partial exhaustion semantics and requested/started/completed/empty/low feedback. Separate refill, preset persistence and new mission reset.

**Keep:** Actual host chaff/flare counts; Bounded editable quantities; Committed run snapshot; Main-power interruption clears running bursts.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/EW_Programs.lua`
- `Cockpit/Scripts/Systems/EW_System.lua`
- `Cockpit/Scripts/Systems/Combat_System.lua`
- `Cockpit/Scripts/Systems/Combat_Logic.lua`
- `Cockpit/Scripts/Systems/EW_Indicator.lua`
- `Cockpit/Scripts/Systems/MFD_Controls.lua`
- Proposed: `Cockpit/Scripts/Systems/Countermeasure_State.lua`

**Depends on:** [SEN-01](#pkg-sen-01), [SEN-07](#pkg-sen-07), [ALR-02](#pkg-alr-02).

**Audit findings:** [AS21](../audit/F22-Fidelity-Audit.html#auth-as21), [AS22](../audit/F22-Fidelity-Audit.html#auth-as22), [CP02](../audit/F22-Fidelity-Audit.html#auth-cp02), [CP03](../audit/F22-Fidelity-Audit.html#auth-cp03), [CP04](../audit/F22-Fidelity-Audit.html#auth-cp04), [CP05](../audit/F22-Fidelity-Audit.html#auth-cp05), [CP06](../audit/F22-Fidelity-Audit.html#auth-cp06), [CP07](../audit/F22-Fidelity-Audit.html#auth-cp07), [CP08](../audit/F22-Fidelity-Audit.html#auth-cp08), [CP09](../audit/F22-Fidelity-Audit.html#auth-cp09), [CP10](../audit/F22-Fidelity-Audit.html#auth-cp10), [CP11](../audit/F22-Fidelity-Audit.html#auth-cp11), [CP01](../audit/F22-Fidelity-Audit.html#auth-cp01).

**Supporting records:** E08, E09, SC17, SC18, SC19, SC20, SC21.

**References:**

- [Ronald W. Brower, Lockheed F-22 Raptor, The Avionics Handbook chapter 32](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf) — p 9 automatic/semiautomatic/manual sentence
- [Chuck's DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf) — pp 610-612
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf) — pp 408-410
- [Chuck's DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf) — pp 586-587,591-592

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Committed selected-bank and named direct-access actions execute the indicated program and report which one actually runs.; SEMI waits for the declared pilot consent; AUTO follows its visible authorized state on a neutral test event. |
| Limit | Invalid draft cannot replace a committed bank; edits do not mutate the current run.; One exhausted category cannot produce a falsely completed mixed program; cycles include the first event exactly as labeled. |
| Failure | Power loss, stop or readiness failure cancels according to policy; revoke gates future automatic starts without an unstated resume. |
| Recovery | Refill/power restoration does not resume an interrupted sequence. Saved settings and replenished inventory recover independently. |

</details>

## Weapons and fire control

<a id="pkg-sen-09"></a>
<a id="case-as30"></a>
<a id="case-as31"></a>
<a id="case-as32"></a>
<a id="case-as33"></a>
<a id="case-as34"></a>
<a id="case-as35"></a>
<a id="case-sg04"></a>
<a id="record-p25"></a>
<a id="record-p26"></a>
<a id="record-p27"></a>
<a id="record-p28"></a>
<a id="record-w01"></a>
<a id="record-w02"></a>
<a id="record-w10"></a>
<a id="record-w14"></a>
<a id="record-w15"></a>
<a id="record-w16"></a>
<a id="record-w17"></a>
<a id="record-w18"></a>
<a id="record-w19"></a>
<a id="record-w20"></a>
<a id="record-sc27"></a>
<a id="record-sc28"></a>
<a id="record-sc29"></a>
<a id="record-sc32"></a>
<a id="record-sc33"></a>
<a id="record-sc34"></a>

### SEN-09 — Stores, target missions and release transactions

A station has explicit inventory, generation, power/init, mission, supported settings and release state; consent is tied to the mission actually assigned and does not survive jettison or replacement.

**Current issue ([SG04](../audit/F22-Fidelity-Audit.html#auth-sg04)):** Station assignments genuinely exist. Release-consent invalidation is broader than the assignment provenance: a radar mover or unrelated HUD target can cancel a captured-station program. No source justifies treating those targets as the same mission object.

- Add per-station initialization/health and explicit PP-like captured mission versus live TOO assignment, coordinate/elevation inspection and named mission slots. Preserve source/sequence qualification through the transfer.
- Bind consent invalidation to the assigned mission/station rather than an unrelated global live target sequence; retain deliberate cancel/reconsent when the assigned data actually changes.
- Transfer only supported per-store fuze/settings through qualified host interfaces and show unsupported controls honestly. Add a distinct SIM training state that preserves actual stores.
- Cancel pending program/held consent before jettison and prevent jettison/service count changes from acknowledging delivered shots. Keep matching native evidence and delayed-inventory quarantine.
- Separate structural repair, same-type replacement/rearm and full mission teardown. Preserve mission profiles deliberately, invalidate instance readiness/lock/consent on a qualified replacement, and retain existing full native reset.
- Keep estimated LAR/release advice visibly qualified. Use supported host data and a declared cue contract, without developing a real guided-weapon release or trajectory algorithm.

**Keep:** Explicit capability allowlist; Captured per-station targets; Native shot identities and cache sequence checks; Station quarantine; Achieved bay/hydraulic release interlock; Full teardown resets native support/seeker history.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/Weapon_System.lua`
- `Cockpit/Scripts/Systems/AG_Stores.lua`
- `Cockpit/Scripts/Systems/Store_Capabilities.lua`
- `Cockpit/Scripts/Systems/AG_Delivery.lua`
- `Cockpit/Scripts/Systems/AG_Ballistic_Computer.lua`
- `Cockpit/Scripts/Systems/AG_Mark_System.lua`
- `EFM/source/NativeAGWeapons.cpp`
- `EFM/source/NativeSidewinder.cpp`
- `EFM/source/RAPTOR.cpp`
- Proposed: `Cockpit/Scripts/Systems/Store_Lifecycle.lua`

**Depends on:** [SEN-01](#pkg-sen-01), [SEN-04](#pkg-sen-04), [SEN-06](#pkg-sen-06).

**Audit findings:** [AS30](../audit/F22-Fidelity-Audit.html#auth-as30), [AS31](../audit/F22-Fidelity-Audit.html#auth-as31), [AS32](../audit/F22-Fidelity-Audit.html#auth-as32), [AS33](../audit/F22-Fidelity-Audit.html#auth-as33), [AS34](../audit/F22-Fidelity-Audit.html#auth-as34), [AS35](../audit/F22-Fidelity-Audit.html#auth-as35), [SG04](../audit/F22-Fidelity-Audit.html#auth-sg04).

**Supporting records:** P25, P26, P27, P28, W01, W02, W10, W14, W15, W16, W17, W18, W19, W20, SC27, SC28, SC29, SC32, SC33, SC34.

**References:**

- [Ronald W. Brower, Lockheed F-22 Raptor, The Avionics Handbook chapter 32](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf) — p 10 SMS
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf) — pp 330-334
- [Chuck's DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf) — pp 571-573
- [Chuck's DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf) — Stores and GPS-weapon chapters

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Captured station mission stays stable while an unrelated live sensor mark moves; TOO follows its declared update/reconsent policy.; Actual release acknowledgment advances the intended program once and only once. |
| Limit | SAFE/SIM/WoW/configuration blockers revoke release authority; SIM preserves stores.; Jettison/service inventory decrease cannot advance a pending delivery or grant a remaining store fresh consent.; Same-type replacement without a sampled zero is not silently assumed to be the same weapon instance. |
| Failure | Failed transfer/alignment/partial jettison leaves accurate status and cancelled stale consent; uncertain inventory remains quarantined. |
| Recovery | Repair, reload and mission restart follow separate declared policies; no delayed acknowledgment authorizes the next transaction. |

</details>

<a id="pkg-sen-10"></a>
<a id="case-as28"></a>
<a id="case-as29"></a>
<a id="case-sg01"></a>
<a id="case-sg02"></a>
<a id="case-sg12"></a>
<a id="record-w05"></a>
<a id="record-w06"></a>
<a id="record-sc30"></a>
<a id="record-sc31"></a>

### SEN-10 — Internal-bay IR weapon readiness and cueing

Radar cue, launcher exposure, native seeker search/acquisition, range-qualified advice and launch consent remain separate states for each selected installation.

- Retain native power/init and real acquisition, including radar-independent IR employment. Show seeker lock even when radar-derived range/SHOOT advice is unavailable.
- Tie optical sensing availability to the declared achieved exposure/launcher state or visibly document the retained compatibility approximation; a stored cue can remain while acquisition is unavailable.
- Define cage/uncage/re-slave and radar-retarget behavior without clearing an already autonomous seeker merely to copy the new radar target.
- Keep the held-release station-change guard and add qualified store-generation resets. Model cooling/resource state only for the applicable selected installation.
- Research host support for a distinct optional Block II LOAL workflow. If supported, plan cue-before-launch and postlaunch unknown/acquiring/qualified status as abstract host-driven states; do not invent range, seeker or guidance logic to bypass an unavailable API.

**Keep:** Native rather than fabricated IR lock; Radar-off launch capability; World-beam projection; Autonomous acquired head retained; Held-release reconstruction guard.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/Weapon_System.lua`
- `Cockpit/Scripts/Systems/IR_Seeker.lua`
- `Cockpit/Scripts/Systems/IR_Audio.lua`
- `EFM/source/NativeSidewinder.cpp`

**Depends on:** [SEN-01](#pkg-sen-01), [SEN-03](#pkg-sen-03), [SEN-09](#pkg-sen-09), [ALR-02](#pkg-alr-02).

**Audit findings:** [AS28](../audit/F22-Fidelity-Audit.html#auth-as28), [AS29](../audit/F22-Fidelity-Audit.html#auth-as29), [SG01](../audit/F22-Fidelity-Audit.html#auth-sg01), [SG02](../audit/F22-Fidelity-Audit.html#auth-sg02), [SG12](../audit/F22-Fidelity-Audit.html#auth-sg12).

**Supporting records:** W05, W06, SC30, SC31.

**References:**

- [Ronald W. Brower, Lockheed F-22 Raptor, The Avionics Handbook chapter 32](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf) — p 10 SMS
- [Chuck's DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf) — pp 538-540
- [Chuck's DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf) — pp 580-586
- [Raytheon AIM-9X Sidewinder product description](https://www.rtx.com/en/raytheon/what-we-do/sea/aim-9x-sidewinder-missile) — Block II/Multiple platforms
- [NAVAIR AIM-9X Block II full-rate production milestone](https://www.navair.navy.mil/node/22731) — Block II milestone

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | An exposed, powered native IR seeker acquires without own radar; actual seeker state and any independent range-qualified advice are distinct.; An acquired autonomous seeker remains sourced separately when radar selection changes. |
| Limit | Station/type change with release held cannot create a new firing press.; Unavailable/covered seeker does not claim acquisition from the existence of a cue; unknown range does not become in-range advice. |
| Failure | Power, exposure, lock or store-instance loss removes the correct permission/state without a queued unintended release. |
| Recovery | Recage/reload/restored supply reconstructs only the intended native lifecycle and requires deliberate fresh consent. |

</details>

<a id="pkg-sen-11"></a>
<a id="case-sg05"></a>
<a id="case-sg08"></a>
<a id="case-sg09"></a>
<a id="case-sg10"></a>
<a id="case-sg11"></a>
<a id="case-sg07"></a>
<a id="record-w07"></a>
<a id="record-w08"></a>
<a id="record-w09"></a>
<a id="record-w11"></a>
<a id="record-w12"></a>
<a id="record-w13"></a>

### SEN-11 — Truthful engagement support, missile feedback and gun presentation

Cue labels accurately distinguish current support authority, retained target memory, estimated timing and qualified feedback; gun references survive a lock-without-valid-solution handover.

- Derive support indication from the active custom/native support owner through A/A-to-A/G changes, accounting explicitly for any qualified native fallback.
- Separate cockpit estimates/qualified telemetry from diagnostic own-missile world truth. An acquired-ever latch cannot be labeled current continuous seeker lock.
- Define whether SHOOT is anticipatory kinematic advice or immediate release eligibility; display persistent configuration/WoW/actuator blockers separately without unnecessarily requiring already-open doors for anticipatory advice.
- Keep stale/invalid gun lead hidden, but preserve a declared noncomputed reference in lock-present/solution-absent states. Add disclosed fixed span or deliberate pilot span entry for the funnel.
- Decide optional no-track MRM VISUAL/BORE employment through the native weapon service. Do not fabricate a local target or treat a donor-only awareness track as weapon authority.

**Keep:** Actual multi-target support identity; Native gun computation and real ammunition count; Separate dynamic and nominal envelope provenance; Estimated numeric timer marking.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/Engagement_System.lua`
- `Cockpit/Scripts/Systems/Weapon_Engagement.lua`
- `Cockpit/Scripts/Systems/Gun_Director.lua`
- `Cockpit/Scripts/Systems/Gun_Funnel.lua`
- `Cockpit/Scripts/Systems/Gun_Funnel_Presentation.lua`
- `Cockpit/Scripts/HUD/engagement.lua`
- `EFM/source/NativeSidewinder.cpp`
- `EFM/source/NativeGunSight.cpp`
- `EFM/source/NativeSTTMotion.h`

**Depends on:** [SEN-02](#pkg-sen-02), [SEN-03](#pkg-sen-03), [SEN-09](#pkg-sen-09), [SEN-10](#pkg-sen-10).

**Audit findings:** [SG05](../audit/F22-Fidelity-Audit.html#auth-sg05), [SG08](../audit/F22-Fidelity-Audit.html#auth-sg08), [SG09](../audit/F22-Fidelity-Audit.html#auth-sg09), [SG10](../audit/F22-Fidelity-Audit.html#auth-sg10), [SG11](../audit/F22-Fidelity-Audit.html#auth-sg11), [SG07](../audit/F22-Fidelity-Audit.html#auth-sg07).

**Supporting records:** W07, W08, W09, W11, W12, W13.

**References:**

- [Ronald W. Brower, Lockheed F-22 Raptor, The Avionics Handbook chapter 32](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf) — pp 10-11 SMS/attack display
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf) — pp 288,292-295
- [Chuck's DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf) — pp 576-598
- [Chuck's DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf) — pp 528-536,553

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Support status changes with actual surviving service, not only a remembered target; estimated timer and qualified feedback labels have explicit provenance.; Gun hard-lock/no-solution transition preserves the chosen noncomputed reference and never displays invalid lead as current. |
| Limit | Lost seeker feedback is unknown/current-lost, not automatically inferred from an acquired-ever latch.; Radar-off/no-track modes do not bypass arming, configuration or supported-native launch constraints. |
| Failure | Stale motion cache, lost support and missing weapon feedback produce declared degraded/unknown cues. |
| Recovery | Fresh qualified data restores the correct cue without rewriting old sample timestamps or implying a confirmed hit. |

</details>

## Cockpit, communications and alerts

<a id="pkg-ui-01"></a>
<a id="case-ax11"></a>
<a id="record-p02"></a>
<a id="record-p04"></a>

### UI-01 — Unify focus and held-input routing on every display

Any relocated sensor format receives page-dependent HOTAS control only when focused, while intentional weapon-global/HUD ACM actions remain global.

**Current issue ([AX11](../audit/F22-Fidelity-Audit.html#auth-ax11)):** The common display/focus owner permits radar on SOI 2/3/4/5, while both A-G axis dispatch and A-A cursor update still accept only 0/2. Moving radar to a side/center display can leave a valid designation action but suppress analog slew. This is a complete-path discrepancy, not a claim that real F-22 HOTAS labels equal Viper labels.

- Allocate command namespaces before extending controls. The captured keyboard light options10505–10512 are global and overlap an earlier EFM10500–10525 AFCS handler. Migrate the advertised light bindings/dispatch with compatibility notes and negative tests proving lights cannot engage/adjust AFCS. No saved profile activation or prior flight cause is inferred.
- Replace final-owner SOI0/2 gates for page cursor axes with the common focused-format authority predicate; cover A-A and A-G paths separately.
- Keep global GUN/SRM TMS/ACM exceptions explicit in the command table. Separate preview/corral from actual designation and execute only the intended transition.
- Audit mouse, keyboard, joystick and axis event semantics as press/release, impulse or continuous. Preserve existing missing-release fixes and avoid synthesizing endless down commands.
- Qualify the physical bezel labels, selected boxes and action ownership from the same control definition; log command/focus/target changes only when useful.

**Keep:** Current shared bezel/controller and original-owner release routing; Weapon-global ACM exception.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/MFD_Controller.lua`
- `Cockpit/Scripts/Systems/Sensor_Control.lua`
- `Cockpit/Scripts/Systems/Radar_System.lua`
- `Cockpit/Scripts/Systems/Combat_Logic.lua`
- `Cockpit/Scripts/clickabledata.lua`
- `Input/F-22A/joystick/default.lua`
- `Input/F-22A/keyboard/default.lua`
- `EFM/source/Autopilot.h`
- `EFM/source/RAPTOR.cpp`

**Depends on:** [ARC-02](#pkg-arc-02), [ARC-03](#pkg-arc-03).

**Audit findings:** [AX11](../audit/F22-Fidelity-Audit.html#auth-ax11).

**Supporting records:** P02, P04.

**References:**

- [Ronald W. Brower (USAF), Lockheed F-22 Raptor, The Avionics Handbook](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf)
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf)
- [Chuck’s DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf)
- [Chuck’s DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Move radar to LMFD, RMFD, CMFD and PMFD, focus it, slew and designate in both roles. |
| Limit | Focus a passive page while slew is held; the invisible radar stops responding without blocking deliberate global ACM commands. Exercise every advertised light command and assert AFCS state remains unchanged. |
| Failure | Power/focus/page loss releases the original owner and cannot latch cursor, designate or trigger. |
| Recovery | Reopen the format and deliberately press again; no old press or preview is committed. |

</details>

<a id="pkg-ui-02"></a>
<a id="case-ax12"></a>
<a id="case-ax13"></a>
<a id="record-p19"></a>
<a id="record-p20"></a>
<a id="record-p21"></a>

### UI-02 — Make numeric transactions acknowledge the committed setting

Every edit has a truthful draft, validation result, correlated commit and achieved readback in matching units.

**Current issue ([AX12](../audit/F22-Fidelity-Audit.html#auth-ax12)):** Explicit draft/commit/error concepts correspond; key choreography is a custom policy, not a documented F-22 defect. The heading readback unit error is a separate confirmed implementation inconsistency: a successfully applied nonzero target can falsely time out.

- Correct heading readback conversion: F22_AP_HEADING is already degrees in the captured publication. Preserve circular heading comparison and magnetic/true reference handling.
- Replace waypoint-ID-only acceptance with a request/commit sequence and accepted id/lat/lon/elevation values; never mark a dropped same-ID edit ENTERED.
- Apply the sequence/status contract to stores, TACAN, ILS, course, altimeter and radio edits. Distinguish local validation error, owner rejection, pending, timeout and completion.
- Retain same-option numeric submission as the declared mod policy; document clear-all, delete-digit, cancel and backout consistently. Hornet CLR second-press behavior is an optional substitute, not established F-22 hardware behavior.
- Keep the ENTRY_FIELD-zero stores completion check and repeated-button/digit release fixes. Cancel drafts on authority/profile/station/power changes.

**Keep:** Single draft owner; Stores completion waits for ENTRY_FIELD zero; Repeated input release improvements.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/UFC_Controller.lua`
- `Cockpit/Scripts/Systems/ICP_System.lua`
- `Cockpit/Scripts/Systems/Nav_Entry.lua`
- `Cockpit/Scripts/Systems/AG_Stores.lua`
- `EFM/source/RAPTOR.cpp`

**Depends on:** [ARC-02](#pkg-arc-02), [ARC-03](#pkg-arc-03).

**Audit findings:** [AX12](../audit/F22-Fidelity-Audit.html#auth-ax12), [AX13](../audit/F22-Fidelity-Audit.html#auth-ax13).

**Supporting records:** P19, P20, P21.

**References:**

- [Ronald W. Brower (USAF), Lockheed F-22 Raptor, The Avionics Handbook](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf)
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf)
- [Chuck’s DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf)
- [Chuck’s DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Submit 0, 1, 90, 123 and 359 degree headings; each valid achieved setting acknowledges correctly. Commit a same-ID waypoint coordinate change and a stores quantity change. |
| Limit | Enter the already-current value and confirm only after this request finishes; reject out-of-range and malformed values without changing the achieved state. |
| Failure | Drop/delay/reorder a response or cancel while pending; no false ENTERED and no orphaned late application. |
| Recovery | A fresh request after restoration succeeds and displays only its own status. |

</details>

<a id="pkg-ui-03"></a>
<a id="case-ax01"></a>
<a id="case-ax09"></a>
<a id="case-ax10"></a>
<a id="case-ax14"></a>
<a id="record-p01"></a>
<a id="record-p03"></a>
<a id="record-p05"></a>
<a id="record-p09"></a>
<a id="record-p10"></a>
<a id="record-p11"></a>
<a id="record-p12"></a>
<a id="record-p15"></a>
<a id="record-p18"></a>

### UI-03 — Preserve flexible layouts and qualify actual presentation

Offensive, defensive, tactical-navigation and vehicle/stores tasks remain available on surviving powered displays with coherent shared/local state.

- Retain duplicate formats and persistent pilot layouts by default. Record startup layout as a mod choice; publish optional task presets rather than asserting historical role descriptions mandate a boot layout.
- Define local range/declutter/inspection/cursor behavior versus shared target and sensor modes; changing one panel cannot secretly retune or re-task another sensor.
- Retain existing physical brightness control grouping; calibrate video/symbol gain separately if supported. Treat night factor0.18 and color thresholds as estimates.
- Make all readouts consume validity and actual units; show unavailable rather than a misleading zero. Check clipped labels, overlap, selected boxes, font contrast and every supported cockpit resolution.
- Trace every referenced cockpit/external draw argument into the actual EDM/material/controller chain before claiming that an indication or projector is absent. Keep fault state independent of brightness.

**Keep:** Shared format library; Independent panel selection; Separate warning content and presentation gain.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/Display_Routing.lua`
- `Cockpit/Scripts/Systems/MFD_Controller.lua`
- `Cockpit/Scripts/MFD_COMMON/formats.lua`
- `Cockpit/Scripts/Systems/Avionics.lua`
- `Cockpit/Scripts/UFD_LEFT/base_page.lua`

**Depends on:** [ARC-01](#pkg-arc-01), [ARC-02](#pkg-arc-02), [UI-01](#pkg-ui-01), [VEH-04](#pkg-veh-04).

- Integration: VEH-14/07: achieved/damaged/saturated FCS effectors. VEH-11: pressure/reference/validity. NAV-WP04: shared HUD cue geometry.

**Audit findings:** [AX01](../audit/F22-Fidelity-Audit.html#auth-ax01), [AX09](../audit/F22-Fidelity-Audit.html#auth-ax09), [AX10](../audit/F22-Fidelity-Audit.html#auth-ax10), [AX14](../audit/F22-Fidelity-Audit.html#auth-ax14).

**Supporting records:** P01, P03, P05, P09, P10, P11, P12, P15, P18.

**References:**

- [Ronald W. Brower (USAF), Lockheed F-22 Raptor, The Avionics Handbook](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf)
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf)
- [Chuck’s DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf)
- [Chuck’s DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Duplicate a sensor task, move vehicle status, swap tertiary displays and recover a needed task on a surviving screen. |
| Limit | At minimum/maximum brightness and day/night mode, fault state remains intact and local view changes follow policy. |
| Failure | Screen/power loss removes presentation availability without erasing independent physical state. |
| Recovery | Restored display uses the declared memory policy and fresh producer validity, without held commands. |

</details>

<a id="pkg-ui-04"></a>
<a id="case-ax16"></a>
<a id="case-cg08"></a>
<a id="record-p07"></a>
<a id="record-p08"></a>

### UI-04 — Add useful checklist and fault-reference navigation

Pilot references match the aircraft actually simulated and distinguish sensed live values from manually completed procedure items.

- Replace the single cold-start texture with normal start/taxi/takeoff/recovery/shutdown reference pages and source-bound abnormal references for modeled failures.
- Associate a stable fault id with a reference page and return path; retain all active fault identities even if one urgent message has attention.
- Show achieved weight, trim, fuel, supply and configuration values only where trustworthy. Do not import Hornet trim values or claim automatic completion of unsensed items.
- Mark estimated/simulated procedures and unavailable information in the reference content. Keep mission debug telemetry out of operational reference flows.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/MFD_COMMON/checklist_page.lua`
- `Cockpit/Scripts/Systems/MFD_Controls.lua`
- `Cockpit/Scripts/Systems/UFC_Controller.lua`
- `Cockpit/Scripts/Systems/Pilot_Warnings.lua`

**Depends on:** [ARC-01](#pkg-arc-01), [ARC-02](#pkg-arc-02), [ALR-01](#pkg-alr-01).

- Integration: VEH-04/07/09/11/12/14: procedures reflect actual physical systems and the selected modern oxygen fit.

**Audit findings:** [AX16](../audit/F22-Fidelity-Audit.html#auth-ax16), [CG08](../audit/F22-Fidelity-Audit.html#auth-cg08).

**Supporting records:** P07, P08.

**References:**

- [Ronald W. Brower (USAF), Lockheed F-22 Raptor, The Avionics Handbook](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf)
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf)
- [Chuck’s DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf)
- [Chuck’s DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Open takeoff and landing references and a selected active fault’s related page with a clear return path. |
| Limit | Missing weight/trim/source displays unavailable and cannot mark an item complete. |
| Failure | A higher-priority event gains attention without destroying the pilot’s selected reference or active fault list. |
| Recovery | After a fault clears, recall shows the defined history status without pretending the checklist repaired hardware. |

</details>

<a id="pkg-cni-01"></a>
<a id="case-ax04"></a>
<a id="record-c01"></a>
<a id="record-c02"></a>
<a id="record-c03"></a>

### CNI-01 — Prove and connect clear-voice radio backend

Pilot selected radio, achieved tuning, receiving, transmitting and audio are connected to a qualified supported DCS voice backend.

**Current issue ([AX04](../audit/F22-Fidelity-Audit.html#auth-ax04)):** The active cockpit lacks a modeled tuning/channel/audio workflow for the published voice function. DCS communication-menu access is present; this does not prove that host ATC, menus or external radio integrations cannot communicate.

- Perform a bounded backend feasibility spike before building more radio UI. The captured registration has no complete active voice-radio path; NativeDatalink is a different role and is not proof of voice support.
- Declare supported simulator build, radio instance count, bands/spacing/modulation, tune/readback API, receive/audio path and PTT capabilities. Use public supported interfaces first; isolate any version-sensitive adapter.
- Implement separate radio power/availability, requested/achieved frequency, selected transmit radio, receiving and PTT states. COMMS MENU opens a menu; it is never the achieved transmit signal.
- Connect explicit COM1/COM2 command bindings and confirm delivery with a controlled sender/receiver scenario. If a second receiver cannot work, show unavailable and keep the capability gap open.
- Gate backend callbacks by lifecycle epoch and physical availability; do not report successful tuning when the backend failed.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/device_init.lua`
- `Cockpit/Scripts/Systems/UFC_Controller.lua`
- `comm.lua`
- `Input/F-22A/joystick/default.lua`
- `EFM/source/NativeDatalink.cpp`

**Depends on:** [ARC-01](#pkg-arc-01), [ARC-02](#pkg-arc-02), [ARC-03](#pkg-arc-03).

**Audit findings:** [AX04](../audit/F22-Fidelity-Audit.html#auth-ax04).

**Supporting records:** C01, C02, C03.

**References:**

- [Ronald W. Brower (USAF), Lockheed F-22 Raptor, The Avionics Handbook](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf)
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf)
- [Chuck’s DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf)
- [Chuck’s DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Tune a compatible sender, receive intelligible audio, select the intended transmitter and verify the counterpart receives only during deliberate PTT. |
| Limit | Reject unsupported bands/spacing and prove radio-menu opening alone does not key the transmitter. |
| Failure | Remove power or backend support; indications become unavailable and PTT releases. |
| Recovery | Restore, retune if the chosen memory policy requires it, and deliberately transmit without old queued PTT. |

</details>

<a id="pkg-cni-02"></a>
<a id="case-ax06"></a>
<a id="case-ax07"></a>
<a id="case-ax08"></a>
<a id="record-c04"></a>
<a id="record-x20"></a>

### CNI-02 — Complete independent radio audio, preset and guard workflows

Inspect, edit, confirm and tune are separate; audio/guard selection is truthful for each supported receiver.

- Implement selected radio, inspected preset, edited preset and tuned channel as separate states. Adopt20 presets as an explicit interim simulation choice if backend supports it, not a documented F-22 count.
- Use independently selected receiver volume/squelch and transmit source; browsing a preset does not retune until deliberate confirmation.
- Implement main/guard monitoring only to the extent the backend actually receives both. Monitoring guard must not silently replace the main working frequency.
- Document mode-dependent AM/FM/band and guard availability from the declared adapter capability. Keep unavailable controls disabled with an understandable reason.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/UFC_Controller.lua`
- `Cockpit/Scripts/Systems/ICP_System.lua`
- `comm.lua`

**Depends on:** [CNI-01](#pkg-cni-01), [UI-02](#pkg-ui-02).

**Audit findings:** [AX06](../audit/F22-Fidelity-Audit.html#auth-ax06), [AX07](../audit/F22-Fidelity-Audit.html#auth-ax07), [AX08](../audit/F22-Fidelity-Audit.html#auth-ax08).

**Supporting records:** C04, X20.

**References:**

- [Ronald W. Brower (USAF), Lockheed F-22 Raptor, The Avionics Handbook](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf)
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf)
- [Chuck’s DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf)
- [Chuck’s DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Inspect presetB while tunedA, confirmB, mute receiver1 while receiver2 remains audible, and monitor guard without losing the working channel. |
| Limit | Empty/unsupported preset or modulation cannot replace a valid achieved setting. |
| Failure | Delayed tune acknowledgement retains the truthful old tuned value while the new request is pending. |
| Recovery | Cancel/retry and restore one receiver without changing the surviving receiver or replaying transmit intent. |

</details>

<a id="pkg-cni-03"></a>
<a id="case-ax03"></a>
<a id="case-ax05"></a>

### CNI-03 — Model graceful emergency CNI availability and logical compatibility

Supported powered resource failures degrade lower-priority functions while retaining a declared emergency voice/navigation/identification set where feasible.

- Consume VEH-04 physical supply availability and VEH-11 cooling health; own only CNI resource allocation/recovery. Electrical_Computer.lua remains a temporary compatibility adapter, never a second SOC/voltage/generator/thermal integrator.
- Map selected essential/emergency navigation consumer feeds through the supported native bus bridge. NativeNavigation.cpp263,267–270 currently connects ILS DC/AC then drives both native generator enables from MAIN_POWER; preserve actual generator state, consumer availability and bridge enable as different quantities.
- Connect a small explicit resource/consumer availability table to physical feeds and cooling. Model declared spare capacity and function priority rather than every historical SEM-E component.
- Keep UHF voice, TACAN, ILS and identification return-to-base roles eligible for recovery on surviving powered resources; never create electrical power through software reconfiguration.
- Separate logical clear/secure/net/time/key-available compatibility from actual waveform or cryptographic implementation. Label the game abstraction and backend limits.
- Do not advertise Hornet CPHR/TOD N/I pages as implemented reference behavior or reproduce sensitive real military keying/hopping procedures.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/Electrical_Computer.lua`
- `Cockpit/Scripts/Systems/Navigation_Power.lua`
- `EFM/source/NativeNavigation.cpp`
- `Cockpit/Scripts/Systems/UFC_Controller.lua`

**Depends on:** [ARC-01](#pkg-arc-01), [ARC-02](#pkg-arc-02), [CNI-01](#pkg-cni-01), [VEH-04](#pkg-veh-04), [VEH-11](#pkg-veh-11).

**Audit findings:** [AX03](../audit/F22-Fidelity-Audit.html#auth-ax03), [AX05](../audit/F22-Fidelity-Audit.html#auth-ax05).

**References:**

- [Ronald W. Brower (USAF), Lockheed F-22 Raptor, The Avionics Handbook](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf)
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf)
- [Chuck’s DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf)
- [Chuck’s DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Healthy resources support the declared functions; compatible logical voice settings work through supported backend. |
| Limit | Exhaust spare capacity and explicitly drop lower-priority capabilities; show incompatibility when a required logical prerequisite is missing. |
| Failure | Lose one declared resource with a surviving powered substitute; recover only supported emergency functions. Complete power loss remains complete loss. |
| Recovery | Restore resource/compatibility deliberately without replaying a prior PTT or hiding degraded status before recovery completes. |

</details>

<a id="pkg-alr-01"></a>
<a id="case-cg02"></a>
<a id="case-cg03"></a>
<a id="case-cg04"></a>
<a id="case-cg09"></a>
<a id="case-cg10"></a>
<a id="record-p13"></a>

### ALR-01 — Own fault identity, occurrence and master attention separately

Acknowledgement affects attention, not the underlying condition; new fault occurrences remain identifiable while older conditions persist.

**Current issue ([CG04](../audit/F22-Fidelity-Audit.html#auth-cg04)):** Fault identity and occurrence are lost before acknowledgement logic. This is more specific than a generic caution feature inventory: the interface cannot distinguish a fresh cause from the previously acknowledged cause.

- Replace aggregate-only caution acknowledgement with condition id, active/inactive, occurrence sequence, priority, onset, acknowledgement and recall state.
- Give master attention one owner and leave individual fault indications active until their physical cause clears. Avoid competing draw-argument and forced-boolean owners.
- Maintain an active list/recall/hidden-count contract even when terrain or another event wins the single forward message. Deduplicate repeat messages without losing distinct new causes.
- Separate equipment validity from terrain/navigation validity. Define supported ground/phase inhibitions per alert family; actual F-22 inhibit matrix remains unknown.
- Carry physical supply isolation into dependent loss-of-function alerts even if the original overtemperature clears. Integrate with vehicle-owned bleed/oxygen/cooling states.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/Pilot_Warnings.lua`
- `Cockpit/Scripts/Systems/Pilot_Warning_System.lua`
- `Cockpit/Scripts/Systems/Avionics.lua`
- `Cockpit/Scripts/UFD_LEFT/base_page.lua`

**Depends on:** [ARC-02](#pkg-arc-02), [ARC-03](#pkg-arc-03), [VEH-01](#pkg-veh-01).

- Integration: VEH-04/05/06/11/12/14: provider-owned condition identity, validity, isolation and recovery; framework can be implemented earlier.

**Audit findings:** [CG02](../audit/F22-Fidelity-Audit.html#auth-cg02), [CG03](../audit/F22-Fidelity-Audit.html#auth-cg03), [CG04](../audit/F22-Fidelity-Audit.html#auth-cg04), [CG09](../audit/F22-Fidelity-Audit.html#auth-cg09), [CG10](../audit/F22-Fidelity-Audit.html#auth-cg10).

**Supporting records:** P13.

**References:**

- [Ronald W. Brower (USAF), Lockheed F-22 Raptor, The Avionics Handbook](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf)
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf)
- [Chuck’s DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf)
- [Chuck’s DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Acknowledge generator faultA; its individual condition remains. Add hydraulic faultB whileA persists and request new attention according to the adopted policy. |
| Limit | Invalid navigation suppresses unavailable terrain guidance without automatically hiding a valid equipment condition. |
| Failure | Several active conditions retain identities when one urgent event owns attention; missing producer validity is shown explicitly. |
| Recovery | Clear each physical cause independently; a recurrence receives a new occurrence rather than inheriting old acknowledgement. |

</details>

<a id="pkg-alr-02"></a>
<a id="case-cg05"></a>
<a id="case-cg06"></a>

### ALR-02 — Qualify voice arbitration, priority and retained mute policy

Attention priority, actual playback, muting and audio-test status are separate, bounded states.

- Specify a provisional mod latency budget for urgent warnings across an occupied voice slot; implement preemption or bounded completion based on measured clip lengths and adopted policy, without claiming recovered F-22 timing.
- Retain confirmed-playback accounting and bounded leases. Mark speech delivered only when actual playback is confirmed; prevent failed/stale audio sources from blocking all later alerts.
- Make the IR seeker audio consumer honor expiring MWS/pilot-audio authority rather than raw priority alone. Normalize native boolean and numeric0/1 is_playing returns in IR_Audio consistently with Warning_Audio_Gate; qualify actual host return forms and audible recovery in a controlled trial.
- Preserve the deliberate global pilot-voice inhibit option: Viper documents all-voice mute. Consider a retained forward-field mute reminder as an optional usability policy, not a mandatory real F-22 feature.
- Define arbitration with RWR/MWS tones, radio/intercom and test speech. Real urgent conditions cancel tests; do not queue obsolete terrain commands after the threat changes.
- Calibrate volume/mute independently of HUD text and fault state. Keep voice-test naming scoped to recordings, distinct from lamp/equipment BIT.

**Keep:** Confirmed actual playback; Finite audio lease; Live event cancels voice test.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/Pilot_Warning_System.lua`
- `Cockpit/Scripts/Systems/Warning_Audio_Gate.lua`
- `Cockpit/Scripts/Systems/RWR_System.lua`
- `Cockpit/Scripts/Systems/MWS_System.lua`
- `Cockpit/Scripts/Systems/Weapon_System.lua`
- `Cockpit/Scripts/Systems/IR_Audio.lua`
- `Cockpit/Scripts/Systems/UFC_Controller.lua`

**Depends on:** [ALR-01](#pkg-alr-01), [ARC-03](#pkg-arc-03).

- Integration: VEH-04: chosen alert/audio consumer feed. CNI-01/02: radio/intercom arbitration. SEN-07/08/10: warning, CM and seeker tone consumers.

**Audit findings:** [CG05](../audit/F22-Fidelity-Audit.html#auth-cg05), [CG06](../audit/F22-Fidelity-Audit.html#auth-cg06).

**References:**

- [Ronald W. Brower (USAF), Lockheed F-22 Raptor, The Avionics Handbook](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf)
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf)
- [Chuck’s DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf)
- [Chuck’s DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | An urgent active event obtains its declared audio/visual response while ordinary speech or test occupies the slot. |
| Limit | All-voice inhibit behaves consistently; audio display reports retained state and zero volume does not erase active alerts. |
| Failure | Missing clip, failed host status or an endlessly true playing flag cannot create a permanent mute. |
| Recovery | Restore audio and announce only still-relevant events under the repetition policy; no replay of expired commands. |

</details>

<a id="pkg-alr-03"></a>
<a id="case-cg01"></a>
<a id="case-cg07"></a>
<a id="record-c07"></a>

### ALR-03 — Add source-bound limits, BIT distinctions and fault history

Modeled limit attention and diagnostic functions are explicit about what is sensed, tested and still uncertain.

- Create a profile/limit table for approaching CAS/Mach/configuration exceedance cues using sourced limits or labeled estimates; keep cue threshold, dynamic flight limit, damage and aircraft registration limits distinct.
- Expose separate voice-playback test, annunciator/display test, sensor/owner BIT result and fault history. A successful clip sequence cannot certify equipment sensing.
- Only add test injections through an explicit diagnostic interface; never mutate real physical failure state merely to draw a test lamp.
- Tie supported failure references to UI-04. Preserve general design claims as such until public F-22 alert behavior establishes a specific target.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/Pilot_Warnings.lua`
- `Cockpit/Scripts/Systems/Pilot_Warning_System.lua`
- `Cockpit/Scripts/Systems/HUD_Flight_Data.lua`
- `Cockpit/Scripts/Systems/UFC_Controller.lua`

**Depends on:** [ARC-01](#pkg-arc-01), [ARC-02](#pkg-arc-02), [ALR-01](#pkg-alr-01), [ALR-02](#pkg-alr-02).

- Integration: VEH-02/07/09: measured air-data health and achieved FCS/gear configuration before configuration-bound limit-cue completion.

**Audit findings:** [CG01](../audit/F22-Fidelity-Audit.html#auth-cg01), [CG07](../audit/F22-Fidelity-Audit.html#auth-cg07).

**Supporting records:** C07.

**References:**

- [Ronald W. Brower (USAF), Lockheed F-22 Raptor, The Avionics Handbook](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf)
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf)
- [Chuck’s DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf)
- [Chuck’s DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | A controlled approach to a selected limit produces the declared cue; independent BIT functions report their actual tested scope. |
| Limit | Invalid air data cannot manufacture a precise overspeed result; boundary hysteresis avoids chatter. |
| Failure | Inject a supported failure, observe sensing/attention/history separately, and verify the playback test cannot mask it. |
| Recovery | Clear the cause and inspect historical versus active state; a new occurrence is separately recorded. |

</details>

<a id="pkg-aux-01"></a>
<a id="case-ax18"></a>
<a id="record-p29"></a>

### AUX-01 — Connect boom-receptacle refueling states and host fuel transfer

Requested door, achieved readiness, contact, transfer and disconnect are independently traced through owned and host state.

**Current issue ([AX18](../audit/F22-Fidelity-Audit.html#auth-ax18)):** Own request, external argument 22 and a separate cockpit lamp exist, but the argument meanings and host contact/disconnect mapping are not established. The source trace cannot certify a separate indication sequence, and it does not establish that native fuel transfer is absent.

- Build an argument/EDM/host mapping for request, achieved door, lamp, contact and transfer. Existing external22 and cockpit0 have different consumers; verify their meanings before renaming them.
- Adopt a boom-receptacle analogue for pilot-ready/contact/disconnect workflow and connect only supported host events. Do not substitute Hornet probe hardware.
- Use VEH-03 as the sole fuel/tank/mass owner, VEH-04 for consumer supply, and VEH-07 for the selected achieved refueling configuration/control-law contract. Add a VEH-06 actuator interface only if the source-limited route selected requires it; do not infer production mode entry from door-request alone.
- Tie actual fuel increase to EFM internal/external mass and feed/transfer policy. A door or READY lamp alone cannot prove contact, and unmapped display arguments cannot prove host transfer absent.
- Specify disconnect input role and readiness after separation; preserve independent door actuation/physical supply constraints.

**Keep:** Existing incremental-kg host refuel callback, internal-then-external fill and queued mass-change accounting in RAPTOR.cpp1583–1619; qualify contact/door gating before adding a duplicate host interlock.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/Electrical_System.lua`
- `Cockpit/Scripts/Systems/Avionics.lua`
- `EFM/source/RAPTOR.cpp`
- `F-22A.lua`

**Depends on:** [ARC-02](#pkg-arc-02), [ARC-03](#pkg-arc-03), [VEH-03](#pkg-veh-03), [VEH-04](#pkg-veh-04).

- Integration: VEH-07: achieved refueling configuration/control law. VEH-06 is conditional on the selected actuator supply route.

**Audit findings:** [AX18](../audit/F22-Fidelity-Audit.html#auth-ax18).

**Supporting records:** P29.

**References:**

- [Ronald W. Brower (USAF), Lockheed F-22 Raptor, The Avionics Handbook](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf)
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf)
- [Chuck’s DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf)
- [Chuck’s DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Open receptacle, obtain host contact, record actual fuel/mass increase and deliberately disconnect with coherent indications. |
| Limit | Open door without contact; READY does not imply transfer. Check full-fuel saturation and selected tank configuration. |
| Failure | Lose contact or required supply; transfer/contact indication changes independently of requested door. |
| Recovery | Reacquire contact and reconcile actual mass without double-counting a host fuel callback. |

</details>

<a id="pkg-aux-02"></a>
<a id="case-ax19"></a>
<a id="record-p30"></a>

### AUX-02 — Preserve continuous lighting commands through actual emitters

Continuous formation/refueling light settings survive the complete command-to-draw-to-material chain where the model supports dimming.

**Current issue ([AX19](../audit/F22-Fidelity-Audit.html#auth-ax19)):** EFM formation/AAR exports are Boolean for every nonzero knob setting, so this owned state path loses relative dimming. Actual emitted luminosity and projector behavior require the EDM/host path; empty lights_data collections do not alone prove whether every modeled lamp illuminates the environment.

- Replace owned nonzero-to-Boolean reduction for formation/AAR brightness with normalized intensity exports, subject to physical supply and declared lamp modes.
- Trace EDM materials, connectors and native light-controller fields separately; determine whether each consumes enable, intensity or both before changing it.
- Verify landing/taxi/position/anti-collision versus formation/refueling controls at night and day. Add missing assets only where the supported light is actually absent.
- Keep true lamp state, pilot brightness preference and presentation gain distinct. Publish emitter/consumer ids and demand to VEH-04, which owns supply/load accounting. Calibrate visually as an estimate unless authoritative photometry exists.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/Electrical_System.lua`
- `Cockpit/Scripts/Systems/Avionics.lua`
- `EFM/source/RAPTOR.cpp`
- `F-22A.lua`

**Depends on:** [ARC-02](#pkg-arc-02), [UI-03](#pkg-ui-03), [VEH-04](#pkg-veh-04).

**Audit findings:** [AX19](../audit/F22-Fidelity-Audit.html#auth-ax19).

**Supporting records:** P30.

**References:**

- [Ronald W. Brower (USAF), Lockheed F-22 Raptor, The Avionics Handbook](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf)
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf)
- [Chuck’s DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf)
- [Chuck’s DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Sweep knob0,0.25,0.5,1 and measure monotonic owned exports plus actual visible intensity for supported emitters. |
| Limit | Enable-only host lamps remain explicitly binary; zero intensity never clears an unrelated fault. |
| Failure | Remove supply; actual emission stops while the documented preference memory is retained. |
| Recovery | Restore supply and check achieved state, without a discontinuous nonzero-to-full-bright step. |

</details>

## Optional equipment and added capabilities

A targeting pod, embedded passive-IR system and helmet display serve different roles. The following work defines complete selectable additions; their presence on a comparator aircraft does not establish F-22 installation.

<a id="pkg-sen-12"></a>
<a id="record-x01"></a>
<a id="record-x02"></a>
<a id="record-x03"></a>
<a id="record-x04"></a>
<a id="record-x05"></a>
<a id="record-x06"></a>
<a id="record-x07"></a>
<a id="record-x08"></a>
<a id="record-x09"></a>

### SEN-12 — Optional complete optical targeting, laser and video chain

If adopted, a mounted and powered optical sensor supplies usable TV/IR imagery, pointing/tracking, source-qualified designation, supported laser functions and a declared video/data path end to end.

- Select an explicitly optional LITENING-inspired initial profile. Keep Sniper as a distinct later equipment variant rather than claiming the same menus, sensors or advanced NTP features.
- First prove a supported host EO/IR image source, LOS and masking path. Build power/STBY/init/ready/fault, TV/IR polarity, FOV versus digital zoom, gain/level, gimbal/airframe limits, image age/freeze and failed-render indication.
- Implement selectable snowplow/velocity/waypoint/radar slaving, ground-stabilized area versus object point track, inertial/coast fallback, reject/return and focused-display HOTAS authority. A track attempts acquisition; it does not guarantee it.
- Transfer a deliberate optical designation through the existing sole ground-target owner with source, observation time, coordinate datum/elevation, quality and an acknowledgment. Preserve independent PP missions and show range-source validity.
- Add a separate game laser owner for safe/armed/ranging/designating/marker states, designator versus LSS code, manual/automatic or buddy-lase selection, training state and masked/no-return/interrupted behavior. Only apply supported host laser effects; the IR marker is not a designator.
- Connect supported coordinate/laser-guided stores through SMS settings and achieved mission-data state. If the host cannot supply a weapon effect, retain sensor-only capability with a visible limitation; no decorative laser-ready label.
- Plan optional video/record metadata and a separately qualified receiver/datalink path. Picture-in-picture or multi-track requires real independent sources and capacity; do not treat them as a single zoomed screenshot or import NTP features into an older pod.

**Keep:** Sole AG_Mark designation owner; Per-station captured missions; Common format focus model; Source and sequence validation.

<details>
<summary>Files, dependencies and references</summary>

- `IRST Pod.lua`
- `Cockpit/Scripts/device_init.lua`
- `Cockpit/Scripts/Systems/AG_Mark_System.lua`
- `Cockpit/Scripts/Systems/Sensor_Control.lua`
- `Cockpit/Scripts/Systems/MFD_Controls.lua`
- `Cockpit/Scripts/Systems/UFC_Controller.lua`
- `Cockpit/Scripts/Systems/Store_Capabilities.lua`
- `Cockpit/Scripts/Systems/Weapon_System.lua`
- Proposed: `Cockpit/Scripts/Systems/EOIR_System.lua`
- Proposed: `Cockpit/Scripts/Systems/EOIR_Controls.lua`
- Proposed: `Cockpit/Scripts/Systems/Laser_State.lua`
- Proposed: `Cockpit/Scripts/Systems/Target_Observation.lua`
- Proposed: `Cockpit/Scripts/Systems/EOIR_Video/init.lua`

**Depends on:** [SEN-01](#pkg-sen-01), [SEN-05](#pkg-sen-05), [SEN-06](#pkg-sen-06), [SEN-09](#pkg-sen-09), [UI-01](#pkg-ui-01), [UI-03](#pkg-ui-03).

**Supporting records:** X01, X02, X03, X04, X05, X06, X07, X08, X09.

**References:**

- [USAF LITENING Advanced Targeting fact sheet](https://www.af.mil/About-Us/Fact-Sheets/Display/Article/104571/litening-advance-targeting/) — Features/platforms
- [Northrop Grumman LITENING Advanced Targeting Pod](https://www.northropgrumman.com/what-we-do/mission-solutions/electro-optical-and-infrared-sensors-eo-ir/litening-advanced-targeting-pod) — Leading Technology
- [Air Combat Command Sniper Pod fact sheet](https://www.acc.af.mil/Portals/92/Docs/Fact%20Sheets%20-%202020%20Update/Facts%20Sheets%20-%202023%20Update/SNIPER%20POD_FEB%202023.pdf) — Mission/Features/platforms
- [Lockheed Martin Sniper ATP and Networked Targeting Pod](https://lockheedmartin.com/en-us/products/sniper.html) — ATP versus NTP
- [Chuck's DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf) — pp 249-277
- [Chuck's DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf) — pp 262-288

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Mount/power/init produces actual imagery; slew/area/point/reject transitions have visible results and acknowledged optical designation reaches the intended station mission.; A supported self/buddy laser game scenario produces the declared designator/range/LSS-LST states and corresponding host store effect. |
| Limit | Blocked/gimbal-limited/cloud-obscured scene cannot remain an unqualified fresh visual lock; image freeze is not live sensing.; FOV change and digital zoom are separate; marker, ranging, designating and laser spot search are distinct.; A mismatched/missing laser or video source does not grant a successful track, precise range or weapon readiness. |
| Failure | Pod removal, power loss, invalid image/LOS or lost point track preserves/clears the declared area/inertial state with honest age and cancels incompatible laser/weapon consent. |
| Recovery | Recovered image/supply requires the selected initialization and explicit reacquisition/reconsent; a frozen frame never becomes a new target by restoration alone. |

</details>

<a id="pkg-sen-13"></a>

### SEN-13 — Optional IRDS and passive air-track sensor roles

An optional modernized profile separates defensive missile detection from any passive aircraft-search observation and qualifies each source before fusion or radar cueing.

- Version legacy missile warning, proposed embedded IRDS and any separate podded IRST as different equipment roles; do not infer a laser rangefinder or targeting camera from the IRST21 database name.
- Characterize a supported host passive aircraft-observation source before adding player tracks. If only bearing is supported, publish bearing/age/quality rather than exact range or object truth.
- Add declared aperture/masking, detection/track/coast/loss and degraded-resource states, and qualified handoff to radar or HMD display.
- Keep missile-warning urgency and aircraft awareness distinct, with no automatic weapon-quality range or remote engagement authority.
- Record modernization evidence dates and stage. Development/testing announcements remain optional simulated equipment assumptions until applicable fielding evidence exists.

**Keep:** Independent existing optical-warning path; Common source-qualified tactical join.

<details>
<summary>Files, dependencies and references</summary>

- `IRST Sensor.lua`
- `IRST Pod.lua`
- `Cockpit/Scripts/Systems/MWS_System.lua`
- `Cockpit/Scripts/Systems/MWS_Native.lua`
- `EFM/source/NativeMWS.cpp`
- `Cockpit/Scripts/Systems/Tactical_Tracks.lua`
- Proposed: `Cockpit/Scripts/Systems/Passive_IR_System.lua`

**Depends on:** [SEN-01](#pkg-sen-01), [SEN-06](#pkg-sen-06), [SEN-07](#pkg-sen-07).

**References:**

- [Lockheed Martin F-22 Infrared Defensive System integration announcement](https://news.lockheedmartin.com/2025-01-22-Lockheed-Martin-to-Modernize-Air-Force-F-22-Raptor-with-Advanced-Infrared-Threat-Detection-Sensors) — Contract/embedded TacIRST paragraphs
- [GAO Weapon Systems Annual Assessment, F-22 SeE](https://www.gao.gov/assets/gao-25-107569.pdf) — p 74 demonstrations/integration
- [GAO Weapon Systems Testing, F-22 Sensor Enhancements](https://www.gao.gov/assets/900/890804.pdf) — Figure 7/p 23
- [Ronald W. Brower, Lockheed F-22 Raptor, The Avionics Handbook chapter 32](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf) — p 9 legacy passive missile-launch role
- [Chuck's DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf) — pp 275-277 optical/radar correlation

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Defensive IR warning and passive aircraft awareness publish distinct source roles and display semantics. |
| Limit | A bearing-only source does not receive precise range because an exact simulator object ID is available.; A generic IRST loadout label does not enable a player sensor without a live qualified source. |
| Failure | Occlusion and resource failures visibly degrade the affected role, without promoting retained data into current sensing. |
| Recovery | Restored apertures/source re-establish observations through actual acquisition, not through preserved world target truth. |

</details>

<a id="pkg-sen-14"></a>
<a id="record-x10"></a>
<a id="record-x11"></a>

### SEN-14 — Optional helmet display and head-LOS handoff

A head-tracked optional display provides aligned, blankable cues and deliberate LOS handoff without mistaking pilot gaze for a sensor measurement or automatic weapon lock.

- Choose a Scorpion-inspired optional profile, while labeling DCS JHMCS alignment/blanking/control examples as substitutes.
- Provide valid head-pose input, coordinate-frame calibration/alignment, power/brightness/NVG presentation and HUD overlap/manual blanking behavior in both desktop and VR.
- Separate look direction, selected source, cue request and acquired track. Route a deliberate helmet cue to radar, IR seeker or optional pod through each sensor owner.
- Show source/age and distinguish bearing-only warnings from conformal ranged targets. Preserve head-relative versus aircraft-relative warning references.
- Define failed pose/alignment and master-mode changes, rejecting invalid/out-of-envelope cues without fabricating acquisition.

**Keep:** Existing aircraft/world projection helpers; Seeker acquisition independence; Common focus control model.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/device_init.lua`
- `Cockpit/Scripts/Systems/Combat_Logic.lua`
- `Cockpit/Scripts/Systems/Sensor_Control.lua`
- `Cockpit/Scripts/Systems/IR_Seeker.lua`
- `Cockpit/Scripts/Systems/AG_Mark_System.lua`
- Proposed: `Cockpit/Scripts/Systems/HMD_System.lua`
- Proposed: `Cockpit/Scripts/HMD/init.lua`

**Depends on:** [SEN-01](#pkg-sen-01), [SEN-05](#pkg-sen-05), [SEN-06](#pkg-sen-06), [SEN-10](#pkg-sen-10), [UI-01](#pkg-ui-01), [UI-03](#pkg-ui-03).

**Supporting records:** X10, X11.

**References:**

- [Thales F-22 Scorpion HMD interface-development contract](https://www.thalesdsi.com/2024/09/20/thales-awarded-diu-contract-f22-hmd-interface-dev/) — Development/testing/PVI paragraphs
- [Chuck's DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf) — pp 284-285
- [Chuck's DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf) — pp 337-340,357

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Head motion moves the qualified cue correctly; a deliberate handoff requests sensor acquisition and actual feedback remains separate.; Blanking/HUD overlap and selected input authority work consistently in 2D and VR. |
| Limit | Looking at a target does not grant a lock or weapon consent; bearing-only EW cannot appear as a precise conformal target.; Alignment quality and unavailable pose prevent false-precision cueing. |
| Failure | Head tracker dropout or alignment loss flags unavailable cueing and revokes stale handoffs. |
| Recovery | Pose restoration/re-alignment restores display and control deliberately without replaying a prior release/cue press. |

</details>

<a id="pkg-sen-15"></a>
<a id="record-w03"></a>
<a id="record-w04"></a>
<a id="record-x12"></a>
<a id="record-x13"></a>
<a id="record-x14"></a>
<a id="record-x15"></a>
<a id="record-x16"></a>
<a id="record-x17"></a>

### SEN-15 — Decide unsupported weapons and independent weapon-video chains

Unsupported weapon/equipment families remain honestly absent or gain a complete explicitly optional host-supported workflow before appearing as operational capability.

- Keep experimental missile/MAKO labels versioned and unsupported A/G delivery inhibited. Decide each optional store family separately from core equipment.
- For an optional Maverick-like capability, qualify prelaunch seeker video, boresight/alignment, acquisition/handoff, actual station identity and native release. It is distinct from postlaunch video steering.
- For optional SLAM-ER/Walleye-like video control, first qualify a native weapon/data-link source, controller ownership, video age, transfer/accept/reject and link-loss behavior. No ordinary Link 16 target message substitutes for weapon video.
- Treat HARM/HTS/cooperative emitter location, anti-ship planning and decoy equipment as evidence/host-feasibility decisions. Specify only supported game modes and UI state; do not implement real RF targeting, TDOA, guidance or countermeasure recipes.
- Publish the decision for advanced multi-track/picture-in-picture and external weapon families; an advertised store requires supported mass/drag/configuration, mission preparation, feedback and recovery chains.

**Keep:** Explicit MAKO A/G unsupported state; Capability allowlist; Native actual station identity.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/Store_Capabilities.lua`
- `Cockpit/Scripts/Systems/Weapon_System.lua`
- `EFM/source/NativeAGWeapons.cpp`
- `entry.lua`

**Depends on:** [SEN-01](#pkg-sen-01), [SEN-09](#pkg-sen-09), [SEN-12](#pkg-sen-12).

**Supporting records:** W03, W04, X12, X13, X14, X15, X16, X17.

**References:**

- [USAF F-22 Raptor fact sheet](https://www.af.mil/About-Us/Fact-Sheets/Display/Article/104506/f-22-raptor/About-Us/f-22-raptor/) — Armament; baseline family context, not proof every unlisted item is impossible
- [USAF AGM-65 Maverick fact sheet](https://www.af.mil/About-Us/Fact-Sheets/Display/Article/104577/agm-65-maverick/) — Features/variant video distinction
- [NAVAIR SLAM-ER product description](https://www.navair.navy.mil/product/SLAM-ER) — Two-way link and named platforms
- [Chuck's DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf) — Maverick/HARM/HTS chapters
- [Chuck's DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf) — Maverick/Harpoon/SLAM/Walleye chapters

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Every enabled optional family has the selected equipment profile, complete control/display/native effect and documented limitations. |
| Limit | Prelaunch seeker image, pod video, own-missile diagnostic truth and postlaunch weapon downlink are not interchangeable.; Unsupported families remain explicitly unavailable rather than passing generic guided-weapon checks. |
| Failure | Lost video/link/seeker or unsupported host interface yields declared unavailable/unknown state without synthetic weapon steering. |
| Recovery | Changing station/controller/rearming starts the declared new lifecycle with no stale image, control ownership or consent. |

</details>

<a id="pkg-mis-01"></a>
<a id="case-ax15"></a>
<a id="case-ax17"></a>
<a id="record-c06"></a>
<a id="record-x18"></a>
<a id="record-x19"></a>
<a id="record-p06"></a>

### MIS-01 — Create mission-data partitions and optional cartographic presentation

Routes, planned intelligence and pilot defaults have provenance and versioning, independent of current sensor detections.

- Define a small versioned mission-data schema for route/alternate fields, planned threat zones, radio presets and declared network/ROE/color defaults; no unrestricted enemy truth feed.
- Load/validate partitions transactionally with provenance and date. Keep planned rings separate from live track lifetimes and distinguish pilot-declared identity from observed classification.
- If selected, add a cartographic layer with explicit terrain-data source, loaded region, orientation, scale and declutter. Keep route/sensor cues usable when imagery is unavailable.
- Document mission-editor, local-file and in-cockpit edit precedence and lifecycle. Do not describe an import file as a verified real F-22 DTC replica.

<details>
<summary>Files, dependencies and references</summary>

- `Cockpit/Scripts/Systems/Navigation_System.lua`
- `Cockpit/Scripts/Systems/Tactical_Situation.lua`
- `Cockpit/Scripts/Systems/Tactical_Tracks.lua`
- `Cockpit/Scripts/MFD_COMMON/formats.lua`

**Depends on:** [ARC-01](#pkg-arc-01), [ARC-02](#pkg-arc-02), [ARC-03](#pkg-arc-03), [SEN-05](#pkg-sen-05), [SEN-06](#pkg-sen-06), [SEN-09](#pkg-sen-09).

**Audit findings:** [AX15](../audit/F22-Fidelity-Audit.html#auth-ax15), [AX17](../audit/F22-Fidelity-Audit.html#auth-ax17).

**Supporting records:** C06, X18, X19, P06.

**References:**

- [Ronald W. Brower (USAF), Lockheed F-22 Raptor, The Avionics Handbook](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf)
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf)
- [Chuck’s DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf)
- [Chuck’s DCS F/A-18C Hornet Guide](https://assets.chucksguides.com/pdf/DCS%20FA-18C%20Hornet%20Guide.pdf)

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Load a known route and planned zone; overlay them consistently while actual sensor contacts age independently. |
| Limit | Corrupt/out-of-region/missing map data cannot corrupt route coordinates or retune a radio. |
| Failure | Reject a bad partition and retain the previous valid partition with an understandable result. |
| Recovery | Reload a corrected partition and reproduce the same route/labels without resurrecting old live tracks. |

</details>

<a id="pkg-nav-wp11"></a>
<a id="case-an30"></a>
<a id="record-l23"></a>
<a id="record-l24"></a>
<a id="record-l25"></a>
<a id="record-nav-30"></a>

### NAV-WP11 — Gate optional automatic recovery capability without inventing production behavior

A conditional AGCAS-equipped profile has explicit availability, arming, intervention, override and handback states. Advisory TAWS and any optional autoland remain separate capabilities.

- Record the selected equipment profile and public functional evidence. Do not claim universal F-22 fit or recovered production law. Show feature availability before issuing commands.
- Specify the game function and authority states: available, armed, inhibited, active, overridden, failed and handed back. Define pilot override and which owner wins competing commands. A numerical protection model remains a separately declared approximate game implementation.
- Keep advisory prediction and automatic control under separate owners with independent availability. Neither a renamed warning nor a stale healthy flag creates protection.
- Qualify intervention, source failure and pilot handoff against actual mod authority before enabling the profile. Do not copy a F-16 recovery trajectory as a F-22 law.
- Keep automatic ILS/flight director/autoland in a further optional branch requiring receiver integrity, capture state, authority, go-around, flare, WOW and rollout. It does not block manual core release.
- Exclude carrier ACLS from F-22 requirements; a fictional carrier project would need a separate airframe and host specification.

**Keep:** Preserve the explicitly advisory terrain module and separate manual recovery.; Keep public automatic-function evidence without filling unknown laws with a donor algorithm..

<details>
<summary>Files, dependencies and references</summary>

- `Proposed: separately owned game AGCAS state/authority module`
- `EFM/source/RAPTOR.cpp`
- `EFM/source/Autopilot.h`
- `Cockpit/Scripts/Systems/Pilot_Warning_System.lua`
- `Cockpit/Scripts/Systems/Terrain_Escape.lua`
- `Optional: separate automatic approach/flare/rollout module`
- `Profile/configuration documentation`

**Depends on:** [NAV-WP01](#pkg-nav-wp01), [NAV-WP07](#pkg-nav-wp07), [NAV-WP08](#pkg-nav-wp08), [NAV-WP09](#pkg-nav-wp09), [NAV-WP10](#pkg-nav-wp10).

**Audit findings:** [AN30](../audit/F22-Fidelity-Audit.html#auth-an30).

**Supporting records:** L23, L24, L25, NAV-30.

**References:**

- [AFMAN 11-2F-22A Volume 3, Operations Procedures](https://static.e-publishing.af.mil/production/1/af_a3/publication/afman11-2f-22av3/afman11-2f-22av3.pdf) — p8 §2.4.2.3; p18 §3.15.3
- [USAF, F-35s begin Auto GCAS test flights](https://www.acc.af.mil/News/Article/1692384/f-35s-begin-auto-gcas-test-flights/) — Complete historical F-22 statement
- [Chuck’s DCS F-16C Viper Guide](https://assets.chucksguides.com/pdf/DCS%20F-16C%20Viper%20Guide.pdf) — pp155–157
- [Eagle Dynamics DCS F/A-18C Early Access Guide](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf) — p48

</details>

<details>
<summary>Completion checks</summary>

| Condition | Required result |
| --- | --- |
| Normal | Feature OFF produces no protection commands while advisory warnings remain.; An equipped profile displays only the declared, available game function.; In a controlled simulation scenario, pilot override ends automatic authority with the stated handback. |
| Limit | Measure every declared game envelope/authority boundary; make no recovery guarantee beyond qualified conditions.; Simultaneous AP, A/T and protection requests follow one authority table rather than additive outputs. |
| Failure | Invalid terrain, position, air data or control power yields explicit failure/unavailability and handback.; Optional autoland cannot announce capture or landing without actual mode, receiver and WOW state. |
| Recovery | Fault or override follows a deliberate reset/rearm policy; normal AP cannot silently resume.; An optional landing abort preserves manual control and healthy flight/radio instruments. |

</details>

## Completion checks

<a id="pkg-veh-15"></a>

<a id="pkg-nav-wp12"></a>
<a id="record-h05"></a>
<a id="record-h07"></a>
<a id="record-h06"></a>

<a id="pkg-rel-01"></a>
<a id="record-c08"></a>
<a id="record-c10"></a>

- Use the per-system completion checks above. Compare against the selected reference behavior and declared estimates; a passing software test alone does not establish aircraft fidelity.
- Exercise normal operation, limits, loss/failure and recovery on the actual supported package. Confirm physical/native effects where the feature depends on them.
- Measure performance at declared mass, CG, payload and atmospheric conditions. Reconcile fuel, energy, pressure, heat and mass changes across the complete chain.
- Qualify cockpit controls, optical alignment, readability and sound in the actual 2D/VR installation. A preview cannot establish the installed result.
- Fly the integrated mission: hot runway start, navigation/setup transit, MiG defense, guided or explicitly selected training-store attack, then recovery at a different runway. Use separate sorties for controlled failures and boundary cases.
- For multiplayer claims, verify authority, remote effects, donor data, disconnect/reconnect and server behavior with actual participants.

Detailed mission cards and native-integration checks remain in the [backlog](BACKLOG.json).

## References and detailed findings

- [Fidelity audit](../audit/F22-Fidelity-Audit.html): documented behavior, current implementation, differences and uncertainty.
- [Complete backlog](BACKLOG.json): every task, dependency, decision and assignment.
- [Source catalogue](SOURCES.json): citations, pages, source applicability and access limits.
- [Captured source](../audit/THIRD_PASS_SOURCE.zip): the preserved source-file bytes matching the planning capture.

Code references use the 27 October 2026 planning capture. Recheck affected files before implementing an item.
