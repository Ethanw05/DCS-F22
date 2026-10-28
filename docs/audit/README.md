# F-22 expanded fidelity, native and cross-system audit

**Deeper audit/planning complete; no fixes implemented.** The largest prior coverage limit—native review only at system and named-critical-path level—has been replaced with a fresh per-body/declaration pass over the declared66 native files. New findings come from actual source, source-owning/header probes and independent challenges, with host/schedule applicability kept explicit.

Repository `C:\Users\Ethans Desktop 2.0\Desktop\DCS MODDING\DCS-F22`, primary checkout `main`, captured HEAD `7513f931a8bf1016a72e8eb184a9c98074786e81` with its recorded dirty/untracked files. [BASELINE.json](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/F22-Audit/Deep-Audit-2026-10-28-1351/BASELINE.json>) and [SOURCE-DRIFT.json](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/F22-Audit/Deep-Audit-2026-10-28-1351/SOURCE-DRIFT.json>) pin per-file hashes; this is a non-atomic review baseline. All 5,515 captured source files and the earlier package's257 manifest entries match the final reconciliation. Source/installed/load/build identities remain separate; sampled DLL/default-input/hook comparisons are in [FINAL-PRESERVATION.json](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/F22-Audit/Deep-Audit-2026-10-28-1351/FINAL-PRESERVATION.json>).

## What changed in the conclusions

| Finding | Demonstrated behavior | Applicability and retained protection |
| --- | --- | --- |
| D-INT-001 | Keyboard yaw smoothing survives common generation reset; identical new-generation input produces different achieved rudder after old left/right histories. | Independently reproduced with explicit old-key release and without combat update. Analogzero remains neutral. Actual DCS re-slot callback order remains unqualified. |
| D-RAD-001 | Accepted NaN/inf scan-center produces six nonfinite native camera-basis fields. | Actual header/adapter path; no renderer/GPU call or crash claimed. Validzero and disabled controls preserved. |
| D-RAD-002 | REQUEST/TIME read before the first sequence can join old enable with a new disabled packet's geometry. | Lua odd/even producer is already correct. Exact adversarial schedule reproduced; real host concurrency unqualified. Preserve bool-checked conversion. |
| D-RAD-003 | Local ground clock rewind retains native selected/pending/range history and publishes future-stamped VALID1 state. | Current Lua rejects the future report and normal rollback cancels request/designation. Provider-state defect is not proved immediate pilot/weapon exposure. |
| D-RAD-004 | Copying producer time 10 at 10.49 renews cached request to10.49, extending its .5s lease at 10.8. | A normal revalidation at 10.8 rejects it. Extension needs a later sample/query before revalidation; actual schedule/RF effects unqualified. |
| D-WPN-001 | Identity original time/known status is lost through native IFDL wire and real Lua fusion, becoming fresh geometry time. | A nonzero identity is conditional while the baseline achieved IFF provider is unavailable. Baseline unknown control produces no hostile evidence; offboard data still has no weapon authority. |
| D-WPN-002 | NaN ground-gun clock can publish native VALID1,81 points and nonfinite timestamp. | Actual numerical owner reproduced; current Lua rejects invalid time. Zero/finite clocks remain valid. |
| D-WPN-003 | A partially written Radar_Tactical packet can send new source with old position under unchanged old sequence. | Actual writer/reader with deliberate preemption; actual callback schedule unqualified. Complete committed packet is correct. |

The earlier F-FLT-001 invalid-atmosphere finding now includes **standby pressure altitude**. Independent ADC-only failure preserves healthy standby as intended, but shared invalid atmosphere can become a fresh valid0m standby result from substituted101325 Pa. Fix the shared-source provenance while retaining independent ADC backup behavior. F-INT-003 additionally needs constructor-time/partial-export readiness and rediscovery, not a blanket rewrite of already safe bool-checked readers.

## Evidence that retained behavior works within the tested scope

The real AFCS/command headers passed 200,000 deterministic transitions and992,387 authority/finite/bounds/no-replay assertions, including1,264 reset episodes. Two actual EFM power-loss/restore cases at different World clock origins disconnected guidance without automatic re-engagement. This is functional controller evidence, not real F-22 gain/handling validation or exhaustive decision coverage.

The physical-owner probe passed 20,000 fuel/first-moment operations, with maximum discrepancies3.64e-12 kg and1.73e-11 kg·m, ledger-capacity refusal/atomicity, engine/APU source-loss/recovery, bounded airdata domains and timestep cases. Thermal convergence at 600s gives roughly 8.86e-5°C difference between.002s and.02s steps under the declared fixed fixture. No complete energy closure or real cabin/oxygen/thermal capacity was authenticated.

Radar probes covered2,700 actual filter updates over27 constant-velocity/wrap/noise-scale cases with finite symmetric positive-eigen covariance;129 completed dwells consumed129 environment queries without duplicate same-clock work. Weapons numerical headers passed 54 analytic/intercept/derivative cases. These are numerical/software checks, not sensor detection-range, missile, shell or aircraft validation.

The first audit's concrete authority/validity/gear/page/radar-sector/release/CM/store/registration findings remain. Preserve one finite physical owner, independent source health, qualified achieved state, correlated effect records, source-specific identity age, saved controls, preferred HUD styling and recorded audio. Retain the declared simulator-assisted high-rate gun source 2 and the already active ground/image coordinator. No search-only dead-code deletion is justified.

## Coverage and strength of claims

| Scope | Review status | Limits |
| --- | --- | --- |
| 317 production Lua files;1,329 functions, 317 load chunks, 27 sound chunks |1,673 first-pass substantive records retained against matched hashes; selected producer/consumer chains re-inspected | No claim of a second whole-Lua pass or all-branch/DCS verification. |
| Five installed diagnostic hooks |43 first-pass records retained; final sampled hashes unchanged | Hooks were not executed; mission gates can actuate independently of missing old control files. |
| 64 owned native source files plus two runtime-wrapper headers |722 lexical records and752 syntax-tree source/declaration records freshly reviewed, including30 omitted entries | Function-definition nodes include defaulted/deleted/destructor cases; implicit generated/template instances and exact ABI not certified. |
| Parser/tool reconciliation |Pinned tree-sitter0.25.2/CPP0.23.4;13 macro/declaration errors reconciled manually | Earlier0.26.0 helper traversal failed; no production crash inferred. Parsing confers no review credit. |
| Native numerical and actual-owner probes |Specific cases and results in VERIFICATION and worker evidence | Fake ports and deliberate schedules are disclosed; no host thread/physiological/GPU/MP effect pass. |
| Historical comparison |All 223 primary and343 supporting records retained with fresh-first-pass dispositions and unchanged-source provenance | Expanded source evidence amends precise claims; it does not rerun every old qualification. |

Exact per-body purpose, callers, state ownership, units/frame/clock, contracts, failure modes, checks, hashes and limits are in [NATIVE-COVERAGE.json](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/F22-Audit/Deep-Audit-2026-10-28-1351/NATIVE-COVERAGE.json>). Source lengths/complexity are review/change candidates; they do not turn the audit into a mass formatting project.

## Calibration, source lineage and uncertainty

| Model family | Current evidence tier | What remains to establish |
| --- | --- | --- |
| Fuel topology | Aggregate rounded public anchor inherited; cell split/location/threshold/rates explicit estimates, no new original-aircraft read claimed. | Pure ledger conservation passed; actual mass callback/CG/MOI ownership, SES bottle mass and native rearm/refuel scheduling unqualified. |
| Engine force/fuel/control deck | Current source estimates; manufacturer static thrust class is not a dynamic deck or TSFC/aircraft envelope validation. | Treat dry/AB anchors, density scaling, Mach fuel multiplier and spool/AB ramp as independent uncertain knobs. Compare held-out climb/specific-excess-power/trim/fuel over same atmosphere, mass, CG, stores. |
| Aerodynamic/FCS/vector coefficients | Source shape/regularization estimates; public pitch-vector limit does not authenticate gain/slew/authority schedules. | No sustained supercruise/climb/range/closed-loop airborne/free-flight validation in this lane. |
| Battery/APU/SES/hydraulics | Model/source estimates; measured power budgets and production topology absent. | APU source loss/restoration and bounded finite state tested; actual native source performance/load/ratings and selected emergency topology unresolved. |
| Cabin/oxygen/thermal | General reduced-order physics plus selected functional evidence inherited; not real F22 cabin/ABOS/OBOGS capacities or production thermal coefficients. | Native canopy, physiological oxygen and thermal failure effects remain separate actual-host work. |
| Brakes/ground contact | Source explicitly estimated work upper envelope, not measured anti-skid heat; native wheel units/forcepoint frame undocumented in installed SDK. | Stalecontact and hot-tire repair behavior verified in pureowners. No actual braking distance, native tire mesh/fuse pressure or qualified friction/thermal calibration. |

The complete six-family matrix records current constants, exact hashes, measured numerical cases and proposed sensitivity/held-out validation conditions in [reviews/physical/lane.json](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/F22-Audit/Deep-Audit-2026-10-28-1351/reviews/physical/lane.json>). An unusual coefficient shape, reduced thermal model or normalized SES store is not automatically a confirmed aircraft defect. Oxygen reserve exhaustion has an explicit end-of-step versus prior-interval semantics question bounded by the20ms production substep; a NaN StoredEnergy helper case lies outside its current finite-constant production callers. Both are precise model/hardening decisions, not claimed physiological incidents or mass creation.

Historical F-22 development testing reported differences between simulator/wind-tunnel predictions and flight, which supports keeping numerical verification separate from aircraft validation. Only the one-page2000 abstract/configuration excerpt was read here; it supplies no production coefficients. [Peron/AFFTC abstract](<https://sfte-ec.org/sfteecold/data/Abstract/A2000-II-02.pdf>)

Public C++ concurrency and Microsoft loader guidance are tailored to packet coherence, explicit scheduling/ownership and callback retirement. They do not prove that DCS executes these callbacks concurrently or that a readable pointer remains alive. Exact access scope and date are in SOURCES/STANDARDS. [C++ Core Guidelines](<https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines>), [DLL best practices](<https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-best-practices>)

## Findings with complete remediation and verification

### D-INT-001 — Keyboard yaw smoothing survives a new flight-model generation

code defect; priorityP2; severity: minor simulator handling/lifecycle consequence; no real-aircraft safety level; confidence: high source/callback reproduction; exact DCS re-slot call order unqualified. Accountable: chat1.

Trigger: A prior same-DLL aircraft generation used keyboard rudder; a new cold/hot/air-hot start occurs without unloading the DLL, followed by a new keyboard rudder request. Independent controls confirm it persists even when the old keyboard command is explicitly released before reset, with opposite old histories.

Expected: Same fresh generation, imposed motion, elapsed time and input must not inherit old-generation keyboard smoothing.

Current: reset_fm_state resets smoothed pitch/roll but omits smoothed_yaw_discrete; the native new-start command response depends on the old filter.

Consequence: Different initial achieved rudder response after otherwise identical spawn/input; strength depends on elapsed neutral steps.

Evidence/result: reviews/lead/native_edge_probe.py; NATIVE-EDGE-PROBE.json fourth case, actual EFM callbacks and public draw state.. reproduced bounded actual-module state contamination. [RAPTOR.cpp:157](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/RAPTOR.cpp:157>), [RAPTOR.cpp:249](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/RAPTOR.cpp:249>).

Complete-chain remedy: Reset the one authoritative yaw smoother with other input filters on generation reset; inspect other persistent filters/command histories for explicit carry policy; migrate no saved command IDs.

Retain: Keyboard ramping and matching release ownership, joystick precedence and existing yaw gains.. Acceptance: normal: Fresh held command ramp remains as selected model; limit: Rapid opposing/late release and immediate new-generation request deterministic; failure: Prior held yaw cannot bias a new generation; recovery: Clear/re-engage state only with current consent; no old command replay. Packages: D-P-FLT-001, P-FLT-004, P-INT-005. Untested: In-game multi-slot lifecycle, real dynamics and rendering; no yaw gain calibration claim..

### D-RAD-001 — Video view accepts nonfinite scan-center geometry into native camera basis

code defect; priorityP2; severity: moderate native rendering/data admission consequence; no crash or actual display effect claimed; confidence: high for fault-injected source condition; normal supported DCS producers emitting malformed values unobserved. Accountable: chat3.

Trigger: View enabled/current and otherwise valid, but scan_center NaN or +/-infinity at GroundVideoView::valid -> prepare -> position. NativeGroundVideo.update copies scan-center parameter without finite admission.

Expected: Every accepted render camera position/basis/projection and point must contain finite values in the declared frame. Reject only affected frame; valid zero heading/scan-center remains valid.

Current: valid enumerates many scalar fields but omits scan_center and antenna_elevation. position evaluates cos/sin(heading+scan_center), producing nonfinite matrix while Prepared.accepted true.

Consequence: moderate native rendering/data admission consequence; no crash or actual display effect claimed

Evidence/result: probe_geometry.cpp includes unmodified GroundVideoView.h, creates explicitly current otherwise-valid View and substitutes NaN/inf scan_center one at a time.. {"case":"NaN_scan_center","accepted":1,"matrix_finite":0}
{"case":"inf_scan_center","accepted":1,"matrix_finite":0}
{"case":"NaN_antenna_elevation","accepted":1,"matrix_finite":1}
{"case":"valid_zero_geometry","accepted":1,"matrix_finite":1}
. [GroundVideoView.h:149](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/GroundVideoView.h:149>), [GroundVideoView.h:196](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/GroundVideoView.h:196>), [NativeGroundVideo.cpp:350](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeGroundVideo.cpp:350>).

Complete-chain remedy: Agree finite typed video frame admission, include scan_center/antenna_elevation and every used geometry term; validate derived matrix/projection before host copy. Reject malformed raw mode/expansion before floating-to-integer cast. Keep current captured image/epoch policy when a new frame is invalid; publish accurate unavailable reason.

Retain: Preserve current MAP/EXP/GMT/TA behavior, immutable image pose, one shared both-eye image, RF-only refresh credit, current host allocation and camera ABI. No alternate image owner or new shader.. Acceptance: NaN/+inf/-inf/wrong-type failure at actual parameter adapter and header cannot produce accepted nonfinite native matrix/projection.; Zero geometry remains accepted and finite; independent units/sign/layout reference unchanged.; Frozen/retained frame and reset/epoch/owner/fault latch transitions remain correct.. Packages: D-P-RAD-001, P-RAD-004. Untested: Fault injection at actual header; no DCS renderer call/GPU operation. NaN antenna_elevation currently becomes finite through fmin/fmax, demonstrating masked invalid input, not the same nonfinite-matrix result..

### D-RAD-002 — Native AESA packet reader reads protected fields before its first sequence

interface/architecture defect; priorityP2; severity: moderate stale control/consent/geometry admission; demonstrated reader output, no observed RF or weapon effect; confidence: high for actual-reader mixed packet under specified schedule; concurrent producer/native callback schedule in supported DCS remains unqualified. Accountable: chat3.

Trigger: AESA_Control publisher completes a new odd/even packet between reader REQUEST/TIME reads and reader first CONTROL_SEQUENCE read. Reader sees same new even sequence initially/finally but mixes old enable with new payload.

Expected: One request is a coherent complete old or new packet, or explicitly unavailable. Epoch/time/sequence acceptance must surround every participating field, including enable and observation time.

Current: Parameters.inputs order REQUEST, TIME, SEQUENCE then geometry. controls loops in that order and only rereads sequence at end. Lua writer correctly marks odd before REQUEST/TIME and commits even at end, so reader pre-sequence fields are outside its validation interval.

Consequence: moderate stale control/consent/geometry admission; demonstrated reader output, no observed RF or weapon effect

Evidence/result: probe_command.cpp includes actual NativeAesaRadar.cpp and actual EDPARAM bool conversion API. Callback commits new REQUEST0/sequence4/range2000 at first sequence read, after REQUEST1/TIME10 were copied from old sequence2/range1000. No actual host callbacks invoked.. {"stable_enabled":1,"stable_range":1000,"returned_enabled":1,"returned_range":2000,"current_bus_enabled":0,"stable_sequence":4,"request_stamp":10}
{"producer_time":10.00,"request_time":10.49,"later_time":10.8,"producer_current":0,"cached_request_current":1}
. [NativeAesaRadar.cpp:362](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeAesaRadar.cpp:362>), [NativeAesaRadar.cpp:449](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeAesaRadar.cpp:449>), [AESA_Control.lua:104](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/AESA_Control.lua:104>).

Complete-chain remedy: Read finite/even sequence first, copy every control and priority field with status, then reread same sequence/epoch before committing Request. Alternatively publish immutable joined snapshot under a characterized host contract. Preserve producer observation stamp separately from receipt and revoke disabled packets coherently.

Retain: Keep existing bool-checked parameter conversion (valid zero distinct from failure), finite controls, priority/cue IDs, finite model tasks and declared source 2 gun analogue. No permanent unchecked compatibility path.. Acceptance: Independent actual writer/reader adversarial schedules at every read/write boundary yield complete old/new request or unavailable, never mixed enable/time/geometry.; Odd, changed, stale/future/wrong-type/failed-conversion sequence withdraws; zero enable and zero valid values remain legitimate.; If supported DCS guarantees serialization, document exact callback/thread evidence and still retain correct packet admission.. Packages: D-P-RAD-001, P-RAD-004. Untested: Synthetic independent parameter port models a possible interleaving; does not establish actual DCS threading or failure frequency. Stub neighbor functions only satisfy linker and are never called..

### D-RAD-003 — Ground sampler retains future selected and pending state after local clock rewind

code defect; priorityP2; severity: moderate provider contract/recovery consequence, currently mitigated at Lua consumer; no immediate pilot/weapon stale admission demonstrated; confidence: high for retained native/provider state in specified rollback; applicability depends actual host rollback/reset guarantees. Accountable: chat3.

Trigger: World clock decreases100->10 while NativeGroundSensor epoch remains unchanged and active controls refreshed, before a new illuminated job.

Expected: A source clock discontinuity retires pending observations/selected acquisition/filter timing or explicitly withdraws the native source until a new qualified epoch/current observation. Retained old pixels may display as labeled retained imagery, not new target observation.

Current: Tracks::advance clears its own cache on rewind, but measurements.pending, selected/selected_type/acquisition_time/range_pending remain. sample no-illumination branch copies selected stamp 100 into fresh Output stamp 10; update publishes native VALID1/TIME100.

Consequence: moderate provider contract/recovery consequence, currently mitigated at Lua consumer; no immediate pilot/weapon stale admission demonstrated

Evidence/result: probe_ground_epoch.cpp includes actual NativeGroundSensor.cpp; declared precondition selected42/current100 and one real Measurements.queue report, then fake clock10 active no-grant call to actual sample and actual update. No scene/terrain/native host call occurs. Separate actual Lua native_track function extracted unmodified via debug.getupvalue tests consumer admission.. provider: {"native_published_valid":1,"native_published_time":100}
{"output_ready":1,"output_stamp":10,"retained_selected_id":42,"selected_future_stamp":100,"delayed_pre_rewind_reports":1}
; consumer: id: DEEP-RAD-consumer; actual module: Cockpit/Scripts/Systems/AG_Radar_System.lua; sha256: c19decf39d36370b1b1d3f6f55e86493770c7373f270912b54f27bc5ae5ce828; actual local: native_track extracted via debug.getupvalue from actual update, body unmodified; provider state: Probe_ground_epoch selected42 observed100 retained while current10; future report admitted: False; same report when time 100 admitted: True; limits: Actual Lua5.1 consumer function with independent numeric bus; no whole-device/DCS scheduling, no evidence native pending replay caused a live effect. Lua update also cancels request/designation on rollback; source-confirmed separate protection.. [NativeGroundSensor.cpp:260](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeGroundSensor.cpp:260>), [NativeGroundSensor.cpp:435](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeGroundSensor.cpp:435>), [GroundMovingTargets.h:51](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/GroundMovingTargets.h:51>).

Complete-chain remedy: Give ground acquisition, queues, filter, range and selected state one explicit source-clock/epoch transition; clear or retire all together on rollback/large discontinuity. Propagate reset reason/generation across sampler, native publication, image-reference policy and Lua request/selection consumers. Require fresh consent/current report rather than old delayed outcome.

Retain: Preserve Lua future-age rejection and rollback request/designation cancellation, ordinary finite silence/coast, actual delayed reports without rollback, RF-budget gates, type3 fixed-terrain disclosure and frozen image source epoch.. Acceptance: Rollback at queue/processing/acquisition/selected/ranging phases retires old pending/private histories or publishes explicit unavailable.; Actual Lua future sample remains rejected; explicit subsequent new request/current epoch restores only new target; no replay from old queue when numerical time catches up.; Normal .06/resource delayed report releases once with original stamp; monotone pause does not manufacture reset or new RF credit.. Packages: D-P-RAD-001, P-RAD-004. Untested: Injected rollback without global reset; supported DCS may always reset native epoch, which must be established before changing host adapters. Actual Lua consumer rejected stamp 100 atnow10 and normal Lua update cancels request; delayed report catch-up probe proves retained provider queue, not a live effect chain..

### D-RAD-004 — Cached AESA request renews producer age from receipt time

code defect; priorityP2; severity: moderate bounded stale command/bridge eligibility; no actual RF or weapon effect demonstrated; confidence: high for timestamp renewal and eligibility condition; EFM copier stall with continuing native driver callback is a host schedule/failure condition not observed. Accountable: chat3.

Trigger: Native parameter copy accepts producer stamp 10 atnow10.49, stores Request.stamp 10.49, then EFM copier stops while owned sensing/bridge callback continues at 10.8.

Expected: The explicit .5s control-source lease remains measured from producer observation time in the same World clock. Receipt may have a separate liveness lease but must not extend stale source authority.

Current: Parameters::command_clock checks original TIME, but controls overwrites Request.stamp with now. sample and bridge_ready later gate that receipt stamp, allowing up to nearly another .5s after the producer lease.

Consequence: moderate bounded stale command/bridge eligibility; no actual RF or weapon effect demonstrated

Evidence/result: Extended actual Parameters.controls probe constructs a stable current producer packet at 10 and copies at 10.49, then invokes actual fresh predicate at 10.8 for producer and returned Request stamps.. {"stable_enabled":1,"stable_range":1000,"returned_enabled":1,"returned_range":2000,"current_bus_enabled":0,"stable_sequence":4,"request_stamp":10}
{"producer_time":10.00,"request_time":10.49,"later_time":10.8,"producer_current":0,"cached_request_current":1}
. [NativeAesaRadar.cpp:433](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeAesaRadar.cpp:433>), [NativeAesaRadar.cpp:449](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeAesaRadar.cpp:449>), [NativeAesaRadar.cpp:582](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeAesaRadar.cpp:582>).

Complete-chain remedy: Preserve validated producer stamp in cached Request, retain separate receipt time only for explicit independent liveness, and enforce both source/context age at sensor/model/bridge admission. Preserve pause/clock policy and actual finite stamps; do not subtract unrelated clocks.

Retain: Keep current .5s bounded control/bridge contract and actual bool conversion, valid zero timestamps, epoch cancellation and model no-catchup behavior; do not erase legitimate paused state without host clock characterization.. Acceptance: Producer10/copy 10.49/later10.8 is unavailable even if request receipt was recent.; Current source and receipt within leases admit; zero timestamps and same-clock no-work calls remain valid under explicit policy.; Actual host copier/driver phase characterization documents reachability; a serialized guarantee must be evidenced rather than inferred.. Packages: D-P-RAD-001, P-RAD-004. Untested: Actual owner/predicate with synthetic clock values; no full driver scene/host API or RF/weapon effect call. A guaranteed joint callback stop could make this trigger unreachable in supported DCS. Independent challenge: a normal controls read at 10.8 disables the request; stale bridge eligibility requires sample/query before that revalidation, not continuous timely update..

### D-WPN-001 — IFDL transport converts unknown or stale identity evidence into fresh known identity

interface/architecture defect; priorityP2; severity: Misleading situational-awareness identity age/protection; offboard reports still have no weapon authority. No probability or live incident inferred.; confidence: high for tested software contract; live nonzero identity applicability remains conditional. Accountable: chat4.

Trigger: An onboard tactical contact retains friendly/hostile affiliation while identity time is unknown or older than fresh geometry. Current native achieved IFF provider is unavailable, so nonzero affiliation is a conditional input and a prerequisite before adding that backend, not a claimed ordinary live observation.

Expected: Transmit and consume identity known/status/original sample independently from kinematic observation time; fresh geometry cannot renew identity. Retained friendly protection may be displayed with truthful provenance/age.

Current: NativeDatalink::transmit ignores sender IDENTITY_KNOWN/TIME and writes only kinematic stamp-age plus affiliation. Report and receive schema have no identity sample field. Datalink_Tracks -> Tactical_Tracks -> Identification_State uses geometric observation.time as identity.time and sets time_known from geometric observation_known.

Consequence: Misleading situational-awareness identity age/protection; offboard reports still have no weapon authority. No probability or live incident inferred.

Evidence/result: Actual C++ transmit/receive/update using explicit own peer/clock/parameter ports, then actual Lua Datalink_Tracks/Tactical_Tracks/Identification_State. Additional actual Radar_Tactical publisher path supplies original identity_time10 and geometry_time200.. Sender unknown/identity_time-100 becomes receiver identity_time200,known=true. Actual publisher known identity_time10 likewise becomes200; native packet/receiver/fusion path reproduced.. [NativeDatalink.cpp:306](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeDatalink.cpp:306>), [NativeDatalink.cpp:207](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeDatalink.cpp:207>), [NativeDatalink.cpp:376](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeDatalink.cpp:376>).

Complete-chain remedy: Version the own IFDL report/schema with identity-specific known/status/original time and provenance; validate at sender and receiver, carry through Datalink_Tracks/Tactical_Tracks/Identification_State and pilot age/qualifier. Old/unsupported packets keep explicit unknown identity age rather than inventing receipt/current time. Migrate all consumers with one provider and preserve friendly-protection/conflict semantics.

Retain: Independent kinematic original/receipt time and unknown native TADIL observation handling; Source+reporter+link+epoch keys; No offboard weapon authority; PPLI membership versus interrogated identity distinction. Acceptance: normal: Known original identity time survives wire and full consumer chain unchanged, independent of fresh geometry.; limit: Old, unknown, future, nonfinite or impossible identity times never become current known time; malformed schema invalidates affected identity only.; failure: Transport version/identity field missing or source epoch changes yields explicit unavailable/unknown identity provenance without dropping independently valid geometry.; recovery: A fresh independently qualified identity event replaces retained evidence once, without receipt-time refresh or duplicate replay.. Packages: D-P-WPN-001, P-WPN-004, P-INT-005. Untested: Actual radio/MP/DCS/native ABI and routine current nonzero identity trigger not established; No authenticated RF/IFF or aircraft behavior claim.

### D-WPN-002 — Native ground-gun solver can mark a NaN-clock result valid

code defect; priorityP2; severity: Incorrect native validity contract; current Lua finite-age behavior contains pilot effect.; confidence: high for deterministic fault-injection boundary. Accountable: chat4.

Trigger: Resolved native World clock returns NaN while a finite current ground-gun request and valid geometry/shell service remain. No evidence this occurs in ordinary DCS.

Expected: Native VALID requires finite current model time and finite result timestamp; invalid clock withdraws the native solution while preserving independent data.

Current: calculate_ground checks request stamp but not now. Both age comparisons are false for NaN, so solver produces81vertices and sets F22_AG_GUN_NATIVE_VALID1 with F22_AG_GUN_RESULT_TIME NaN. Current Lua AG_Ballistic_Computer age comparison rejects this result.

Consequence: Incorrect native validity contract; current Lua finite-age behavior contains pilot effect.

Evidence/result: Actual NativeGunSight.cpp calculate_ground compiled into standalone audit executable; explicit model clockNaN, valid actual-layout pose ports and analytic finite shell trajectory.. VALID1,POINT_COUNT81,result_time_finite=false. Consumer protection remains; no valid pilot CCIP solution or actual effect claimed.. [NativeGunSight.cpp:417](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeGunSight.cpp:417>), [AG_Ballistic_Computer.lua:119](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/AG_Ballistic_Computer.lua:119>).

Complete-chain remedy: Admit finite now and finite age before shell work; publish valid0 and explicit clock reason on failure. Keep current Lua age/finite guards; only a new qualified timestamp/request can restore availability. Include all related native result groups in clock/status contract review.

Retain: Actual native muzzle/shell/wind path; Current Lua rejection of nonfinite age; Independently valid flight/kinematic sources. Acceptance: normal: Finite fresh clock/request produces finite-time native vertices and valid publication.; limit: NaN/inf/negative/future/stale boundary combinations cannot publish valid time-qualified output.; failure: Clock failure invalidates native result before costly solve; no retained point count treated as current.; recovery: Fresh admitted clock/request restores without stale generation or queued-consent replay.. Packages: P-WPN-006. Untested: Actual World clock fault/ABI/geometry/shell and simulator operation untested; Analytic shell port validates admission/publication contract only.

### D-WPN-003 — Radar-to-IFDL publication lacks an in-progress marker

code defect; priorityP2; severity: Potential incorrect donor object/position association; no offboard fire-control authority granted.; confidence: high for source protocol and counterexample; actual concurrent host trigger unqualified. Accountable: chat3.

Trigger: Native datalink transmitter runs while Lua Radar_Tactical.publish is between slot-field writes. Exact host callback/thread ordering is unqualified; this is a source-protocol counterexample, not an observed DCS race.

Expected: A receiver/sender snapshot belongs to one committed generation; producer in-progress state or serialization guarantee must exclude mixed identity/geometry.

Current: Radar_Tactical increments sequence only after64 slot updates and never marks write-in-progress. NativeDatalink compares before/after sequence equality, so unchanged old sequence can accompany mixed new source ID and old position.

Consequence: Potential incorrect donor object/position association; no offboard fire-control authority granted.

Evidence/result: Execute actual Radar_Tactical publisher, capture exact parameter state immediately after new first-slot SOURCE write; feed that snapshot into actual C++ transmitter/receiver. No modifications to either owner module.. Committed old frame seq1/source 77/N1000; mid-publish sends source 88/N1000 under seq1; final committed seq2 sends source 88/N2000. Actual simulated preemption demonstrates inadequate protocol if scheduling permits.. [Radar_Tactical.lua:33](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Radar_Tactical.lua:33>), [NativeDatalink.cpp:312](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeDatalink.cpp:312>).

Complete-chain remedy: Either establish measured enforced serialization across these exact producer/consumer callbacks or adopt one typed odd/even/invalid commit generation at write start and stable completed generation after all fields. Migrate native transmitter and all tactical readers to reject in-progress/changed generation; no duplicate track owner.

Retain: Genuine measured onboard positions only; Existing native sender before/after checks as secondary protection; Radar/donor association and weapon authority separation. Acceptance: normal: A complete source/position/velocity/identity tuple is transmitted from one committed frame.; limit: Preempt at each producer field write, sequence wrap and empty/refilled slots; sender rejects every mixed/in-progress snapshot.; failure: Torn/missing/stale frame invalidates transmission of affected tracks without invented defaults or replay.; recovery: Only a complete new committed generation is admitted after interruption/reset.. Packages: D-P-RAD-001, P-WPN-004, P-RAD-004. Untested: Whether DCS executes this interleaving; real callback thread serialization and parameter-memory guarantees; No actual radio/MP/host effect observed.

### F-INT-001 — Source, installed and loaded package identity remain distinct

host limitation; priorityP1; severity: moderate; confidence: high for identity gap; no claim installed code defective. Accountable: chat2.

Trigger: Attempt to qualify current source using latest existing DCS log or installed default controls

Expected: Qualify exact loaded current build and its actual controls.

Current: Current source and installed DLL bytes match, but latest log loaded same path before current DLL timestamp. Both default input files differ source vs installed; user saved-diff behavior not measured.

Consequence: Current integration/compatibility cannot be inferred from historical successful startup or matching DLL bytes.

Evidence/result: C:\Users\Ethans Desktop 2.0\Desktop\DCS MODDING\F22-Audit\Fresh-Audit-2026-10-28-0413\probes\capture_identity.py and PACKAGE-IDENTITY.json. Read-only facts reproduced; no current DCS launch. [entry.lua:24](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/entry.lua:24>), [default.lua:1](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Input/F-22A/joystick/default.lua:1>), [default.lua:1](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Input/F-22A/keyboard/default.lua:1>).

Complete-chain remedy: Explicit source/build/package/loaded manifest and saved-control-preserving default reconciliation.

Retain: User saved profiles/HUD/audio; current normal install path.. Acceptance: normal: Attributed source/install/load and supported input import; limit: Old/missing/mismatched DLL/assets/defaults identified; failure: Guard failure withdraws unsupported feature; recovery: Install/qualify exact supported package without stale-log attribution. Packages: P-INT-003. Untested: DCS current loaded bytes; user binding actions.

### F-INT-002 — Current CMake can overwrite source DLL output despite an external build directory

interface/architecture defect; priorityP1; severity: moderate; confidence: high. Accountable: chat2.

Trigger: Configure/build f22 target with external -B expecting all outputs outside source tree

Expected: Explicit build output policy; audit/testing must not silently replace source binary.

Current: RUNTIME_OUTPUT_DIRECTORY is hardcoded to CMAKE_SOURCE_DIR/bin independent of -B.

Consequence: Ordinary external build can overwrite production source-tree DLL; invalid provenance/test isolation.

Evidence/result: Read EFM/CMakeLists13-14; no hazardous build executed. Fresh probe used separate safe driver.. source-confirmed. [CMakeLists.txt:13](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/CMakeLists.txt:13>).

Complete-chain remedy: Make output destination explicit per build preset and isolate test fixtures/build artifacts; retain intentional install as separate step.

Retain: Actual toolchain/C++23/DCS ABI and focused install policy.. Acceptance: normal: External build artifacts remain chosen build root; limit: Debug/Release all configurations checked; failure: Missing/invalid output config fails explicitly; recovery: Reconfigure without corrupting known installed identity. Packages: P-INT-003. Untested: New output policy not implemented.

### F-INT-003 — Shared native parameter wrapper erases read failure status

interface/architecture defect; priorityP1; severity: moderate native data/lifetime boundary; confidence: high for source behavior; conditional consequence. Accountable: chat2.

Trigger: Native parameter conversion returns false, or module/export unavailable before EDPARAM construction/caller use

Expected: Keep conversion status and API readiness distinct from numeric data; valid zero is not an error default.

Current: getParamNumber initializes res0, ignores bool conversion result and returnsres. API resolver returns zero pointers for absent CockpitBase; forwarding methods do not locally guard pointers. Some callers add valid flags, but no common read-status contract.

Consequence: Failed data read can become apparently valid0; unsupported lifetime/load order can reach unchecked calls if caller lacks guard.

Evidence/result: Lead inspected full two runtime wrapper headers and getter callers; no hazardous host call executed.. Source-confirmed status erasure; supported DCS malformed read/load-order occurrence not established.. [CockpitAPI_Declare.h:31](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/include/Cockpit/CockpitAPI_Declare.h:31>), [ccParametersAPI.h:38](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/include/Cockpit/ccParametersAPI.h:38>).

Complete-chain remedy: Agree checked-status interface, migrate affected actual callers, remove unchecked obsolete use; keep host ABI in adapter and withdraw affected outputs on failure. Avoid a permanent parallel unchecked/checked compatibility path.

Retain: valid numeric zero; borrowed DCS ownership; one physical owner; current native profile guards. Acceptance: normal: Valid numeric reads including0 remain correct; limit: Wrong type/NaN/inf/expired context rejected at owning field domain; failure: Absent export/conversionfalse yields unavailable and no callback escape; recovery: Reacquire only current qualified context and reset epoch; no stale handle use. Packages: P-INT-008. Untested: Real DCS failed conversion; missing-host crash occurrence; thread/lifetime contention.

### F-FLT-001 — Invalid atmosphere becomes healthy environmental/HUD observation

interface/architecture defect; priorityP1; severity: major simulator function/feedback; confidence: high. Accountable: chat1.

Trigger: Healthy sample then nonfinite atmosphere temperature

Expected: Invalid host inputs must not be republished as healthy environmental or HUD observations. Preserve independent valid kinematics/backup oxygen.

Current: Atmosphere callback substitutes101325 Pa/288.15K and clears atmosphere_valid; environment adapter forwards substitutions without original validity; HUD_VALID always1. Probe pressure26436->101325 while environment/OBOGS/HUD remain valid1 and airdata/force withdraw0. Deepening: standby native pressure also publishes fresh0m/VALID1 from substituted101325 Pa after shared atmospheric invalidity.

Consequence: Atmospheric consumers can accept fabricated pressure and environmental consent.

Evidence/result: V-FLT-001: probe_environment.py/result reproduced. Source review; no runtime qualification. [RAPTOR.cpp:843](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/RAPTOR.cpp:843>), [VehicleIntegration.h:323](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/VehicleIntegration.h:323>), [RAPTOR.cpp:1916](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/RAPTOR.cpp:1916>).

Complete-chain remedy: Carry provenance into field-group validity. Withdraw atmospheric-derived health while retaining independently valid kinematics/backup oxygen; do not indiscriminately erase every HUD cue. Preserve ADC-independent standby on a genuinely healthy atmospheric source, but pass shared atmospheric validity to standby and reject substituted pressure as measured.

Retain: single physical owner; saved control IDs; HUD styling; recorded audio; finite resources; healthy degraded modes. Acceptance: normal: Healthy source-limited behavior retained; limit: Finite domains and bounded timestep/event sequences; failure: Withdraw only affected consent; no fabricated healthy zero; recovery: Qualified source restoration without stale action replay. Packages: P-FLT-001. Untested: DCS actual host behavior/threading; visible cockpit/physiological/mechanical effects; 2D/VR; MP.

### F-FLT-002 — Unsafe damaged gear remains green and all lamp consumers share nose parameter

code defect; priorityP1; severity: major simulator function/feedback; confidence: high. Accountable: chat1.

Trigger: Hot ground start; damage callback(8,0); battery available

Expected: Per-leg achieved lock, health and admitted command must determine pilot indication; finite SES alternate extension is separate from native arrestment.; Each registered fault affects appropriate physical/native state and pilot feedback; repair differs from resource servicing/cooling/refuel/start.

Current: Aggregate unsafe=1/downlocked=0 but N/L/R_GEAR_LIGHT all 1. Mainpanel right/left/nose lamps all bind N_GEAR_LIGHT (lead independently read).

Consequence: Contradictory and non-independent pilot gear feedback.

Evidence/result: V-FLT-002: probe_gear.py/result reproduced failure+repair; lead independent challenge. Source review; no runtime qualification. [RAPTOR.cpp:1980](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/RAPTOR.cpp:1980>), [VehicleIntegration.h:531](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/VehicleIntegration.h:531>), [mainpanel_init.lua:127](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/mainpanel_init.lua:127>).

Complete-chain remedy: Define per-leg achieved lock/damage/validity in physical owner; migrate legacy lamp producer AND mainpanel bindings. Probe host damage IDs8/15/16 versus suspension83/84/85 before changing actual leg mechanics.

Retain: single physical owner; saved control IDs; HUD styling; recorded audio; finite resources; healthy degraded modes. Acceptance: normal: Healthy source-limited behavior retained; limit: Finite domains and bounded timestep/event sequences; failure: Withdraw only affected consent; no fabricated healthy zero; recovery: Qualified source restoration without stale action replay. Packages: P-FLT-005. Untested: DCS actual host behavior/threading; visible cockpit/physiological/mechanical effects; 2D/VR; MP.

### F-FLT-003 — Canopy/refueling owned state lacks qualified production adapter

source-backed gap; priorityP1; severity: moderate capability/qualification limit; confidence: high. Accountable: chat1.

Trigger: Normal canopy/refuel operation

Expected: Qualified native canopy position/lock controls cabin sealing; absent provider remains unavailable, native escape remains host-owned.; Conserve fuel/mass/first moment through feed/transfer/burn/refuel; distinguish empty tank from absent carriage and door readiness from transfer.; Achieved source/intensity and door/contact/disconnect state must reach actual host effects with preserved controls/audio.

Current: Production search locates canopy fields in registration/consumers, no qualified writer. Electrical_System publishes AAR/native refuel dispatch while physical owner reads separate F22_REFUEL_DOOR_REQUEST/DISCONNECT_REQUEST with no production writer found.

Consequence: Cabin seal remains unavailable and owned refuel-ready/door/disconnect cannot establish full pilot->host chain.

Evidence/result: Fresh production/load-path search; actual host probe still required. Source review; no runtime qualification. [VehicleSignals.h:75](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/VehicleSignals.h:75>), [VehicleIntegration.h:345](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/VehicleIntegration.h:345>), [VehicleIntegration.h:437](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/VehicleIntegration.h:437>).

Complete-chain remedy: Chat 2 probes and owns cockpit/native adapters under chat1 physical contract. Preserve native controls, distinguish ready/contact/transfer/disconnect and withdraw unknown seal.

Retain: single physical owner; saved control IDs; HUD styling; recorded audio; finite resources; healthy degraded modes. Acceptance: normal: Healthy source-limited behavior retained; limit: Finite domains and bounded timestep/event sequences; failure: Withdraw only affected consent; no fabricated healthy zero; recovery: Qualified source restoration without stale action replay. Packages: P-FLT-009. Untested: DCS actual host behavior/threading; visible cockpit/physiological/mechanical effects; 2D/VR; MP.

### F-FLT-004 — Finite oxygen model stops at fixed SDK pressure boundary

host limitation; priorityP1; severity: moderate capability/qualification limit; confidence: high. Accountable: chat1.

Trigger: OBOGS fails and backup reserve depletes

Expected: Finite source-limited OBOGS/backup model must reach qualified native oxygen/cabin effects or explicitly declare unavailable effect.

Current: Model delivery can withdraw but ED_FM_OXYGEN_SUPPLY always returns101000 Pa, explicitly pending host qualification.

Consequence: Finite model does not prove finite native oxygen or physiological effect.

Evidence/result: Source-confirmed intentional boundary; real host response untested. Source review; no runtime qualification. [VehicleEnvironment.h:88](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/VehicleEnvironment.h:88>), [RAPTOR.cpp:1294](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/RAPTOR.cpp:1294>), [wHumanCustomPhysicsAPI.h:820](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/include/FM/wHumanCustomPhysicsAPI.h:820>).

Complete-chain remedy: First probe actual SDK effect with bounded isolated failure; then route qualified delivery or declare unsupported effect. Preserve independent backup and selected era.

Retain: single physical owner; saved control IDs; HUD styling; recorded audio; finite resources; healthy degraded modes. Acceptance: normal: Healthy source-limited behavior retained; limit: Finite domains and bounded timestep/event sequences; failure: Withdraw only affected consent; no fabricated healthy zero; recovery: Qualified source restoration without stale action replay. Packages: P-FLT-006. Untested: DCS actual host behavior/threading; visible cockpit/physiological/mechanical effects; 2D/VR; MP.

### F-FLT-005 — Airborne envelope/gravity/inertia remain unvalidated estimates

calibration uncertainty; priorityP2; severity: moderate capability/qualification limit; confidence: high. Accountable: chat1.

Trigger: Claims of sustained supercruise/climb/range/high-alpha, banked Nz or redistribution response

Expected: Matched atmosphere/mass/CG/stores/thrust/fuel establish a consistent envelope, separating calibration from held-out validation.; CAS/EAS/TAS, signed normal acceleration, CG moment arms and inertia stay explicit; qualify native gravity/inertia/ground-effect/store-drag ownership first.

Current: Estimated coefficient/thrust/fuel relationships; g=ay/9.81+1 and delta-inertia0 explicitly await host convention/ownership characterization.

Consequence: Source consistency and imposed-motion grids cannot validate full-flight response or production accuracy.

Evidence/result: Fresh source review; no flight validation. Source review; no runtime qualification. [RAPTOR.cpp:376](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/RAPTOR.cpp:376>), [RAPTOR.cpp:940](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/RAPTOR.cpp:940>), [RAPTOR.cpp:1084](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/RAPTOR.cpp:1084>).

Complete-chain remedy: Probe specific-force/gravity/inertia/ground effect/store drag before duplicate contributions; predeclare matched-condition calibration and independent validation tolerances/uncertainty.

Retain: single physical owner; saved control IDs; HUD styling; recorded audio; finite resources; healthy degraded modes. Acceptance: normal: Healthy source-limited behavior retained; limit: Finite domains and bounded timestep/event sequences; failure: Withdraw only affected consent; no fabricated healthy zero; recovery: Qualified source restoration without stale action replay. Packages: P-FLT-008. Untested: DCS actual host behavior/threading; visible cockpit/physiological/mechanical effects; 2D/VR; MP.

### F-FLT-006 — Hydraulic emergency EW generation needs profile/supply decision

source-backed gap; priorityP2; severity: moderate capability/qualification limit; confidence: medium. Accountable: chat1.

Trigger: Normal generator loss in equipment profile selecting manufacturer-described EW emergency generator

Expected: One finite physical source owner supplies admitted consumers, handles depletion/start interruption/restoration and selected equipment topology.; Four-pump/APU sources and finite reserve/demand/routing determine achieved actuators, with no second Lua integrator.

Current: Physical power supports engine/GPU/groundAPU main and battery essential; no separately identified hydraulic EW generator.

Consequence: Emergency defensive survival cannot be inferred from hydraulic pressure or generic essential bus.

Evidence/result: Eaton April2014 p2 identifies emergency EW generator components; no complete topology. Source review; no runtime qualification. [VehiclePower.h:125](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/VehiclePower.h:125>), [VehicleIntegration.h:467](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/VehicleIntegration.h:467>).

Complete-chain remedy: Resolve dated Eaton equipment applicability and energy/host path with chat4; if selected add bounded physical provider and consumer load/failure/recovery contract.

Retain: single physical owner; saved control IDs; HUD styling; recorded audio; finite resources; healthy degraded modes. Acceptance: normal: Healthy source-limited behavior retained; limit: Finite domains and bounded timestep/event sequences; failure: Withdraw only affected consent; no fabricated healthy zero; recovery: Qualified source restoration without stale action replay. Packages: P-FLT-002. Untested: DCS actual host behavior/threading; visible cockpit/physiological/mechanical effects; 2D/VR; MP.

### F-NAV-001 — HUD altitude remains valid after altitude owner stops

interface/architecture defect; priorityP1; severity: major simulation indication; confidence: High within stated source/offline boundary. Accountable: chat2.

Trigger: ALT stops while physical/HUD producer continues with retained ALT_VALID=1.

Expected: Admit finite selected data only with source clock, validity and bounded age. A stopped owner withdraws indication. Preserve explicit RDR-to-BARO policy; STBY never silently switches.

Current: HUD altitude() reads value and valid flag but never its published stamp. At10 seconds without new altitude it still publishes valid=1 and3000ft.

Consequence: Pilot can receive a plausible stale altitude. Warning/MFD closure needs the same contract review.

Evidence/result: probe-altitude-stale.json. Reproduced valid3000ft after10s stall. [HUD_Flight_Data.lua:118](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/HUD_Flight_Data.lua:118>), [Altitude_System.lua:85](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Altitude_System.lua:85>).

Complete-chain remedy: Create coherent source-qualified altitude reader shared by HUD/MFD/warning; keep World time separate from spawn time.

Retain: Independent altitude/CAS and explicit RDR fallback; generic standby.. Acceptance: normal: Complete input/provider/validity/effect/feedback chain; limit: Explicit numerical, resource, capacity and timing boundaries; failure: Withdraw affected capability without false completion or hidden truth substitute; recovery: Fresh current context/source/request; no stale replay. Packages: P-NAV-001. Untested: Synthetic owner stall; no claim DCS normally stalls this device. Native rendering unobserved..

### F-NAV-002 — Avionics competes with common MFD page authority

interface/architecture defect; priorityP1; severity: moderate; confidence: High within stated source/offline boundary. Accountable: chat2.

Trigger: Left ENG selected with MAIN_POWER=BATTERY_POWER=1 andAPU_RPM_STATE=2.

Expected: Common MFD controller owns page/view/visibility; Avionics supplies brightness/physical annunciators without changing selected format.; Remove superseded owners only after load/host/control proof; preserve saved IDs, current UFC, PMFD input transport and preference commands.

Current: MFD_Controller sets LMFD_ENG_PAGE1; actual Avionics.update sets0; controller update restores1.

Consequence: Selected engine format depends on callback order; native erasure/flicker is plausible but unobserved.

Evidence/result: probe-page-writers.json. Actual modules reproduce1->0->1. [Avionics.lua:329](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Avionics.lua:329>), [MFD_Controller.lua:96](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/MFD_Controller.lua:96>).

Complete-chain remedy: Move intended APU supply presentation to explicit common contract; remove obsolete page writers and audit blank/mask writers.

Retain: APU indications, brightness/night gain, selected layout, saved controls/audio.. Acceptance: normal: Complete input/provider/validity/effect/feedback chain; limit: Explicit numerical, resource, capacity and timing boundaries; failure: Withdraw affected capability without false completion or hidden truth substitute; recovery: Fresh current context/source/request; no stale replay. Packages: P-NAV-002. Untested: Native flicker not observed; ownership conflict is reproduced..

### F-NAV-003 — Common ADI vertical-speed text binds vv instead of VV

code defect; priorityP1; severity: moderate; confidence: High within stated source/offline boundary. Accountable: chat2.

Trigger: ADI selected during nonzero vertical speed.

Expected: ADI binds the same channel, units and validity as the authoritative vertical-speed producer. Distinguish measured zero from unavailable.

Current: Active common constructor binds lowercase vv; Avionics publishes uppercase VV. No owned lower-case producer found. Fixture reads0 when VV=1968.50394.

Consequence: May display plausible zero climb/descent; production channel mismatch proven, host case semantics separate.

Evidence/result: probe-adi-vv.json. Offline graph mismatch reproduced. [adi_page.lua:522](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/MFD_COMMON/adi_page.lua:522>), [Avionics.lua:269](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Avionics.lua:269>).

Complete-chain remedy: Migrate to one unit-qualified vertical-speed channel with validity; remove old alias after all consumers migrate.

Retain: ADI geometry/style and true zero.. Acceptance: normal: Complete input/provider/validity/effect/feedback chain; limit: Explicit numerical, resource, capacity and timing boundaries; failure: Withdraw affected capability without false completion or hidden truth substitute; recovery: Fresh current context/source/request; no stale replay. Packages: P-NAV-001. Untested: Native case sensitivity/private host publisher not established; verify before claiming observed DCS zero..

### F-NAV-004 — Native TACAN context identity is stored but never checked

interface/architecture defect; priorityP0 probe; severity: potential major native lifetime; confidence: High within stated source/offline boundary. Accountable: chat2.

Trigger: Host context changes without prior native reset (ordering not established).

Expected: Owned TACAN must belong to current cockpit context. Withdraw before context loss/change reuse, then matched destruction/recreation after outstanding callbacks stop.

Current: component_context saved on construction, never read. update reuses api.component with current context/ILS. EFM reset normally releases it.

Consequence: If sequence is allowed, stale object/measurement crosses contexts with potential invalid access.

Evidence/result: NativeNavigation and RAPTOR reset closure review. Missing identity guard confirmed; dangerous host sequence not reproduced. [NativeNavigation.cpp:272](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeNavigation.cpp:272>), [NativeNavigation.cpp:225](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeNavigation.cpp:225>).

Complete-chain remedy: First prove reset/context order with actual-adapter fixture and pinned host; enforce withdrawal/recreation only where needed with matched destructor.

Retain: ABI timestamp/image-size guard, allocator pairing and receiver validity.. Acceptance: normal: Complete input/provider/validity/effect/feedback chain; limit: Explicit numerical, resource, capacity and timing boundaries; failure: Withdraw affected capability without false completion or hidden truth substitute; recovery: Fresh current context/source/request; no stale replay. Packages: P-NAV-003. Untested: Host may guarantee reset before every context change; not an observed crash..

### F-NAV-005 — Voice and ident need independent capability decisions

host limitation; priorityP0 probe; severity: capability decision; confidence: High within stated source/offline boundary. Accountable: chat2.

Trigger: COM1/COM2 or station identification requested.

Expected: Select controls only after pinned-host lifecycle/tune/readback/RX/TX/PTT/audio proof. Menu opening does not prove transmission.; Declare ident policy and prove monitor/volume/mute independently from received LOC/GS and bearing/range. Current permanent mute is deliberate.

Current: clear_voice_backend=false; COM1 opens communications menu, COM2 unavailable. NativeNavigation deliberately mutes both ident receivers each update.

Consequence: No complete selected dual-radio/guard/preset/ident chain; LOC/GS or menu access cannot prove voice/audio.

Evidence/result: UFC/profile/native audio source review. Selected-off voice and mute confirmed; host feasibility unknown. [UFC_Controller.lua:280](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/UFC_Controller.lua:280>), [Equipment_Profile.lua:9](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Equipment_Profile.lua:9>), [NativeNavigation.cpp:213](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeNavigation.cpp:213>).

Complete-chain remedy: Prove lifecycle/tune/RX/TX/PTT/audio; only then select optional profile and implement. Investigate ident separately.

Retain: Truthful unavailable state, communications menu and receiver measurements.. Acceptance: normal: Complete input/provider/validity/effect/feedback chain; limit: Explicit numerical, resource, capacity and timing boundaries; failure: Withdraw affected capability without false completion or hidden truth substitute; recovery: Fresh current context/source/request; no stale replay. Packages: P-NAV-003, P-NAV-004. Untested: No DCS voice/ident test; disabled equipment is not automatically a defect..

### F-NAV-006 — GINS estimates and AFCS source mapping need explicit boundaries

calibration uncertainty; priorityP1; severity: model boundary; confidence: High within stated source/offline boundary. Accountable: chat2.

Trigger: Alignment/coast/source failure; AFCS HSEL with selected GINS heading failure.

Expected: Retain HUD/NAV/SFG selection and component health, coherent frames and coast. Label estimated schedules. Explicitly declare AFCS heading/attitude provider and failure mapping.

Current: Two references now exist.480/90/30s alignment and uncertainty budgets are estimates. AFCS uses raw EFM heading with Frame.heading_valid defaulttrue; navigationFrame does not copy selected GINS health.

Consequence: Old single-GINS claim obsolete. Production fidelity unknown; AFCS failure expectations cannot be inferred from cockpit selection alone.

Evidence/result: Current GINS/INS/AFCS source and diagnostic tests. Narrow implementation credited; provider policy unresolved. [Gins_References.lua:53](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Gins_References.lua:53>), [INS_Model.lua:8](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/INS_Model.lua:8>), [Gins_Alignment.lua:49](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Gins_Alignment.lua:49>).

Complete-chain remedy: Agree explicit AFCS sensor mapping with flight owner before changes; separate calibration from validation and retain estimate labels.

Retain: Independent HUD/NAV/SFG selections; fail-closed GINS; GPS observation distinct from aiding toggle.. Acceptance: normal: Complete input/provider/validity/effect/feedback chain; limit: Explicit numerical, resource, capacity and timing boundaries; failure: Withdraw affected capability without false completion or hidden truth substitute; recovery: Fresh current context/source/request; no stale replay. Packages: P-NAV-001, P-NAV-006. Untested: No recovered production alignment/redundancy schedule; do not assert HSEL must use NAV GINS absent decision..

### F-NAV-007 — Owned envelope warning catalogue and native-bingo-to-cockpit connection need closure

source-backed gap; priorityP2; severity: missing attention cue; confidence: High within stated source/offline boundary. Accountable: chat2.

Trigger: Approach selected envelope limit or mission reserve.

Expected: Preserve the existing native threshold and actual native kilograms; qualify FuelBingo field validity/schema/generation/stamp before cockpit consumption; define low-fuel versus pilot-set bingo occurrence/ACK/hysteresis/audio separately. Choose evidence-supported or explicitly estimated overspeed threshold with flight owner.

Current: Native threshold already exists:11714 adds value to BingoRequest clamped0..12000 kg, F22_BINGO_KG_REQUEST; vehicle_publish_fuel publishes EFM_FUEL_BINGO when finite threshold>0 and total_fuel<threshold. Avionics instead mirrors drawarg225 into BINGO_LIGHT, consumed by both UFD. Reviewed fault/voice catalogue has no owned bingo event and no overspeed event.

Consequence: Current pilot-set native bingo cause lacks an owned current cockpit lamp/attention/audio bridge; legacy visual argument is a separate cause. Historical AIRSPEED ICAW catalogue decision also remains.

Evidence/result: Rainey/Kohn EMD passage; current warning/fault/Avionics closure. Source correction: threshold present; current cockpit cause path remains disconnected.. [Pilot_Warnings.lua:2](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Pilot_Warnings.lua:2>), [Fault_Registry.lua:2](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Fault_Registry.lua:2>), [VehicleIntegration.h:419](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/VehicleIntegration.h:419>).

Complete-chain remedy: Use I-NAV-006 across chat1 producer/chat2 alert consumer; retain11714 and threshold. Add qualified provider cause and current attention/lamp/audio routing if selected. Remove drawarg225 publisher only after migration. No replacement threshold implementation.

Retain: Distinct occurrence/ACK/history, finite voice lease and recordings.. Acceptance: normal: Complete input/provider/validity/effect/feedback chain; limit: Explicit numerical, resource, capacity and timing boundaries; failure: Withdraw affected capability without false completion or hidden truth substitute; recovery: Fresh current context/source/request; no stale replay. Packages: P-NAV-005. Untested: No native bingo-to-lamp runtime observation; no authenticated production warning thresholds..

### F-NAV-008 — Retired ICP helpers and unreachable PMFD branches remain

cleanup candidate; priorityP2; severity: maintenance; confidence: High within stated source/offline boundary. Accountable: chat2.

Trigger: Maintenance of current input/page owners.

Expected: Remove superseded owners only after load/host/control proof; preserve saved IDs, current UFC, PMFD input transport and preference commands.

Current: ICP_System loads UFC_Controller. PMFD forwards every matching OSB and returns before old CONFIG branches; select_page has no call.

Consequence: Dormant duplicate workflow misleads future edits; active11301..11305 preferences must remain.

Evidence/result: Registration/literal-loader closure and local early-return proof. Local dead branches high confidence; external arbitrary loader unresolved. [PMFD_System.lua:101](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/PMFD_System.lua:101>), [ICP_Flight_Pages.lua:4](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/ICP_Flight_Pages.lua:4>), [ICP_Stores_Page.lua:5](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/ICP_Stores_Page.lua:5>).

Complete-chain remedy: Prove full load/host graph then remove precise dead regions/helpers during execution; preserve active transport/preferences.

Retain: Saved IDs and physical press/release ownership.. Acceptance: normal: Complete input/provider/validity/effect/feedback chain; limit: Explicit numerical, resource, capacity and timing boundaries; failure: Withdraw affected capability without false completion or hidden truth substitute; recovery: Fresh current context/source/request; no stale replay. Packages: P-NAV-002. Untested: No whole-directory deletion justified; arbitrary external loaders need retirement gate..

### F-NAV-009 — Optics and surviving emergency CNI remain runtime unqualified

host limitation; priorityP1; severity: qualification limit; confidence: High within stated source/offline boundary. Accountable: chat2.

Trigger: 2D/VR head movement, approach or supply loss.

Expected: Preserve HUD font/color/projection/audio and qualify FPM/cage/ghost/E-bracket/angular alignment/readout clearance in2D/VR against pinned installed/build identity.

Current: Explicit HUD geometry substitutes missing EDM connector triplet.12degree normal reference plus Hornet-derived bracket. Receiver feed is generator+DC estimate; battery/GPU/APU AC conversion unqualified.

Consequence: Offline logic/preview cannot establish native optics, recovery usefulness or retained CNI.

Evidence/result: device_init/CNI-03/current profile and source review. Qualification gap retained. [HUD_FlightMath.lua:17](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/HUD_FlightMath.lua:17>), [Equipment_Profile.lua:9](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Equipment_Profile.lua:9>).

Complete-chain remedy: Staged controlled optical/source/supply trial after build/package/loaded identity; model only supportable retained topology.

Retain: Current HUD styling, manual-only recovery and explicit optional exclusions.. Acceptance: normal: Complete input/provider/validity/effect/feedback chain; limit: Explicit numerical, resource, capacity and timing boundaries; failure: Withdraw affected capability without false completion or hidden truth substitute; recovery: Fresh current context/source/request; no stale replay. Packages: P-NAV-007. Untested: No DCS operated; no2D/VR/MP claim..

### F-RAD-001 — Legacy Lua scan enclosure hides real owned AESA detections

interface/architecture defect; priorityP1; severity: high simulator consequence; confidence: high for stated code condition; runtime limits explicit. Accountable: chat3.

Trigger: TWS selected target near0deg, new source 2 hit at 50deg inside actual60deg search.

Expected: Actual sensed current reports must reach consumers; search stays pilot volume between priority revisits.

Current: scan_plan narrows Lua admission to30deg while AESA_Control commands60deg; supplied valid report84 disappears, only track42 remains. SCAN AUTO/support fields describe obsolete enclosure.

Consequence: Silent loss of situational awareness and misleading scan/support indication.

Evidence/result: RAD-PROBE-002/003 in radar_probe.py: actual Radar_System plus independent Computer/Control calls.. reproduced. [Radar_Computer.lua:110](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Radar_Computer.lua:110>), [Radar_Computer.lua:458](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Radar_Computer.lua:458>), [AESA_Control.lua:108](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/AESA_Control.lua:108>).

Complete-chain remedy: Make sensed source 2 acceptance authoritative; migrate consumers to actual tasks/deadline/age and remove old enclosing scan authority without replacing physical sensor.

Retain: Single array owner, original observation epochs, current degraded states, saved control IDs, HUD styling/audio.. Acceptance: normal: Full request/provider/consumer/pilot chain works.; limit: Finite caps, variable cadence, no invented observations.; failure: Malformed/stale/torn/unavailable data withdraw authority.; recovery: Fresh new epoch/report restores deliberately; no stale intent replay.. Packages: P-RAD-001. Untested: Native runtime/aircraft qualification remains open.

### F-RAD-002 — Selected-track closure can be NaN while valid

code defect; priorityP2; severity: moderate simulator consequence; confidence: high for stated code condition; runtime limits explicit. Accountable: chat3.

Trigger: Fresh selected TWS track; EFM_HUD_VALID1 but ownship VN=NaN/inf.

Expected: Valid closure must be finite; invalid component withdraws closure only.

Current: Selected branch uses EFM_HUD velocity without finite checks and publishes valid1; probe yields closure NaN, valid1. STT branch checks finite separately.

Consequence: False healthy numeric publication can reach pilot/format/engagement fields; no crash claimed.

Evidence/result: RAD-PROBE-001 actual Radar_System injection.. reproduced. [Radar_System.lua:939](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Radar_System.lua:939>).

Complete-chain remedy: Validate all input components and final result consistently; publish invalid field without poisoning track; declare cursor elapsed-time/pause policy.

Retain: Single array owner, original observation epochs, current degraded states, saved control IDs, HUD styling/audio.. Acceptance: normal: Full request/provider/consumer/pilot chain works.; limit: Finite caps, variable cadence, no invented observations.; failure: Malformed/stale/torn/unavailable data withdraw authority.; recovery: Fresh new epoch/report restores deliberately; no stale intent replay.. Packages: P-RAD-002. Untested: Native runtime/aircraft qualification remains open.

### F-RAD-003 — Surface association still uses simulator identity

interface/architecture defect; priorityP2; severity: moderate simulator consequence; confidence: high for stated code condition; runtime limits explicit. Accountable: chat3.

Trigger: Crossing/close/jumping surface objects with sparse measurements.

Expected: Measured association/covariance should decide correspondence; host binding stays private.

Current: Noisy EKF measurements exist, but filter(truth.id), Tracks::observe and selected object_id matching provide perfect association.

Consequence: Unrealistically perfect identity through ambiguity; risk of wrong inherited surface handoff.

Evidence/result: Body/caller trace; ground numerical/native diagnostics.. source-supported scope/limit. [GroundMovingTargets.h:83](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/GroundMovingTargets.h:83>), [NativeGroundSensor.cpp:365](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeGroundSensor.cpp:365>).

Complete-chain remedy: Introduce owned surface tokens, measured mutual-neighbor/uncertainty gates and explicit ambiguous coast; private bindings only at actual effect; publish covariance/generation/time and migrate consumers.

Retain: Single array owner, original observation epochs, current degraded states, saved control IDs, HUD styling/audio.. Acceptance: normal: Full request/provider/consumer/pilot chain works.; limit: Finite caps, variable cadence, no invented observations.; failure: Malformed/stale/torn/unavailable data withdraw authority.; recovery: Fresh new epoch/report restores deliberately; no stale intent replay.. Packages: P-RAD-003. Untested: Native runtime/aircraft qualification remains open.

### F-RAD-004 — Coherent SAR remains research without host integration

host limitation; priorityP2; severity: capability limit; confidence: high for stated code condition; runtime limits explicit. Accountable: chat3.

Trigger: Attempt to adopt coherent SAR under broad selected radar profile.

Expected: Coherent SAR claim needs actual granted return collection, phase/motion history, formation and publication.

Current: Production uses shared GM_F16/EXP_F16/DBS1/DBS2 presets. CPU/GPU prototypes do not establish terrain/thread/texture ABI or full-footprint DCS performance.

Consequence: Current useful approximation does not establish phase-history SAR; feature/host decision required.

Evidence/result: Source and research inspected; no benchmark rerun or DCS timing claim.. source-supported scope/limit. [NativeGroundVideo.cpp:191](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeGroundVideo.cpp:191>), [GroundVideoView.h:206](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/GroundVideoView.h:206>), [SEN-04-SAR-research.md:1](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/docs/overhaul/SEN-04-SAR-research.md:1>).

Complete-chain remedy: Decide SAR applicability, prove environment/output host interfaces first, then bounded leased collection/formation; retain declared DBS approximation if blocked.

Retain: Single array owner, original observation epochs, current degraded states, saved control IDs, HUD styling/audio.. Acceptance: normal: Full request/provider/consumer/pilot chain works.; limit: Finite caps, variable cadence, no invented observations.; failure: Malformed/stale/torn/unavailable data withdraw authority.; recovery: Fresh new epoch/report restores deliberately; no stale intent replay.. Packages: P-RAD-005, P-RAD-006. Untested: Native runtime/aircraft qualification remains open.

### F-RAD-005 — Current integrated radar package lacks complete runtime qualification

host limitation; priorityP1; severity: qualification blocker; confidence: high for stated code condition; runtime limits explicit. Accountable: chat3.

Trigger: Current build, actual missiles, failures, re-slot, host update, dense scene, VR/MP.

Expected: Readiness, offline tests, installed hashes and actual runtime effects are independent evidence axes.

Current: Guards/epochs/leases exist; old flown DLL predates several scheduler/association/ground changes. Actual callback quiescence and current multi-target support, ground/VR/MP not independently established.

Consequence: Cannot close current release gates from ready flags or earlier flight; potential lifecycle hazards need proof, not assumed crash verdict.

Evidence/result: 7/8 fresh strict native builds/runs pass; native ground /W4 /WX /analyze fails C6011 at motion():122 behind readable() guard.. source-supported scope/limit. [NativeAesaRadar.cpp:704](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeAesaRadar.cpp:704>), [NativeGroundVideo.cpp:259](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeGroundVideo.cpp:259>).

Complete-chain remedy: Pin source/package/loaded identities; instrument callback phase/lifetime; qualify actual sensing/render/support outcomes and separate failure sorties. Resolve or narrowly justify C6011 warning without claiming null crash.

Retain: Single array owner, original observation epochs, current degraded states, saved control IDs, HUD styling/audio.. Acceptance: normal: Full request/provider/consumer/pilot chain works.; limit: Finite caps, variable cadence, no invented observations.; failure: Malformed/stale/torn/unavailable data withdraw authority.; recovery: Fresh new epoch/report restores deliberately; no stale intent replay.. Packages: P-RAD-004. Untested: Native runtime/aircraft qualification remains open.

### F-RAD-006 — IFF request controls have no owned reply chain

source-backed gap; priorityP2; severity: capability gap; confidence: high for stated code condition; runtime limits explicit. Accountable: chat3.

Trigger: AUTO/interrogate selected expecting achieved replies.

Expected: Requested interrogation must distinguish achieved reply/provenance from unavailability.

Current: IFF request/ON state changes; reply() has no active caller; owned source 2 observations always iff=-1. Fusion identity remains separate.

Consequence: UI can imply an operational request path with no radar reply capability.

Evidence/result: Caller/load trace and actual observation construction.. source-supported scope/limit. [Radar_IFF.lua:6](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Radar_IFF.lua:6>), [AESA_Control.lua:60](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/AESA_Control.lua:60>), [Radar_System.lua:426](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Radar_System.lua:426>).

Complete-chain remedy: Chat 4 owns achieved IFF/evidence backend; chat3 integrates agreed source/request/validity/age seam and accurate indications; never substitute coalition truth.

Retain: Single array owner, original observation epochs, current degraded states, saved control IDs, HUD styling/audio.. Acceptance: normal: Full request/provider/consumer/pilot chain works.; limit: Finite caps, variable cadence, no invented observations.; failure: Malformed/stale/torn/unavailable data withdraw authority.; recovery: Fresh new epoch/report restores deliberately; no stale intent replay.. Packages: P-RAD-007. Untested: Native runtime/aircraft qualification remains open.

### F-RAD-007 — Retired synthetic ground returns and radar telemetry linger

cleanup candidate; priorityP2; severity: maintenance/test validity; confidence: high for stated code condition; runtime limits explicit. Accountable: chat3.

Trigger: Normal update or old synthetic fixture.

Expected: Retire superseded paths after supported-profile/caller migration and remake checks against current contracts.

Current: Return count forced0; decoder test-only include; Lua reads old F22G and writes256 map slots; telemetry retains F22O/F22N readers. Tests still inject retired producer answers.

Consequence: Recurring work and false integration confidence; not proof host callbacks removable.

Evidence/result: Caller/include/load search plus producer trace.. source-supported scope/limit. [NativeGroundRadar.cpp:19](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeGroundRadar.cpp:19>), [NativeGroundReturns.h:16](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeGroundReturns.h:16>), [AG_Radar_System.lua:325](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/AG_Radar_System.lua:325>).

Complete-chain remedy: Prove supported callers, remove old noise overlay/decoder/readers after current path coverage; preserve callbacks/control IDs/history.

Retain: Single array owner, original observation epochs, current degraded states, saved control IDs, HUD styling/audio.. Acceptance: normal: Full request/provider/consumer/pilot chain works.; limit: Finite caps, variable cadence, no invented observations.; failure: Malformed/stale/torn/unavailable data withdraw authority.; recovery: Fresh new epoch/report restores deliberately; no stale intent replay.. Packages: P-RAD-001. Untested: Native runtime/aircraft qualification remains open.

### F-RAD-008 — Radar depth and numerical aircraft fidelity remain uncertain

calibration uncertainty; priorityP2; severity: fidelity uncertainty; confidence: high for stated code condition; runtime limits explicit. Accountable: chat3.

Trigger: Claiming real APG77 ranges/ECCM/LPI or dense combat availability.

Expected: Declare estimates/omissions, validate mathematics separately from aircraft calibration and selected fit.

Current: Fixed declared RCS/reference range/noise/clutter/dwell/EKF policies; common airborne ECM only. CFAR/false alarms/deception/ground interference/waveform agility remain open.

Consequence: Known fidelity/evidence limits; no defensible accuracy percentage or production parameter claim.

Evidence/result: Source constants/body review and fresh model/filter/scheduler diagnostics.. source-supported scope/limit. [AesaRadar.h:95](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/AesaRadar.h:95>), [AesaRadar.cpp:411](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/AesaRadar.cpp:411>), [AesaReceiver.h:7](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/AesaReceiver.h:7>).

Complete-chain remedy: Version assumptions, sensitivity/convergence/independent validation; decide selected depth and only implement feasible complete chains with bounded provider.

Retain: Single array owner, original observation epochs, current degraded states, saved control IDs, HUD styling/audio.. Acceptance: normal: Full request/provider/consumer/pilot chain works.; limit: Finite caps, variable cadence, no invented observations.; failure: Malformed/stale/torn/unavailable data withdraw authority.; recovery: Fresh new epoch/report restores deliberately; no stale intent replay.. Packages: P-RAD-008. Untested: Native runtime/aircraft qualification remains open.

### F-WPN-001 — Pending A/G release crashes when native weapon device disappears

software defect; priorityP1; severity: major simulator functionality loss; confidence: high. Accountable: chat4.

Trigger: One accepted launch request remains pending, then GetDevice returns nil.

Expected: Native loss must cancel/retire pending work into honest unresolved state, stop native commands where possible, publish unavailable feedback and require fresh consent after recovery.

Current: update calls choose_station(native, false) at 965 despite native_ready=false; choose_station401 dereferences nil. Independent probe issued one request, PENDING1 then reproduced exception.

Consequence: major simulator functionality loss

Evidence/result: probe-pending-native-loss in PROBE-RESULTS.json. actual unmodified owning Lua module in independent minimal host ports. [Weapon_System.lua:965](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Weapon_System.lua:965>), [Weapon_System.lua:401](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Weapon_System.lua:401>).

Complete-chain remedy: Native loss must cancel/retire pending work into honest unresolved state, stop native commands where possible, publish unavailable feedback and require fresh consent after recovery. Migrate all callers/publications and retain actual effects/readiness separation.

Retain: Saved command IDs and physical DOWN semantics; Native inventory/armed launch IDs; no count-only ACK; Preferred HUD styling and existing audio assets; Current source 2 highrate gun aiming. Acceptance: Normal path reaches actual effect and request-correlated feedback.; Bounds/invalid input never create readiness or replay.; Failure withdraws current authority; unresolved effects retained until reconciliation.; Recovery requires fresh press/current generation and does not reuse stale acknowledgement.. Packages: P-WPN-001. Untested: No actual DCS execution or effect observed in this audit..

### F-WPN-002 — CCIP bay-delay prediction consumes different physical authority from actual doors

interface contract defect; priorityP1; severity: major simulator functionality loss; confidence: high. Accountable: chat4.

Trigger: Utility supply differs from flight-control supply or physical publication becomes stale/torn.

Expected: Bay-delay prediction must consume the same qualified utility/electrical/mission envelope and actual bay/station as the achieved door owner, with explicit invalidation and one clock contract.

Current: AG_Ballistic_Computer148 reads raw EFM_VEHICLE_VALID/EFM_ACTUATOR_AVAILABLE; Weapon_System880 uses qualified physical_supply.utility. Forecast may remain valid or use wrong delay while achieved door motion differs.

Consequence: major simulator functionality loss

Evidence/result: not established; exact limit retained. static source/dataflow evidence; runtime qualification outstanding. [AG_Ballistic_Computer.lua:148](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/AG_Ballistic_Computer.lua:148>), [Weapon_System.lua:880](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Weapon_System.lua:880>), [Weapon_Physical_State.lua:67](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Weapon_Physical_State.lua:67>).

Complete-chain remedy: Bay-delay prediction must consume the same qualified utility/electrical/mission envelope and actual bay/station as the achieved door owner, with explicit invalidation and one clock contract. Migrate all callers/publications and retain actual effects/readiness separation.

Retain: Saved command IDs and physical DOWN semantics; Native inventory/armed launch IDs; no count-only ACK; Preferred HUD styling and existing audio assets; Current source 2 highrate gun aiming. Acceptance: Normal path reaches actual effect and request-correlated feedback.; Bounds/invalid input never create readiness or replay.; Failure withdraws current authority; unresolved effects retained until reconciliation.; Recovery requires fresh press/current generation and does not reuse stale acknowledgement.. Packages: P-WPN-002. Untested: No actual DCS execution or effect observed in this audit..

### F-WPN-003 — SEMI/AUTO availability lacks a production warning-event input

missing selected behavior chain; priorityP1; severity: major simulator functionality loss; confidence: high. Accountable: chat4.

Trigger: Pilot chooses SEMI/AUTO/CONSENT during ordinary RWR/MWS warning encounters.

Expected: Expose automatic capability only when a declared, qualified abstract game event source is connected. Connect source identity/time/generation, event lifecycle and explicit program-selection policy through consent to observed cartridge effect, or show unavailable until supported.

Current: Runner modes/consent/effects exist, but sole event() caller is EW_System11110 neutral scripted stimulus. Effective input cleanup removes11110; no production warning producer found. AUTO_AVAILABLE equals readiness and DEF presents mode/consent.

Consequence: major simulator functionality loss

Evidence/result: not established; exact limit retained. static source/dataflow evidence; runtime qualification outstanding. [EW_Dispenser.lua:59](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/EW_Dispenser.lua:59>), [EW_System.lua:64](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/EW_System.lua:64>), [EW_System.lua:112](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/EW_System.lua:112>).

Complete-chain remedy: Expose automatic capability only when a declared, qualified abstract game event source is connected. Connect source identity/time/generation, event lifecycle and explicit program-selection policy through consent to observed cartridge effect, or show unavailable until supported. Migrate all callers/publications and retain actual effects/readiness separation.

Retain: Saved command IDs and physical DOWN semantics; Native inventory/armed launch IDs; no count-only ACK; Preferred HUD styling and existing audio assets; Current source 2 highrate gun aiming. Acceptance: Normal path reaches actual effect and request-correlated feedback.; Bounds/invalid input never create readiness or replay.; Failure withdraws current authority; unresolved effects retained until reconciliation.; Recovery requires fresh press/current generation and does not reuse stale acknowledgement.. Packages: P-WPN-003. Untested: No operational threat-response recipe or real countermeasure algorithm is requested. Neutral event engine works; choice of generic game event/selection policy must be declared..

### F-WPN-004 — Legacy A/A-typed JDAM is advertised as supported guided A/G

software defect; priorityP1; severity: major simulator functionality loss; confidence: high. Accountable: chat4.

Trigger: A mission loads compatibility CLSID {GBU32_JDAM}.

Expected: Keep compatibility identity only with explicit unavailable/legacy presentation until callers/presets migrate to a qualified stock coordinate-guided bomb, or implement and qualify the complete actual native type path.

Current: Catalogue returns supported=true/kind7/guided=true. Legacy definition is CAT_AIR_TO_AIR/wsType_AA_Missile. Weapon owner marks bomb only level2==5 and native coordinate hook only bomb class; label/support and actual delivery disagree.

Consequence: major simulator functionality loss

Evidence/result: probe-legacy-jdam-capability in PROBE-RESULTS.json. actual unmodified owning Lua module in independent minimal host ports. [Store_Capabilities.lua:12](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Store_Capabilities.lua:12>), [GBU_32.lua:35](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Weapons/GBU_32.lua:35>), [Weapon_System.lua:417](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Weapon_System.lua:417>).

Complete-chain remedy: Keep compatibility identity only with explicit unavailable/legacy presentation until callers/presets migrate to a qualified stock coordinate-guided bomb, or implement and qualify the complete actual native type path. Migrate all callers/publications and retain actual effects/readiness separation.

Retain: Saved command IDs and physical DOWN semantics; Native inventory/armed launch IDs; no count-only ACK; Preferred HUD styling and existing audio assets; Current source 2 highrate gun aiming. Acceptance: Normal path reaches actual effect and request-correlated feedback.; Bounds/invalid input never create readiness or replay.; Failure withdraws current authority; unresolved effects retained until reconciliation.; Recovery requires fresh press/current generation and does not reuse stale acknowledgement.. Packages: P-WPN-007. Untested: No actual DCS execution or effect observed in this audit..

### F-WPN-005 — Malformed station weapon field escapes descriptor validation

software defect; priorityP2; severity: malformed external-input robustness; confidence: high. Accountable: chat4.

Trigger: Host or mock provides valid count with nonnil non-table info.weapon.

Expected: Validate descriptor table shape once at native station ingress, reject/invalidate malformed inventory before capability/IR consumers, keep other stations/system running.

Current: key() type-checks weapon, describe() assigns info.weapon or{} then indexes w.level4; actual call with weapon=7 throws51. IR_Seeker.profile has similar shape assumption.

Consequence: malformed external-input robustness

Evidence/result: probe-capability-wrong-type in PROBE-RESULTS.json. actual unmodified owning Lua module in independent minimal host ports. [Store_Capabilities.lua:47](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Store_Capabilities.lua:47>), [Store_Capabilities.lua:51](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Store_Capabilities.lua:51>), [IR_Seeker.lua:8](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/IR_Seeker.lua:8>).

Complete-chain remedy: Validate descriptor table shape once at native station ingress, reject/invalidate malformed inventory before capability/IR consumers, keep other stations/system running. Migrate all callers/publications and retain actual effects/readiness separation.

Retain: Saved command IDs and physical DOWN semantics; Native inventory/armed launch IDs; no count-only ACK; Preferred HUD styling and existing audio assets; Current source 2 highrate gun aiming. Acceptance: Normal path reaches actual effect and request-correlated feedback.; Bounds/invalid input never create readiness or replay.; Failure withdraws current authority; unresolved effects retained until reconciliation.; Recovery requires fresh press/current generation and does not reuse stale acknowledgement.. Packages: P-WPN-001. Untested: No evidence that current valid DCS get_station_info produces this malformed payload; this is a demonstrated fault-injection contract defect, not an observed live flight failure..

### F-WPN-006 — Missing model clock is reported as valid timed CM readiness

software defect; priorityP2; severity: false timed-readiness qualification; confidence: high. Accountable: chat4.

Trigger: get_model_time unavailable in a mismatched/incomplete host environment.

Expected: Require qualified advancing/current World-clock source for timed execution or publish explicitly separate substitute-clock policy with reduced capability. CLOCK_VALID must describe the actual clock qualification.

Current: EW_System160 sets clock_valid=true and advances fixed0.05 per callback when function absent. Independent actual-owner probe returns CLOCK_VALID1/READY1 with missing clock.

Consequence: false timed-readiness qualification

Evidence/result: probe-cm-missing-clock in PROBE-RESULTS.json. actual unmodified owning Lua module in independent minimal host ports. [EW_System.lua:153](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/EW_System.lua:153>), [EW_System.lua:160](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/EW_System.lua:160>).

Complete-chain remedy: Require qualified advancing/current World-clock source for timed execution or publish explicitly separate substitute-clock policy with reduced capability. CLOCK_VALID must describe the actual clock qualification. Migrate all callers/publications and retain actual effects/readiness separation.

Retain: Saved command IDs and physical DOWN semantics; Native inventory/armed launch IDs; no count-only ACK; Preferred HUD styling and existing audio assets; Current source 2 highrate gun aiming. Acceptance: Normal path reaches actual effect and request-correlated feedback.; Bounds/invalid input never create readiness or replay.; Failure withdraws current authority; unresolved effects retained until reconciliation.; Recovery requires fresh press/current generation and does not reuse stale acknowledgement.. Packages: P-WPN-003. Untested: Normal DCS clock exists; missing-function behavior is a degraded/host-compatibility boundary. No present flight timing failure is claimed..

### F-WPN-007 — Native payload hook and passive sources lack demonstrated full callback retirement contract

native qualification gap; priorityP1; severity: potential callback fault/stale publication; no probability assigned; confidence: medium; qualification gap certain, concurrent failure unproven. Accountable: chat4.

Trigger: Payload launch callback overlaps reset/unhook or native MWS/datalink object teardown; host serialization unknown.

Expected: Establish exact callback/thread ownership, stop/unregister producers, drain all in-flight payload/native uses before resetting borrowed parameter/object resources, and qualify late callbacks/re-slot. Add coherent generations where serialization cannot guarantee snapshots.

Current: FeedbackGuard drains NativeSidewinder.update, but record_payload_launch is outside it and copies borrowed EDPARAM cache after releasing ground lock. NativeMWS READY is published before slots and has no sequence. Source guard/readability does not prove lifetime.

Consequence: potential callback fault/stale publication; no probability assigned

Evidence/result: not established; exact limit retained. static source/dataflow evidence; runtime qualification outstanding. [NativeSidewinder.cpp:393](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeSidewinder.cpp:393>), [NativeSidewinder.cpp:673](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeSidewinder.cpp:673>), [NativeMWS.cpp:339](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeMWS.cpp:339>).

Complete-chain remedy: Establish exact callback/thread ownership, stop/unregister producers, drain all in-flight payload/native uses before resetting borrowed parameter/object resources, and qualify late callbacks/re-slot. Add coherent generations where serialization cannot guarantee snapshots. Migrate all callers/publications and retain actual effects/readiness separation.

Retain: Saved command IDs and physical DOWN semantics; Native inventory/armed launch IDs; no count-only ACK; Preferred HUD styling and existing audio assets; Current source 2 highrate gun aiming. Acceptance: Normal path reaches actual effect and request-correlated feedback.; Bounds/invalid input never create readiness or replay.; Failure withdraws current authority; unresolved effects retained until reconciliation.; Recovery requires fresh press/current generation and does not reuse stale acknowledgement.. Packages: P-WPN-006. Untested: No actual DCS execution or effect observed in this audit..

### F-NAV-010 — Legacy side indications bypass modeled field health and reference selection

confirmed source gap; priorityP1; severity: Powered side displays can present an unqualified number beside correctly withdrawn attitude/engine fields.; confidence: High for the cited source behavior; host effect requires stated qualification. Accountable: chat2.

Trigger: A selected ADC, radar-height, GINS heading/position channel becomes invalid while cockpit power/page remain available.

Expected: Each displayed field must consume one selected current producer with field validity, coherent generation/source identity and bounded age. Failed ADC/GINS/radar channel must not be replaced by unrestricted host truth.

Current: Avionics samples raw base IAS, radar altitude, Mach and heading every6ms and publishes IAS/RADALT/MACH/NAV without native AIRDATA, selected GINS heading or independent radar field health. Common ADI IAS/NAV and both UFD IAS/NAV/RADALT bind only opacity/page gates. Attitude strokes and engine numbers are correctly qualified, so that protection does not extend to the adjacent numbers.

Consequence: Powered side displays can present an unqualified number beside correctly withdrawn attitude/engine fields.

Evidence/result: Fresh source control-flow and complete current producer/consumer closure; no runtime in residue pass.. Confirmed source contract issue within stated boundary. [Avionics.lua:260](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Avionics.lua:260>), [Avionics.lua:274](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Avionics.lua:274>), [Avionics.lua:295](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Avionics.lua:295>).

Complete-chain remedy: Extend the qualified snapshot/typed readout contract to IAS/NAV/RADALT/MACH/AOA/G/fuel as applicable, define field-specific source applicability, remove corresponding raw Avionics publishers only after current consumers migrated.

Retain: Current appearance, stable saved command IDs and qualified owner protocols; preserve unaffected valid capabilities.. Acceptance: normal: Complete input/provider/validity/effect/feedback chain; limit: Explicit numerical, resource, capacity and timing boundaries; failure: Withdraw affected capability without false completion or hidden truth substitute; recovery: Fresh current context/source/request; no stale replay. Packages: P-NAV-001, P-NAV-008. Untested: No assertion that DCS always keeps raw methods healthy after failure or that a specific visible wrong number occurred. Correlated native producer invalid-atmosphere root belongs to flight finding; this is the independently missing consumer gates..

### F-NAV-011 — Day/Night binding sends two toggles for one press/release cycle

interface/architecture defect; priorityP2; severity: The momentary Day/Night binding can appear ineffective after release and may flash mode while held.; confidence: High for the cited source behavior; host effect requires stated qualification. Accountable: chat2.

Trigger: Use saved/default Day/Night command10017 with normal key/button down followed by up.

Expected: Define the existing maintained/absolute/held versus toggle contract, then route each intended press/release/idempotent state accordingly. A demonstrated value-independent toggle is not by itself proof the maintained binding was intended as one persistent toggle.

Current: Keyboard and joystick define down=DayNight, up=DayNight. Avionics flips day_night for10017 regardless of value, so a delivered press and release invert it twice.10018 is a separate toggle alias; mouse TUMB source semantics differ.

Consequence: The momentary Day/Night binding can appear ineffective after release and may flash mode while held.

Evidence/result: Fresh source control-flow and complete current producer/consumer closure; no runtime in residue pass.. Confirmed source contract issue within stated boundary. [default.lua:361](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Input/F-22A/keyboard/default.lua:361>), [default.lua:322](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Input/F-22A/joystick/default.lua:322>), [Avionics.lua:204](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/Systems/Avionics.lua:204>).

Complete-chain remedy: Agree and document10017 maintained/absolute/held versus10018toggle semantics; preserve saved IDs and intended behavior, then apply matching edge decoding and independent repeated/release tests. Do not blanket-ignore releases.

Retain: Current appearance, stable saved command IDs and qualified owner protocols; preserve unaffected valid capabilities.. Acceptance: normal: Complete input/provider/validity/effect/feedback chain; limit: Explicit numerical, resource, capacity and timing boundaries; failure: Withdraw affected capability without false completion or hidden truth substitute; recovery: Fresh current context/source/request; no stale replay. Packages: P-NAV-008. Untested: Host normal down/up delivery not executed here; malformed values and hardware maintained switches require remade sequences. Mouse click behavior is not inferred from keyboard declarations..

### F-NAV-012 — Mouse UFD swap buttons omit the release their latch requires

source/host contract mismatch; priorityP2; severity: If the host honors the declared false release flag, the first mouse swap latches and later presses cannot swap until state reload or another matching release.; confidence: High for the cited source behavior; host effect requires stated qualification. Accountable: chat2.

Trigger: Press then release either physical cockpit SMFD swap button and press again.

Expected: A releasable physical button must deliver the transport release required by its owner; focus/page/power/lifecycle loss also must cancel held state without replay.

Current: L_SMFD_1 and R_SMFD_1 use default_button with use_release_message=false. The release-enabling loops cover L/R/B_MFD_,PMFD_ and ICP_, not L/R_SMFD_. Avionics sets swap_held on down and permits another swap only after decoded up.

Consequence: If the host honors the declared false release flag, the first mouse swap latches and later presses cannot swap until state reload or another matching release.

Evidence/result: Fresh source control-flow and complete current producer/consumer closure; no runtime in residue pass.. Confirmed source contract issue within stated boundary. [clickabledata.lua:37](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/clickabledata.lua:37>), [clickabledata.lua:387](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/clickabledata.lua:387>), [clickabledata.lua:528](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/clickabledata.lua:528>).

Complete-chain remedy: Enable/route mouse release for both SMFD commands or replace latch protocol with an explicit supported impulse transport; keep key aliases10027/10910 and hardware semantics. Add lifecycle cancel path if Avionics remains owner.

Retain: Current appearance, stable saved command IDs and qualified owner protocols; preserve unaffected valid capabilities.. Acceptance: normal: Complete input/provider/validity/effect/feedback chain; limit: Explicit numerical, resource, capacity and timing boundaries; failure: Withdraw affected capability without false completion or hidden truth substitute; recovery: Fresh current context/source/request; no stale replay. Packages: P-NAV-008. Untested: DCS stop_action/release semantics must be observed; source establishes mismatch, not a reproduced stuck display. Do not count a host descriptor stub as native delivery evidence..

### F-NAV-013 — Common ADI approach bars consume obsolete unproduced ILS names

confirmed repository interface gap; priorityP1; severity: The common ADI cannot receive owned localizer/glide-slope movement or visibility through the reviewed repository chain.; confidence: High for the cited source behavior; host effect requires stated qualification. Accountable: chat2.

Trigger: Select manual approach/ADI with a valid native localizer or glide-slope reception.

Expected: Selected manual-recovery display must use the explicit current approach receiver contract, independent LOC and GS validity and documented angular scaling. If these bars are deliberately outside the selected profile, remove the dormant graph rather than leave unexplained legacy channels.

Current: The loaded common ADI constructor binds ILS_HORIZON, ILS_VERT, ILSN_VIS. Repository-wide production Lua/C++ search found only these consumer references. NativeNavigation publishes F22_ILS_LOC/GS with independent *_VALID; Nav_Guidance publishes HUD_ILS_* instead. Neither supplies the legacy combined gate.

Consequence: The common ADI cannot receive owned localizer/glide-slope movement or visibility through the reviewed repository chain.

Evidence/result: Fresh source control-flow and complete current producer/consumer closure; no runtime in residue pass.. Confirmed source contract issue within stated boundary. [adi_page.lua:342](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/MFD_COMMON/adi_page.lua:342>), [adi_page.lua:357](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/Cockpit/Scripts/MFD_COMMON/adi_page.lua:357>), [NativeNavigation.cpp:352](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/EFM/source/NativeNavigation.cpp:352>).

Complete-chain remedy: Decide common ADI approach-bar applicability, migrate each axis to qualified current LOC/GS fields with correct units/sign/full-scale bounds and age, or retire obsolete bars with explicit profile decision. Preserve independently valid axis and no autoland promise.

Retain: Current appearance, stable saved command IDs and qualified owner protocols; preserve unaffected valid capabilities.. Acceptance: normal: Complete input/provider/validity/effect/feedback chain; limit: Explicit numerical, resource, capacity and timing boundaries; failure: Withdraw affected capability without false completion or hidden truth substitute; recovery: Fresh current context/source/request; no stale replay. Packages: P-NAV-008. Untested: An undocumented native producer of these arbitrary legacy names was not observed; runtime diagnostic can challenge that alternative. No claim of automatic landing capability or authenticated F22 ADI artwork..

### F-HOOK-001 — Installed native preview uses superseded control-file path

interface/architecture defect; priorityP2; severity: minor diagnostic usability/qualification identity; confidence: high source/path mismatch, actual runtime commands untested. Accountable: chat2.

Trigger: Matching native validation mission and a controller following current repository path

Expected: Installed diagnostic script and chosen source/tool control contract resolve same explicit current path and sourcehash.

Current: Installed reads hardcoded Documents/Codex/.../work/f22-native-control.txt; repository counterpart reads lfs.writedir Logs/f22-native-control.txt. Both knowncandidate control files absent at audit time. Unused installed mission variable also points missing path, while actual activation is filename suffix.

Consequence: Controller commands can be missed due path mismatch; automatic warmup/pause/screenshot actions remain possible on matchingbasename despite missing old paths.

Evidence/result: Read-only counterpartdiff and pathstat; no hook run. Source review; no runtime qualification. [F22NativePreview.lua:2](<C:/Users/Ethans Desktop 2.0/Saved Games/DCS/Scripts/Hooks/F22NativePreview.lua:2>).

Complete-chain remedy: During authorized execution reconcile one managed installed testhook/control path contract and hash, remove unused path authority assumption; do not overwrite/remove passive recorder or recordings incidentally.

Retain: Dedicated mission gate; Existing recorder/CSV evidence; Native camera/HUD styling and assets. Acceptance: normal: Controller and hook share current path/source identity; limit: Unavailable controls reported, no implicit fallback path authority; failure: Missing control path cannot be called valid test execution; recovery: New managed hook/control state qualified without replaying stale commands. Packages: P-INT-003, P-INT-007. Untested: DCS callback loading; Actual rendered effects.

### F-HOOK-002 — Dogfight diagnostic queue is unbounded and releases depend on paused model time

code defect; priorityP2; severity: moderate diagnostic validity/resource consequence; confidence: high absence of bound/clock rule, actual host paused-frame/effect behavior unqualified. Accountable: chat2.

Trigger: Repeated control requests before deadlines, or explicit global pause with pending delayed action in matching mission

Expected: Diagnostic queue/work/control parsing bounded with explicit pending action timeout/cancel/stop semantics; timed release/hold policy accounts for active/global pause.

Current: queue grows for shot/burst/run actions with no capacity or command-length bound and reverse-scans all entries everyframe. Release/hold deadlines use DCS.getModelTime; initial GLOBALHOLD after2s and pause command can stop modeltime before queued deadline. No onSimulationStop release/queue disposition callback.

Consequence: Unbounded test work/retained actions and delayed diagnostic releases/holds may not complete until modeltime resumes; results cannot be treated as qualified deterministic trigger sequences.

Evidence/result: Static control-flow/state analysis only; no live stuck input or aircraft/native effect observed. Source review; no runtime qualification. [F22DogfightValidation.lua:2](<C:/Users/Ethans Desktop 2.0/Saved Games/DCS/Scripts/Hooks/F22DogfightValidation.lua:2>), [F22DogfightValidation.lua:29](<C:/Users/Ethans Desktop 2.0/Saved Games/DCS/Scripts/Hooks/F22DogfightValidation.lua:29>), [F22DogfightValidation.lua:49](<C:/Users/Ethans Desktop 2.0/Saved Games/DCS/Scripts/Hooks/F22DogfightValidation.lua:49>).

Complete-chain remedy: Remake bounded request-correlated harness with maxqueue/maxcommand/framebudget, pending press/release accounting, explicit pause-clock timeout/cancel and stop/restart recovery; prove actual host pause/command semantics before tests. Preserve recordings and mission compatibility until replacement qualified.

Retain: Controlled mission scope; World truth only in test evidence; Saved command IDs. Acceptance: normal: Every admitted testrequest has completed or explicit failed/canceled disposition; limit: Bounded queue/controlline/callbackwork; failure: Pause/device loss/malformed control cannot silently leave pending testaction; recovery: Restart/teardown/retry does not replay old queue or invent success. Packages: P-INT-002, P-INT-005. Untested: Actual DCS commands during pause; Crossmission native state release guarantees.

### F-REG-001 — Ferry preset references unregistered/unoffered IRST pod identities

interface/architecture defect; priorityP2; severity: moderate preset usability/compatibility; confidence: high for mismatch; actual host symptom unknown. Accountable: chat4.

Trigger: Select supplied preset14: FERRY CONFIG VLO TANK, IRST POD

Expected: Every supplied preset CLSID must resolve to declared store identity admitted on its aircraft station; unsupported optional sensing must remain explicitly unavailable.

Current: Preset requests IRST_SENSOR_Pod at stations4/8; no local registration or offered pylon entry found. ActualF22_IRST is registered and offered onlystation6, also already included in this preset.

Consequence: Preset cannot be reconstructed solely from current declared stores/stations; host may reject/drop unknown stores, actual handling untested.

Evidence/result: REGISTRATION-PROBE actual Lua sink -> preset assignment admission check, only these2assignments fail across 24presets; full production search found oldCLSID only in those preset lines.. Static/declarative mismatch reproduced; no DCS load attempted. [F-22A.lua:637](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/UnitPayloads/F-22A.lua:637>), [IRST Pod.lua:27](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/IRST Pod.lua:27>), [F-22A.lua:454](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22/F-22A.lua:454>).

Complete-chain remedy: Correct only supplied preset metadata to intended declared carriage (validpodstation6 already exists), or label/withdraw this unsupported supplied option. Preserve user mission files and required mission-loadability CLSIDs; do not create a new compatibility owner by default or claim pilot IRST availability from pod registration.

Retain: Existing user mission loadability; Selected-off optional capability gates; Current valid F22_IRST registration; Saved controls and assets. Acceptance: normal: All provided preset assignedIDs admitted on declared stations; limit: Unique station assignment, declared forbidden combinations satisfied, finite geometry/count/mass; failure: Unavailable external equipment explicit rather than fabricated supported delivery; recovery: Reload/rearm does not change selected profile or silently enable sensor. Packages: P-WPN-007. Untested: DCS unknownCLSID handling; Real native pod sensor/detection effects; Actual geometry/mass/drag; MP.

## Independent challenge and residual qualification

Physical reviewer independently challenged the lead reset/standby cases using release-before-reset, opposite history and ADC-only controls. Weapons reviewer independently compiled and challenged all four radar cases, including producer lease versus intervening revalidation. Radar reviewer challenged all three weapons findings with own input matrices and disclosed reuse of inspected native executables/ports. See [REVIEWS.json](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/F22-Audit/Deep-Audit-2026-10-28-1351/REVIEWS.json>) and exact challenge records. No author certified its own full stream.

Actual supported-host callback cadence/order, parameter memory guarantees, allocator/context lifetime and teardown; installed-loaded identity; physiological/native weapon effects; real flight envelope; GPU output; 2D/VR optics/audio; and actual multiplayer clock/authority/replication remain explicit qualification. Protective consumers and conditional triggers are preserved in each finding. This audit produced deeper evidence and implementation instructions. It implemented no fix, deleted no existing test, installed no files and operated no DCS instance.
