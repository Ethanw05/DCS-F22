# Final system review for the morning test build

Continuation from `14962fe1a5dc03fd41aba972f0af88b519cc1e8c`, following the user's code → relevant evidence → change → verify sequence. No CFD. This supplements the [initial implementation matrix](OVERNIGHT_OVERHAUL.md); it is not a claim of production fidelity or exhaustive bug elimination.

## Flight controls and configuration — verified

**Read:** `FlightModel.cpp` force, engine, control-command, neutral-schedule, allocation and achieved-actuator paths; `FlightModel.h`; physics and independent scenario tests.

**Then checked:** R22, Rainey/Kohn's 1998 test-team paper, especially cruise versus power-approach/air-refueling speed-brake behavior and its 35° normal / 20° single-engine approach flap schedule. [Source](https://man.fas.org/dod-101/sys/ac/docs/f-22-emd-paper.htm). This is historical EMD evidence, not confirmation of every production block's control law.

**Changed:** Air-refueling now suppresses the wing speed-brake bias while retaining opposed rudder braking. Normal low-speed landing flap bias is 35°; single-engine cutoff/damage selection gives 20°. Neutral schedule is separated from moment allocation so its meaning can be checked independently; achieved surfaces remain rate/travel limited and may depart from neutral to control the aircraft.

**Verified before continuing:** New normal/AR/single-engine configuration cases, plus the existing full-angle energy/force, TVC, actuator, fuel, callback and independent rigid-body scenario suites pass in Release. Automatic single-engine selection and the EAS retraction blend remain disclosed approximations. No aerodynamic coefficient was inferred from model geometry.

## Engines, electrical supply and hydraulics — verified

**Read:** Entire `Engine_System.lua` and `Common/Vehicle.lua`; adapter start, health, simulation, failure and repair paths; vehicle and callback tests.

**Then checked:** R22's IVSC/APU integration discussion and the bundled SDK's `ed_fm_on_planned_failure` contract (`wHumanCustomPhysicsAPI.h`, planned-failure example). The early flight-test APU/ECS handshake problem is historical context, not a production timing specification. No public electrical schematic or hydraulic branch map was obtained.

**Changed:** A native low-hydraulic-pressure warning (draw 208) no longer creates a physical pump failure. That feedback could prevent cold-start pressure from ever building. Explicit failure causes now drive pressure decay. The SDK planned-failure callback handles `hydro`, independent engine/generator IDs and `apu`, publishes supply faults, and clears them on repair/new start/release. APU and generator choices are registered in the mission-editor table, disabled by default. Ground power permits starting without falsely asserting APU READY. APU failure drops readiness and requires a new start request after repair. Disconnected battery charge is held.

**Verified before continuing:** Vehicle tests cover low-pressure-warning recovery, actual common hydraulic loss, GPU/APU distinction, APU fault and battery isolation. Callback tests cover planned engine failure independence, hydraulic actuation hold/recovery, repair and fresh-start reset. Shared-device startup still passes. Real mission-editor scheduling and the Windows cockpit-parameter bridge need DCS testing. Pressure, load, spool timing and automatic single-engine selection remain disclosed assumptions.

## HUD and weapon-mode commands — verified

**Read:** Entire `HUD_System.lua`, `HUD/page.lua`, `Common/Stores.lua`, `Weapon_System.lua`, command definitions and HUD/stores/shared-device tests.

**Then checked:** R03's adopted layout/counter evidence and the already inspected R182/R183 picture comparison; R09 §32.3.5 for stores-management responsibilities; R186's native gunnery section for the retained host interface. Repository command 113 explicitly describes cannon on/off. Neither R186 nor an F-22 illustration establishes a complete F-22 tactical mode specification.

**Changed:** A common command-state helper treats cannon as a toggle over the previous mode. Toggling it off restores NAV or the prior combat mode instead of leaving both devices latched in GUN forever. Mode changes cancel held custom fire/release. Brightness changes ignore button release. Non-finite sensor values use finite fallbacks; invalid body velocity hides the FPM.

**Verified before continuing:** HUD and stores tests cover NAV→GUN→NAV, combat→GUN→combat, ignored key-up, held-fire cancellation and invalid air data. Original HUD construction/math and shared-device tests pass. This is an observed-command estimate, not a readback of actual native mode. DCS must establish host command delivery, mode transitions, alignment, pitch/bank/FPM signs, clipping and VR. Custom NAV lacks native route/ILS steering; the native selector remains necessary.

## Warning, air-data and display ownership — verified

**Read:** Entire `Avionics.lua`, shared sensor wrapper, MFD warning inputs and acknowledgement tests.

**Then checked:** R09 §§32.3.7/32.4 for display and failure-handling architecture. That description supplies no exact ICAW warning/acknowledgement truth table or F119 operating limits. This pass fixes internal consistency without claiming those details.

**Changed:** Left/right generator, hydraulic and oil indications retain separate rising edges for master caution. A newly lost second supply re-annunciates after the first was acknowledged; an aggregate warning no longer hides it. Shared sensor sampling rejects infinities as well as NaNs. Physical warnings remain independent of display brightness.

**Verified before continuing:** Explicit sequential left/right failures and acknowledgements, sensor corruption, zero brightness, persistent faults and shared-device tests pass. Oil remains an RPM proxy, thresholds remain assumptions, and host warning draw arguments are indications rather than a new physical failure model.

## Radar controls, EW and datalink — verified within the retained host

**Read:** Entire `PMFD_System.lua`, radar input definitions, native dispatch ownership and PMFD tests; rechecked aircraft sensor/countermeasure registration.

**Then checked:** R186 printed pp.66–70 for the actual retained simulation's radar controls/TWS, R09 §§32.3.2/32.3.4 and R36's manufacturer description. Public F-22 system roles do not supply detection/track/jammer parameter sets or a validated native host integration for a replacement APG-77.

**Changed:** Held antenna directions are tracked independently. Last pressed wins; releasing it resumes an opposite still-held key; releasing an inactive direction leaves the active one running. Power/page/WOW cancellation clears stale held inputs so power restoration cannot restart scanning.

**Verified before continuing:** Opposing held controls, release/resume, power loss/restoration, native toggle echo and no per-frame dispatch tests pass. Existing countermeasure-budget and baseline-sensor tests pass. Native F-15 radar/RWR/ECM remain; `F22_RADAR_STATE_VALID=0` explicitly marks displayed toggle estimates as unverified. No new ALR-94, fusion, IFDL, LPI or quantitative detection capability is claimed.

## Navigation, ICP, autopilot and MFDs — reviewed and regression checked

**Read:** Entire `ICP_System.lua`, `MFD_System.lua`, keypad/page/indicator contracts and current input mappings.

**Then checked:** R09 §32.3.3 and §32.3.7; R186 native NAV/gunnery/radar interface distinctions. Public CNI architecture is not a route-programming API or an autopilot law.

**Decision:** Retain the prior bounded course/altitude reference transactions, host waypoint/AP/communications wrappers, exclusive powered page state, physical fuel/pressure consumers and original page geometry. No extra navigation feature was inferred from the research. The new shared mode handling also keeps ICP's visible-HUD brightness routing consistent.

**Verified:** Keypad commit/rejection/timeout, press/release, page restoration, fuel-flow units, left/right pressure ownership, all active indicator constructions and clickable contracts pass. Reference entries do not command the native route or AP. Native AP response, HSI/ILS, radio interaction and display rendering require DCS. See the original matrix for retained texture/asset limitations.

## Stores registration and retained weapons — verified

**Read:** Pylon/loadout identifiers, all active custom declaration identities, quarantine filter and payload presets; release state machine already reviewed above.

**Then checked:** R09 SMS ownership and the existing R172 official JDAM-description evidence. Neither provides replacement missile coefficients, seeker behavior or an operational F-22 release timing table.

**Changed:** Corrected a doubled closing brace in the left external pylon's twin AIM-9 rack ID to match its already-declared loadout. Added a regression assertion that offered custom missile/rack IDs actually resolve to declared loadouts, plus duplicate/missing implemented failure-ID checks.

**Verified:** Registration test reproduced the unresolved ID before correction and passes afterward. Door clearance/cancellation, charge budget and quarantine tests pass. Invalid JDAM/MAKO A2G entries remain blocked; other custom weapons remain `[APPROX]`. Native AIM-9/AIM-120 are recommended for first compatibility tests. Native direct weapon bindings can bypass custom interlocks; native selected-station/bay mapping is still unresolved.

## Fuel, refueling, ground handling, lifecycle and packaging — reviewed

**Read:** Adapter fuel setters/refuel/mass-event paths, suspension/brake/steering exports, electrical/refuel-door state, reset/repair/draw callbacks and overlay packager.

**Then checked:** Bundled SDK fuel/mass/suspension contracts and R22 taxi/refuel/braking integration context. These do not provide measured tire/brake torque, thermal behavior, transfer plumbing or a production deceleration-command law.

**Decision and checks:** Retain conservation/accepted-amount accounting, achieved-door tanker gate, contact-based WOW, independent brakes and ground-speed steering. Existing fuel/mass, callback, independent-scenario, electrical and shared-device checks pass. Planned-failure lifecycle is corrected above. Packaging includes source/hash metadata and all matching Lua with the newly built x64 DLL. Large upstream assets and the F-15 avionics requirement remain external prerequisites.

**Simulator boundary:** No DCS executable, render/VR test, actual flight/weapon/radar/refuel transaction, rearm/respawn/repair session, sound or multiplayer test ran here. Successful unit/scenario tests are not those results. Follow [TEST_BUILD.md](TEST_BUILD.md) before accepting the build. No CFD, invented performance deck, protected-binary decompilation or third-party HUD asset copying was used.
