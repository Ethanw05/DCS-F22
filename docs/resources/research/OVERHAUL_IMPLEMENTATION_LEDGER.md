# F-22A overhaul implementation and integration ledger

**Latest summary:** 2026-10-25, updated during controlled validation. **Coordinator:** parent systems/UI chat. **Review owner:** integration reviewer. Dated checkpoints below are retained as evidence; the summary here describes the latest result and remaining work.

This tracks the [50-finding public-evidence audit](../../audit/README.md#retired-report-a25) during the newly authorized implementation pass. The user permits reasonable estimates and modest F-22A modernization. The historical audit is preserved; this ledger does not turn a source edit into flight qualification.

## Latest validation summary

| Area | Verified result | Remaining work or scope limit |
| --- | --- | --- |
| Source and compiled checks | Last complete source checkpoint: 93/93 scripts. Last compiled Debug checkpoint: 15/15 CTests. Earlier independent full source check: 91/91. | The new asynchronous A/G repair is in progress and is not covered by those earlier checkpoints. Use the exact source/build manifests, not Git HEAD alone. |
| Stores and menus | Native HOME, MODE, PROGRAM, ENTRY and DOORS captures preserve the original bay art and fit the LCD. Contextual mode, selection, quantity/program routing and keypad zero were exercised through real owners. | Native ENTRY exposed an unsupported underscore marker. Supported hyphens are now installed; numeric entry telemetry is verified, but its new marker still needs a matching close view. VR remains unqualified. |
| Defensive overview | Native capture renders the FCS-derived F-22 ownship and two rings. Source-specific range, age, affiliation and warning contracts pass reviewed checks. | Dense live contacts, stereo readability and performance remain separate gates. Cyan is reserved for explicit flight membership. |
| Aircraft/rack startup | Corrected checkpoint loads without the prior unresolved damage property, corrupt-damage-model, negative rack-drag or cockpit Lua errors. | This does not qualify actual damage/repair, every loadout or the vehicle performance envelope. |
| Radar startup and terrain warnings | A matching native warning run verifies hot radar ON, deliberate OFF retained, quiet tested recoverable high-bank maneuvers, severe-dive PULL UP and clearing during recovery/climb. | Broad nuisance statistics, actual valley lateral escape and full operating envelope remain open. This flight used the prior generated voice assets. |
| Ground-radar image | Flat gray output over measured land was reproduced. The independently reviewed one-element material correction removes the gray artifact in a matching native A/B. | The corrected output is black, with no terrain detail. Image generation/binding and cursor/cardinal/range geometry remain unqualified. Geometry designation stays disabled. |
| Moving-ground tracks | A fixed-capacity core scene-query path and its exports were researched. | Ground category, lifetime/thread and obstruction gates still need qualification; GMT/GMTT are not implemented. |
| A/G delivery | Native BombSight returns a valid 17-point trajectory. A controlled request trace proves the response arrives on the next native frame. | The Lua owner assumed a synchronous response and inhibits the solution. A proper pending-request/response repair is in progress. No weapon was released in these blocked attempts; accuracy remains unmeasured. |
| COM | Isolated default-off prototype has real core radio/intercom APIs. Review reproduced three PTT lease/cleanup gaps; the owner reports offline fixes. | Exact updated candidate review, native receiver audio/tuning and PTT/focus/pause qualification are pending. No working normal COM page is claimed. |
| User warning recordings | Four supplied voices and their matching duration table are staged as a coherent five-file package. | The new recordings are not yet installed or natively accepted. They must not be credited to the earlier warning flight. |

Primary artifacts and scoped handoffs are linked below. The later user flight has a separate [preserved-data review](../../audit/README.md#retired-report-a27); its seven missions are not treated as one continuous flight or as later-patch validation.

## State vocabulary and completion rule

- **Pending:** assigned and scoped, but no reviewed overhaul implementation evidence is recorded yet.
- **Implemented / review pending:** an owner reports a concrete patch; integration review and required checks remain.
- **Source verified:** merged source and relevant numerical/Lua checks were independently reviewed. Native/visual/flight gates can still be open.
- **Qualified:** the required task has matching source/DLL/build/runtime evidence, within an explicitly stated scope.
- **Partial / deferred capability:** useful improvements exist, but a required backend, data source, or validation gate remains. State the reason and actual usable behavior.

An owner report is evidence to inspect, not automatic closure. Each record began pending for this overhaul even where useful pre-existing code/tests existed. Later states are scoped by the evidence below. Final closure needs the acceptance criterion in the linked audit, appropriate validation, and exact affected files. A source-only item can close at source verification when no runtime gate is relevant; a sensor/delivery/optical performance claim cannot.

## Owners and file boundaries

| Owner | Assigned lane | Shared-file boundary / handoff |
| --- | --- | --- |
| Parent UI | Bottom stores, menus, MFD routing, ICP stores integration, review/merge | Owns `MFD_System.lua` and bottom stores artwork/page changes; integrates staged patches |
| Stores child | `AG_Stores`, `Weapon_System`, `AG_Ballistic_Computer`, `AG_Delivery`, `NativeAGWeapons`, explicit store capabilities | No direct `MFD_System`/ICP/RAPTOR edits; stage narrow NativeSidewinder changes if needed; `OVERHAUL_STORES_HANDOFF.md` |
| Vehicle child | Flight, engine, fuel, ground and physical vehicle-state improvements | Stages source in isolation; parent merges around NAV edits in RAPTOR and MFD; no new device ID planned |
| Ground chat `01a17586` | Ground radar image renderer/backend, AG radar controls/format and mover observations | Preserve designation contract; no stores/menu/weapon-owner edits; `OVERHAUL_GROUND_HANDOFF.md` |
| Tactical chat `01a16f90` | AA radar, shared tracks/fusion, RWR/MWS/EW, TSD/Attack/Defensive formats | Owns tactical format/state files; narrow shared NativeSidewinder contract; `OVERHAUL_TACTICAL_HANDOFF.md` |
| NAV chat `01a16f6e` | NAV/CNI/ALT/AP/warnings and existing runtime acceptance | Scope RAPTOR changes to altimetry/AP; give parent MFD/ICP contracts; `OVERHAUL_NAV_HANDOFF.md` |
| Integration reviewer | This ledger, new uniquely named integration tests, independent merge/contract review | No implementation or other owners' existing-test edits without coordination |

Only one task owns DCS installation and runtime controls at a time, with explicit handoffs and exact PID/mission guards. No other task may install or control that session. User flights are preserved and left untouched. Source/build/isolated work can continue independently; each runtime result is tied to its installed manifest.

## Fifty-finding work queue

| ID | Priority | Owner | Current overhaul state | Required dependency / verification gate |
| --- | --- | --- | --- | --- |

| DISP-01 | P1 | Parent UI + Tactical | Source verified | Shared tactical track contract; NAV overlay and page/focus routing; TSD/Attack/Defensive runtime comparison. |
| DISP-02 | P1 | Parent UI | Source verified | Original front-view bay assets; station inventory/selection; shared SMS handles; source-driven visual preview and in-cockpit fit. |
| DISP-03 | P1 | Parent UI | Source verified | Capability-aware modes; MFD-to-Weapon command routing; keypad cancellation and selected-mode presentation. |
| DISP-04 | P2 | Parent UI | Source verified | A stable page/focus table; distinct functional A/G MAP versus placeholder PMFD MAP; consistent MENU/BACK routes. |
| DISP-05 | P2 | Tactical + Parent UI | Implemented / review pending | Layer/filter state shared with tactical data; dense-scene selection/label check; no lost track identity. |
| RAD-01 | P2 | Tactical | Partial / deferred capability | Native observations and capability availability; declared detection approximation; actual sensor trial matrix. |
| RAD-02 | P2 | Tactical | Implemented / review pending | Actual achievable scan/revisit budget; native target responder; real launched-missile support evidence. |
| RAD-03 | P2 | Tactical | Implemented / review pending | Measured positive-friendly identification; unknown/nonreply rules; source/conflict/age tests. |
| AGR-01 | P1 | Ground | Implemented / review pending | A radar-video/image backend the user accepts; native scene/visibility bounds; resolution, gain, stabilization and image-age tests. |
| AGR-02 | P1 | Ground | Partial / deferred capability | A separate bounded moving-target observation with velocity/time/identity; persistent track and coast/reacquisition. |
| AGR-03 | P2 | Ground | Partial / deferred capability | World-stabilized image and cursor geometry; actual EXP/patch acquisition; range/coverage validity. |
| AGR-04 | P2 | Ground + Stores | Partial / deferred capability | Separate terrain-point/moving-track target kinds; compatible weapon seeker/guidance; immutable coordinate handoff. |
| FUS-01 | P1 | Tactical | Implemented / review pending | Shared observation/track schema; source/field uncertainty and age; one identity across radar/EW/NAV/weapon consumers. |
| FUS-02 | P2 | Tactical | Partial / deferred capability | Genuine bounded offboard/IR inputs or explicit unavailable capability; no use of mission truth as detections. |
| EW-01 | P2 | Tactical | Implemented / review pending | RWR bearing-only interpretation; independent optical warning; Defensive layout, priority and audio agreement. |
| EW-02 | P2 | Tactical | Implemented / review pending | Program definition/entry contract; common-device real counts and dispensing; actual consent/automatic-state semantics. |
| EW-03 | P2 | Tactical | Partial / deferred capability | Requested versus applied ECM; bounded EA approximation and supported threat/effect contract. |
| WPN-01 | P1 | Stores | Implemented / review pending | Explicit supported CLSID/capability registry; station/bay/mode/target compatibility; actual native launch behavior per store. |
| WPN-02 | P1 | Stores | Source verified | Launch acknowledgement from real native ID/sequence or observed inventory; immutable station/store transaction; timeout/dedup. |
| WPN-03 | P1 | Stores | Implemented / review pending | Per-station target and guided-weapon launch-acceptability policy; valid coordinate handoff and actual weapon outcome. |
| WPN-04 | P2 | Stores + Parent UI | Source verified | Quantity versus pulses/pairs; spacing distance versus time; only supported fuze behavior; keypad/store profile lifecycle. |
| BAL-01 | P1 | Stores | Implemented / review pending | Pose/bay/prediction/release/impact logging from normal flight; separate pointing, timing and ballistic error. |
| BAL-02 | P1 | Stores | Implemented / review pending | First trajectory/terrain intersection or conservative unavailable solution; ridge/slope/valley comparisons. |
| BAL-03 | P2 | Stores | Implemented / review pending | Store identity, launch origin/ejection assumptions and wind sampling; gun/bomb physical outcome comparisons. |
| HUD-01 | P1 | Parent UI + Runtime | Source verified | One angular/optical frame across FRL/FPM/targets/solutions; multiple head positions and VR-eye measurements. |
| HUD-02 | P2 | NAV + Parent UI | Implemented / review pending | Shared indicated-altitude/reference/validity; warning arbitration and stale-sensor rules; pressure and terrain/audio trials. |
| NAV-01 | P2 | NAV | Implemented / review pending | Explicit simplified IRS aiding/error/recovery policy; power interruption and alignment behavior; visible uncertainty. |
| NAV-02 | P1 | NAV | Implemented / review pending | Facility-driven TACAN/ILS and route tests; true/magnetic course, independent LOC/GS validity; source-aware HUD/AP. |
| NAV-03 | P2 | NAV | Partial / deferred capability | Working voice-radio backend before CNI controls; actual tuning, transmit/audio route, presets and power loss. |
| AFCS-01 | P1 | NAV + Vehicle | Implemented / review pending | Qualified flight-model/engine response; source validity/authority/override; capture/hold and disconnect across configurations. |
| FCS-01 | P1 | Vehicle + Parent integration | Source verified | Consumed, bounded trim state in actual control law; reset and AP takeover semantics; moment/response tests. |
| FCS-02 | P2 | Vehicle + Parent integration | Source verified | Automatic-only versus defined override semantics; bindings connected or removed; physical/aerodynamic/visual agreement. |
| FCS-03 | P2 | Vehicle + Parent integration | Partial / deferred capability | Pilot-command contract, common allocation/saturation and transitions; conditioned handling/PIO evaluation. |
| TVC-01 | P1 | Vehicle + Parent integration | Source verified | Return-to-neutral rate independent of command-authority schedule; boundary sweep and continuous achieved thrust. |
| TVC-02 | P2 | Vehicle + Parent integration | Source verified | Independent achieved nozzle/effector state; EFM force and drawing/synoptic contracts; asymmetry/failure tests. |
| AER-01 | P2 | Vehicle + Parent integration | Source verified | Common reference geometry convention; AI versus player scope; mass/configuration-conditioned performance. |
| AER-02 | P2 | Vehicle + Parent integration | Source verified | Declared force axes/relative flow; continuity and work/energy sweeps; artificial stabilization identified separately. |
| ENG-01 | P1 | Vehicle + Parent integration | Source verified | Modeled shaft/raw/related/percent RPM contract; existing percent consumers preserved; actual API/sound/effect checks. |
| ENG-02 | P2 | Vehicle + Parent integration | Source verified | Persistent thermal/oil/nozzle state; one producer for displays/warnings/sounds; transient/failure verification. |
| ENG-03 | P2 | Vehicle + Parent integration | Partial / deferred capability | Continuous installed-engine and fuel-flow approximation; declared valid envelope; dry/AB and ground/air tests. |
| FUEL-01 | P2 | Vehicle + Parent integration | Partial / deferred capability | Host mass authority; tank/feed/starvation/CG policy; no duplicate fuel/store mass accounting; repeated-start conservation. |
| FUEL-02 | P2 | Vehicle + Parent integration | Source verified | Capacity from installed tank; acceptance/full/removed-tank behavior; callback mass ownership and refuel conservation. |
| VEH-01 | P2 | Vehicle + Parent integration | Partial / deferred capability | Single actual supply owner; startup/fallback consistency; battery/APU/load/reversion contract to all consumers. |
| VEH-02 | P1 | Vehicle + Parent integration | Source verified | Physical hydraulic supply/demand/failure; achieved surfaces/nozzles/doors/gun rate; display consumes same state. |
| VEH-03 | P2 | Vehicle + Parent integration | Partial / deferred capability | Deliberate cabin/cooling/oxygen scope and failures; coupled avionics behavior and useful status rather than decorative values. |
| GND-01 | P1 | Vehicle + Parent integration | Source verified | Correct main-wheel mapping; independent left/right achieved brake requests; common/parking compatibility and taxi response. |
| GND-02 | P2 | Vehicle + Parent integration | Partial / deferred capability | Valid suspension/WOW fallback; actual common NWS host gating; touchdown/bounce/rollout and anti-skid behavior. |
| LIFE-01 | P1 | Integration + Runtime | Implemented / review pending | Stable native slot IDs and common-library boundary; supported-build profile, startup diagnostics and fail-closed adapters. |
| LIFE-02 | P1 | Integration + Runtime | Implemented / review pending | Merged-source/DLL hashes; numerical/build checks; separate runtime, flight, VR, rearm/repair/restart/MP evidence. |
| DOC-01 | P2 | Integration + all owners | Source verified | Dated capability ledger and exact test evidence; historical status documents clearly superseded without deleting history. |


## Contracts that must survive integration

| Contract | Current producer / boundary | Integration requirement |
| --- | --- | --- |
| Native device slots | `devices.lua`; qualified adapters directly address radar **13**, weapon **15**, ILS **24**, navigation electric **26** | Append new devices after existing slots rather than inserting into the counter sequence. A slot must continue to hold the expected native class. TACAN 23 is constructed in C++; its lack of a normal creator is intentional. |
| Device-scoped commands | `Nav_Commands.lua` uses 10840-10842 for undo/designate; EW uses the same numbers on a different device | Keep explicit target-device dispatch. Do not convert these to global dispatch while cleaning up menus. |
| Master mode / station | `Weapon_System` owns `HUD_MODE`, selected native station and weapon metadata | Page selection requests actions; it must not independently manufacture weapon or master-mode state. Stations are native zero-based indices. |
| Stores page and entry | MFD owns `CMFD_BAY_PAGE` and `F22_SMS_PROGRAM_PAGE`; Weapon owns `F22_SMS_ENTRY_*`; ICP forwards digits | Preserve one transactional scratchpad owner. NAV/page/focus/power changes cancel or hand off deliberately. New MODE/quantity/profile UI must consume backend state rather than maintain a second copy. |
| Stores numeric input | Weapon commands 10975 quantity / 10976 interval / 10977 digit / 10978 backspace / 10979 commit / 10980 cancel | Zero is a valid digit payload. Do not treat every numeric command as a positive press. New fields need agreed command/field semantics. |
| Ground designation | AG radar writes `F22_AG_DESIGNATION_*` plus sequence; AG Mark owns accepted world target and `F22_AG_TARGET_SEQUENCE` | Retain coordinate/frame/time semantics and immutable pilot-event capture. A moving track needs a new target kind; do not silently move a frozen coordinate. |
| A/G solution | Ballistic owner publishes validity, model time, station/store identity and native request/response sequence | Consumer checks all relevant identity, age and authority fields. A fresh-looking result from a previous store/target cannot authorize release. |
| Release acknowledgement | Native Sidewinder hook publishes ring `F22_SHOT_01..16_{SEQUENCE,ID,TARGET,STATION,TIME,TYPE,MODE}` and `F22_LAUNCH_SEQUENCE` | Match newer actual sequence/ID and exact station/type/mode, or verified inventory change. Advance program only on acknowledged physical release, with bounded timeout and no duplicate dispatch. |
| Tactical tracks | Radar/RWR/MWS currently have distinct observation fields and age policies | Shared fusion must retain measured versus estimated fields, source, age/uncertainty and sensor limitations. Passive-only bearing must not inherit range or allegiance from mission truth. |
| World/body/display frames | Most world payloads use north/up/east; HUD projection, radar scope and RWR native bearing conventions differ | Name axes, units, heading convention and timestamp in each new contract. Reuse tested frame conversion rather than introduce page-local sign fixes. |
| Main/battery/APU supply | Engine Lua publishes actual availability each update; C++ initializes and contains fallback paths | Vehicle refactor must preserve a single actual supply owner and reconcile initialization/NaN fallbacks. An engine-running fallback must not hide failed actual supply. |
| Physical vehicle state | EFM force, actuator/nozzle achieved position and new vehicle availability | Synoptics/animation observe the physical state. A display-derived pressure/RPM proxy must not become a second physical controller. |
| Indicated altitude | Recent NAV work supplies shared static-pressure/QNH indicated altitude to instruments, HUD/AP/warnings | Preserve that change around staged RAPTOR merges. Do not restore the removed private altimetry adapter from the earlier frozen audit. |
| Native text resources | DCS indicator states bind parameter handles; existing code avoids unsafe `%s` use in certain controllers | Declare/type dynamic handles before binding and preserve proven formatter contracts. Additions must be exercised with DCS-like element proxies and ultimately actual rendering. |

## Initial independent evidence and remaining checks

- The older frozen audit's **63/63 Python/Lua** result is a historical baseline, not this overhaul's completion result.
- New `tests/test_overhaul_device_contract.py` executed successfully against the current actual `devices.lua`/`device_init.lua`. It checks native slot/class compatibility, unique IDs and existing implementation paths. It does not execute the native DLLs.
- Six scoped contract checks passed at this checkpoint: the new device contract, standalone loader, combat controls, sensor focus, NAV entry, and A/G usability/keypad handoff. Full outputs are saved in `overhaul-integration-2026-10-25/initial-contract-checks.json` in the coordinator workspace. These are baseline contract checks; they do not close the pending new-overhaul features.
- Existing `tests/run_all.py` automatically discovers new `test_*.py` files. The full merged suite must be rerun after component integration; numeric C++ CTest and native DCS acceptance are separate gates.
- `entry.lua` creates the own cockpit/common-service graph. Do not restore the old F-15 inherited cockpit because a historical audit says it was required.
- Ground/tactical/native renderers need actual resource registration and render-order/clipping checks in addition to producer logic. Static page presence does not prove a useful image.
- The normal root tree is dirty and shared. Use narrow patches with baseline hashes, preserve other owners' changes and record source/DLL hashes for any installed test.
- No new compiled DLL, installed aircraft, flight, VR, rearm/repair/restart or multiplayer qualification is claimed by this checkpoint.

## Merge review gates

1. **Source review:** inspect the exact owner diff, evidence, parameter/command contracts and remaining limitations; reject fabricated sensor or release authority.
2. **Conflict review:** reconcile RAPTOR/NativeSidewinder/MFD/ICP overlaps by functions and actual dataflow, not by choosing one whole-file version.
3. **Logical checks:** run scoped component and meaningful cross-component checks. Fix incompatibilities rather than updating expectations to bless a broken contract.
4. **Complete merged build:** record source snapshot, native build/CTest and Python/Lua results. A new device/module must be actually registered and supported assets present.
5. **Visual/native acceptance:** the runtime owner checks stores imagery/menu focus, native sensor/release readback, failure behavior and current DCS profile.
6. **Flight qualification:** normal-flight CCIP, radar scene/mover task, missile support, navigation/AFCS, power/hydraulics and ground-handling cases are recorded within their declared scope.
7. **Ledger update:** record each finding's exact disposition, proof and remaining gates. Avoid a blanket “all fixed” claim where unavailable backends or flight evidence remain.

## Update record

| Checkpoint | Evidence / disposition |
| --- | --- |

| 2026-10-25 20:51:05 MDT | Created complete 50-item assignment/dependency queue; native device-graph regression passed; no overhaul finding closed prematurely. |


## Independent source review — 21:03 MDT

**No finding is flight-qualified by this review.** Source verification means the named source contract and Lua checks passed; the original acceptance gates above remain authoritative.

| Findings | Exact evidence and remaining gate |
| --- | --- |
| DISP-02, DISP-03 | Reviewed `MFD_CENTER/stores_program.lua`, `MFD_COMMON/lcd.lua`, `Systems/Stores_Display.lua` and actual MFD/ICP/Weapon routing. Original `bay_frame`/left/main/right door textures remain the stores foundation; current delivery mode is shown, alternatives are gated by the MODE subpage and backend compatibility. Independent `test_overhaul_stores_display.py` checks windowed class indices, blank-key consumption, unavailable MODE choices, NAV SAFE quantity/interval input including zero, decoded release edges, RTN/MENU, power/page/master-mode cancellation, unique native names/resolved parents and persistent labels on all five subpages. `test_ag_usability.py` UI section was updated for the intentional new controls and passes. Native optical fit/VR is still open. |
| WPN-02 | Reviewed real `AG_Stores.lua` request/acknowledgement and `Weapon_System.lua` native shot-ring consumption. Independent `test_overhaul_release_contract.py` passes matching station/type/mode/ID/new sequence, bounded event/observation time, rewind/timeout-before-evidence, duplicate prevention, explicit failure, edit cancellation and native-event-before-inventory reconciliation. A station with delayed inventory stays quarantined across consent changes, allowing other stations. These are Lua source contracts; actual native dispatch/shot observation and physical release still require the merged DLL and DCS trial. |
| WPN-04 | Actual model and cross-device checks exercise retained profiles, time versus distance, quantity versus pulses/pair semantics and safe entry lifecycle. `test_overhaul_stores.py` passes capability masks, spacing/pulses and entry/target cases. Fuze remains explicitly STORE DEFAULT; no programmable fuze adapter is claimed. Actual ripple footprint/interval/pair outcomes need native flight evidence. |
| WPN-01, WPN-03, BAL-01..03 | Concrete stores source is present and inspected in part: explicit capabilities, per-station coordinates, a declared estimated guided LAR, release/solution telemetry and bounded trajectory/terrain intersection. Owner tests pass, but native per-station target patch/build, full source review and normal-flight CCIP/error separation are still required. No CCIP accuracy improvement is qualified yet. |
| DISP-01, RAD-01, FUS-02, EW-03, NAV-03 | Explicit capability limits: main tactical plot remains a radar-centered format pending route/TSD composition; radar detection remains common DCS behavior without a validated APG-77 performance model; genuine offboard and aircraft IR-search producers are absent; ECM has request/readback without newly proven advanced EA effects; no own voice-radio tuning/transmit backend exists. These are partial/deferred capabilities, not renamed completed features. |
| DISP-04, DISP-05, RAD-02, RAD-03, FUS-01, EW-01, EW-02 | Concrete owner handoff in `OVERHAUL_TACTICAL_HANDOFF.md`: common tactical track provenance/age/range validity, support deadline diagnostics, Attack/Defensive formats and editable manual CM programs. Parent registration/bezel routing and independent source review remain. Owner reports focused 22/22, but its then-full run 67/69 had concurrent A/G failures; it is not full-suite acceptance. |
| HUD-02, NAV-01, NAV-02, AFCS-01 | Concrete source and bounded runtime claims in `OVERHAUL_NAV_HANDOFF.md`: measured-pressure datum, AP/ALT separation, warning priority/audio, simplified IRS lifecycle and CNI/AP contracts. Independent review has not yet reproduced all claimed evidence. Wider envelope, simultaneous-threat audio, map/facility coverage and vehicle integration remain open. |
| LIFE-01, LIFE-02, DOC-01 | New device-graph check still passes fixed native slots 13/15/24/26 and expected creator classes. All 50 findings remain tracked. A complete merged build/hash/CTest/full-Lua checkpoint and a final per-finding disposition are still required. Historical audit remains unchanged. |

Nine independent scoped scripts passed together at this checkpoint: device graph, release transaction, stores display integration, owner stores regression, combat controls, sensor focus, NAV entry, shared MFD pages and display startup. Their full output is saved as `overhaul-integration-2026-10-25/stores-ui-contract-checks.json` in the coordinator workspace. The updated A/G usability script also passed separately. No DCS process was controlled and no installed binary or flight behavior was changed by this reviewer.

Issues caught and corrected with the owning agents: native element name reread produced invalid parents under write-only proxies; class-window buttons used bezel numbers instead of published backend indices; release evidence was previously checked before clock/window validity; and a delayed count decrement could satisfy a later same-station request. All four now have focused regression coverage.

## Independent integration update — 21:19 MDT

The vehicle patch has been merged by the coordinator. This review independently reran **14/14 Debug CTest tests**, including the real compiled EFM callback fixture against its local test-only CockpitBase mock. `CMakeCache.txt` and `CTestTestfile.cmake` both identify this shared source tree. Build directory: `DlcBuilder/stores-overhaul-2026-10-25/merged-build`; output record: `DlcBuilder/overhaul-integration-2026-10-25/vehicle-review-checks.json`. This is a compiled source/model check, not a DCS flight test.

| Findings | Source disposition and remaining limits |
| --- | --- |
| FCS-01/02, TVC-01/02, ENG-01/02, FUEL-02, GND-01 | Inspected the vehicle handoff and meaningful compiled callback/numerical assertions: functional bounded trim/reset, actual flap override, independent achieved nozzles and zero-envelope return, raw/relative RPM and temperature/oil units, independent/common brakes and no nosewheel brake, actual refuel capacity/acceptance and mass delta. The merged compiled tests pass. Native flight/envelope and actual host tire/force response remain open. |
| AER-01/02 | Lua and EFM reference areas now both read 78.06 m². Inspected body-relative velocity capture and continuous drag vector opposing that flow. Existing aerodynamic coefficients/artificial stabilization and configuration performance remain unqualified. These are source corrections within the documented approximate model. |
| VEH-02, ENG-02 | `test_overhaul_vehicle_indications.py` independently verifies physical hydraulic/oil/nozzle/temperature consumption, independent failed circuits, high-RPM/zero-oil warning and retained pressure after RPM loss, sanitization and declared legacy fallback. All 12 native oil needles across the three ENG pages now read their corresponding PSI channel. Physical oil caution uses the documented 100 psi mod estimate. `test_overhaul_stores_actuators.py` independently reran successfully: zero/partial supply, achieved door clearance, open-door native gun stop on lost supply, GPU guard and SAFE transaction reconciliation. Variable native cannon rate is not implemented; gun motor availability is binary. |
| VEH-01 | Confirmed Engine_System remains the actual main/battery bus publisher after one-time C++ startup seed; C++ NaN bus fallback is0, not a healthy-engine bypass. EFM consumes the bus and publishes vehicle validity last. Battery/generator fault model is a documented estimate; production load/reversion wiring remains partial. |
| FCS-03, ENG-03, FUEL-01, VEH-03, GND-02 | Explicit partial scope in [vehicle handoff](OVERHAUL_VEHICLE_HANDOFF.md): production control law/handling, full engine deck/high-Mach table, internal feed/transfer, ECS/oxygen/cooling and real anti-skid/NWS/rollout qualification are not completed by these corrections. |
| DISP-01 | Later tactical source now includes `Tactical_Situation.lua` route/passive composition. This supersedes the earlier 21:03 note that composition had not yet been implemented. Independent producer-construction binding review found the new TSD/Defensive/CM-editor fields require initial publication before native indicators bind; `test_overhaul_tactical_binding.py` records this gate while the tactical owner repairs it. Native rendering/fusion task acceptance remains open. |
| AGR-01..04 | [Ground handoff](OVERHAUL_GROUND_HANDOFF.md) describes a staged, build-fingerprinted core radar-video adapter and1/1 candidate camera/parameter test, with no accepted GPU pixels or merged/runtime qualification yet. No new GMT, EXP/DBS or moving-target-guidance capability is closed. The rejected tile prototype is not integrated. Ground-source owner retains this lane. |
| WPN-02, LIFE-02 | Cancellation, SAFE and timeout now retain an unresolved dispatched request's station barrier. The independent release contract confirms an old delayed decrement cannot authorize a new request. This intentionally blocks a station with unknown physical outcome until actual inventory/store reconciliation. Identical-CLSID/count rearm without an observed lifecycle transition remains a required recovery test; do not claim complete rearm/repair lifecycle qualification. |

The updated NAV menu regression passes with rootPB2→NAV and the original action mappings preserved. New `test_overhaul_menu_routes.py` passes ENG selection without release-edge bounce and RWR/EW press/release ownership across page/power changes, including the actual EW latch accepting its next press. Stores native graph checks now include contextual FCS versus STN STEP and every bound SMS handle declared before indicator construction.

No new installed-aircraft, GPU radar-image, VR, multiplayer or normal-flight accuracy claim is made at this checkpoint. Source states describe the concrete reviewed corrections, not closure of every performance/capability gate in the original finding.

## Independent source checkpoint — 21:55 MDT

All **eight reviewer-owned actual-source Lua tests pass together**: device graph, release transaction, stores/keypad/graph, MFD/PMFD menus, physical indications, tactical bindings, HUD bindings and Attack contexts. Exact output: `DlcBuilder/overhaul-integration-2026-10-25/final-lua-checks.json`. The coordinated updates to existing A/G usability and NAV menu expectations also pass. New checks retain backend assertions and use real Lua owners/native-style elements, rather than replacing them with a second UI implementation.

- **DISP-01/04:** Attack now has exclusive A/A and A/G native backgrounds. A/G detail uses the existing delivery owner, and an independent display-consumer gate rejects stale/future/wrong-station solutions. Guided detail labels a coordinate/LAR estimate and hides free-fall time/range. The actual wrapper's names, parents and construction-time bindings pass. Blank legacy SMS keys are consumed; MENU, lower Stores and TSD routes reach their owners. Side-display DMS cycles cannot expose duplicate legacy bay pages. PMFD layer controls deliver their releases after page/power changes, and root Tactical no longer bounces out on release.
- **DISP-02/03:** Gun context shows the cannon/rounds and hides/consumes bomb programming keys. Gun pickle cannot create a bomb program, and selecting a carried class restores its retained bomb profile. This is independently tested through actual MFD/ICP/Weapon owners.
- **HUD-01:** Reviewed the concrete 33-versus-40 mrad forward-origin mismatch and planar/polar projection correction. Existing angular telemetry remains intact; render-only slope channels align the FPM, gun, IR and A/G cues. The actual cross-ray test passes and all 47 bound plane/slope fields are initialized before native HUD construction. Affine ladder perspective, nominal-eye software aperture and actual stereo/head/zoom optics remain unqualified. This source correction does not establish CCIP impact accuracy.
- **Tactical startup:** The previously missing TSD/Defensive/manual-CM construction fields are repaired. Both the independent format-binding check and the tactical owner's startup check now pass; the earlier binding gate is cleared at source level.
- **AGR-01/LIFE-01:** Core video candidate is now present in shared source. Independently reviewed its build fingerprints, exact-class/context/controller/target gate, preserved RTTI/vtable clone, conditional restoration, per-thread frame/epoch and locked snapshot. Invalid/stale views now produce a neutral finite camera/point; bad parameter buffers latch an output-disabling fault until reset; cached ownership is rechecked; foreign tables are rejected before typed instance getters. The new guard unit tests explicitly cover those cases. The coordinator reports 15 native tests passing; this review's recorded independent 14-test run is an earlier checkpoint, not proof of the final modified renderer. **Actual GPU pixels, camera/cardinal/cursor mapping, render-thread ABI and native lifecycle still require a matching rebuilt/runtime checkpoint.**
- **AGR-02/03/04:** Native GMT/GMTT, EXP/DBS and moving-target-guidance transport remain partial/deferred. Coordinate designation from the new video is deliberately inhibited until geometry qualification. No dot/texture change is being counted as a moving-target sensor.
- **DOC-01:** README now points to this ledger and current handoffs. The older implementation log, stores-control note and hydraulic-proxy note have dated historical/fallback banners; their content and the 50-finding historical audit remain preserved.

**Runtime hold:** the coordinator reported an unrelated user DCS/VR session. All runtime/install work is held pending the user's closure and coordinated ownership handoff; isolated source/build review may continue. This reviewer has not installed, launched, stopped, restarted or controlled DCS. No row in this ledger is newly Qualified.

## Defensive overview review — 22:35 MDT

The right Defensive page now defaults to a photo-inspired overview, with inspection/program controls behind DETAIL. See [the independent defensive review](../../audit/README.md#retired-report-a24) for exact behavior, tests, resolved findings and preview limits. Five focused source/Lua scripts pass; actual editor press/release assertions were preserved while selecting DETAIL explicitly in their fixtures. Review caught and resolved the unplottable-record count and missing red alert-material defects; circles now use batched native line geometry.

The independent full Python/Lua suite also passes **91/91 checks**, recorded in `D:/Codex-F22-Overhaul-2026-10-25/integration-review-defensive/full-suite.log`.

The independent reviewer also reran **15/15 Debug CTest tests** in `D:/Codex-F22-Overhaul-2026-10-25/ground-build`, which points to the current shared source. The earlier 14-test checkpoint is superseded at compiled-unit level. Results and source-driven preview fixtures are saved in `D:/Codex-F22-Overhaul-2026-10-25/integration-review-defensive/`. Actual GPU image geometry, native/VR screenshots and dense-scene performance remain unqualified. The coordinator's single typed damage-shell-name correction still needs startup confirmation; this review does not convert it into flight qualification.


## Coordinator frozen checkpoint and external runtime gate

The coherent shared checkpoint passes **91/91 Python/Lua scripts and15/15 Debug native CTests**, independently repeated. Current native artifacts are in D:/Codex-F22-Overhaul-2026-10-25/ground-build; the earlier C: merged-build was preserved onD: as build-checkpoint-before-ground. Exact source/DLL/model hashes: D:/Codex-F22-Overhaul-2026-10-25/source-checkpoint-91.json. Git HEAD alone omits these concurrent working-tree changes.

The right Defensive overview is now reference-based, with the latest human palette RED hostile/GREEN friendly/YELLOW unknown; CYAN requires explicit wingman membership. See OVERHAUL_UI_HANDOFF.md and OVERHAUL_DEFENSIVE_REVIEW.md. Native controls/source/graph tests pass. The complete current green preview is defensive-green-frozen-91.png under D:/Codex-F22-Overhaul-2026-10-25/previews-defensive, explicitly actual-Lua with synthetic contacts, not a DCS capture.

The user-flight data and as-found runtime snapshot were preserved before testing; conclusions and concrete missing-texture/corrupt-damage/paired-rack faults are in USER_FLIGHT_REVIEW_2026-10-25.md. The one typed EDM collision-shell name correction is in source and passes full semantic/inverse validation; native startup/actual damage and repair remain open. Four positive paired-rack drag registrations and malformed offered AIM9X pair ID are repaired and declaration-tested.

A newer unowned/user VR DCS process35024 opened before the new checkpoint could be installed. Installers refused before copying. No process was stopped or controlled. The updated near/far/mask/green-EW/EDM/rack checkpoint therefore remains queued for a closed-DCS native session. Actual GPU terrain pixels/cardinal/range/cursor, updated LCD fit/VR optics and unpaused release/impact accuracy are not claimed. Older native behavior checks are scoped in the relevant handoffs; they do not qualify later source changes.

NAV03 common COM code remains an inactive isolated prototype, documented in OVERHAUL_COMMS_HANDOFF.md. No decorative tuning/transmit readiness is enabled. GMT/GMTT, calibrated APG77 RF/EA, genuine offboard/IR aircraft inputs, complete production vehicle/engine/ECS calibration and the stated lifecycle/envelope gates remain explicit partial capabilities. This checkpoint is not a claim that all50 findings are flight-qualified.

## Closed-session validation handoff and flight-data update

The newer user session has exited, and the user explicitly confirmed that DCS is closed and validation should continue. Its final logs, both available replay files and as-found installed code/model were preserved in a separate 229-file archive before the next install. See [the later user-flight review](../../audit/README.md#retired-report-a27). It supplies useful gun, radar-startup and nuisance terrain-warning evidence; it contains no A/G release/impact correlation and did not fly the new Defensive overview or corrected external model.

Ground-video validation now owns the first coordinated runtime slot, followed by terrain warnings and then the opt-in COM prototype. The deployment includes the explicit corrected external model, five changed outer aircraft/weapon Lua files, current cockpit/input Lua, rebuilt DLL and terrain sound pair. No unowned DCS session is authorized for closure by the test launchers.

The only runtime-source delta after the frozen full 91/15 checkpoint is the user-requested FCS-derived F-22 ownship contour and its Defensive overview consumer. The actual overview contract passes after that change, and the complete actual-Lua preview was inspected. Its exact two-file delta is recorded in `D:/Codex-F22-Overhaul-2026-10-25/source-ownship-delta-2256.json`. The original full-checkpoint manifest remains unchanged. Native GPU/cockpit/damage and warning results must be recorded against their matching installed manifests before any qualification claim.

## First corrected native startup and subsequent warning candidate

The coordinated checkpoint including the two-file ownship change passed the full **91/91 source checks** before installation. Ground validation launched its owned DCS process 37112 with the dedicated validation mission after a zero-process guard. Its startup scan found no unresolved damage property, corrupt-damage-model, negative rack-drag or cockpit Lua error. The coordinator independently viewed the native `F22-Ground-Video-MAP-225717.png` capture: the right display renders two rings and the F-22 contour. This establishes the narrow startup/render behavior; actual damage, repair, VR and the lower Stores view remain separate checks.

The ground-video surface changes from black to gray, with an overlay and active callbacks, but still lacks terrain detail. **AGR-01 remains open at native image level.** Neither READY nor the gray quad qualifies the sensor; geometry designation remains inhibited. The renderer owner continues investigation with a separate read-only contract review.

After that coherent copy, the warning owner prepared four source-only Lua updates: `Terrain_Escape.lua`, `Pilot_Warnings.lua`, `Pilot_Warning_System.lua` and `Radar_System.lua`. This subsequent source checkpoint also passes **91/91 checks**. Recovery tests retain severe-dive and directional terrain warnings while rejecting the selected high-altitude maneuver nuisance cases. Radar startup requests ON through the existing power/backend gates and preserves deliberate pilot OFF. The warning change removes distant current-path-only calls, includes actual-bank recovery, and clears obsolete speech. These are model/source results, with assumptions and primary research in [the nuisance-warning review](../../audit/README.md#retired-report-a23).

The four-file release manifest is `fi/work/hornet-warning-research/release-manifest.json`. It is queued for a closed owned-session checkpoint and the subsequent warning flight slot; it was not installed into process 37112 midflight. No new native DLL is needed for this warning/radar delta.

The coordinator also inspected native `F22-Ground-EW-Stores-Down-230316.png`, which includes the entire lower Stores home page. Original bay artwork, selected weapon/current mode and inventory/control labels fit within the LCD. This clears the earlier home-page framing gap, with VR and programming subpages still separate. A terrain footprint query measured land and hills inside the 20 NM ground frame, while independent image sampling found 97.23% of a representative interior box exactly RGB 160/160/160. The gray video therefore cannot be accepted as a uniform-water scene; terrain rendering/transfer remains unresolved.
