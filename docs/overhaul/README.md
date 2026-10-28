> Adopted execution baseline: expanded 46-package audit of 28 October 2026. Current implementation and gates: [integration status](integration/STATUS.json). Historical claims retain all 566 dispositions in [the crosswalk](../audit/PRIOR-AUDIT-CROSSWALK.json).

# Expanded F-22 implementation plan

**All 46 packages are planned.** This successor retains43 earlier packages and adds3 focused native/input/provenance packages from8 new findings. Current implemented behavior, offline probe evidence and unqualified actual host/aircraft behavior remain separate.

Repository `C:\Users\Ethans Desktop 2.0\Desktop\DCS MODDING\DCS-F22`, primary checkout `main`, captured HEAD `7513f931a8bf1016a72e8eb184a9c98074786e81` with its recorded dirty/untracked files. [BASELINE.json](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/F22-Audit/Deep-Audit-2026-10-28-1351/BASELINE.json>) and [SOURCE-DRIFT.json](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/F22-Audit/Deep-Audit-2026-10-28-1351/SOURCE-DRIFT.json>) pin per-file hashes; this is a non-atomic review baseline. All 5,515 captured source files and the earlier package's257 manifest entries match the final reconciliation. Source/installed/load/build identities remain separate; sampled DLL/default-input/hook comparisons are in [FINAL-PRESERVATION.json](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/F22-Audit/Deep-Audit-2026-10-28-1351/FINAL-PRESERVATION.json>).

## Execution sequence and ownership

Work in the primary checkout on`main`, re-read current AGENTS/coding rules and recheck affected hashes. Chat 2 is the single contended-file integrator. Separate chats share one filesystem: serialize shared edits/tests/commits and stage only intended work. Preserve saved bindings, HUD styling, recorded audio and unrelated changes. There is no audit-tag reset, worktree, backup mod tree or incidental deployment/DCS termination.

P-INT-002 closes at **HARNESS_READY**, with independently specified common ports/runner, harmless self-checks, explicit known pre-fix failures and complete replacement-owner allocation. Existing tests are **deleted and remade during actual execution** in accountable batches. Domain full-chain replacements and every old-test/research disposition close in P-INT-006; the initial harness does not wait for completed domain fixes.

| New package | Accountable | Delivered behavior and downstream gate |
| --- | --- | --- |
| D-P-FLT-001 |Chat 1 |Fresh-generation keyboard filter state; precedes deeper P-FLT-004 FCS work. |
| D-P-RAD-001 |Chat 3 with Chat 4 consumer-region review |Finite camera admission, complete packet capture, preserved source lease and coherent ground reset; precedes P-RAD-004 integrated native qualification and donor migration. |
| D-P-WPN-001 |Chat 4 |Independent identity provenance through own wire/native/Lua/pilot qualifiers; precedes P-WPN-004 IFF/donor expansion. |

Chat 1 owns physical resources/forces/achieved actuators. Chat 2 owns navigation/cockpit/CNI/alerts, shared native parameter contract and integration. Chat 3 owns radar observations/ground/video admission and radar controls. Chat 4 owns stores/effects, defensive avionics, identity/fusion and native IFF reply-backend feasibility. Chat 4 P-WPN-004 **IFF_PROVIDER_READY** supplies a qualified reply backend or explicit tested unavailable/no-go to Chat 3 P-RAD-007; no reverse prerequisite. Physical P-FLT-002 supplies qualified utility/achieved-door state before P-WPN-002 prediction migration. Native-read P-INT-008 gates affected nav/entry/refuel/lighting adapters; independent direct atmosphere fixes remain separate.

A source-admission package closes its named complete software behavior and accurately records host qualification limits; it never grants a broader DCS/GPU/MP capability label. P-RAD-004 and P-INT-005/006 compose actual supported-host effects and mission qualification. Failed/unknown host feasibility requires a precise unavailable/no-go decision, not fabricated completion or another compatibility owner.

## Dependency order

P-INT-001 â†’ P-INT-003 â†’ P-INT-004 â†’ P-INT-002 â†’ P-INT-007 â†’ P-INT-008 â†’ P-RAD-001 â†’ P-WPN-001 â†’ P-WPN-003 â†’ P-WPN-006 â†’ P-WPN-007 â†’ P-WPN-009 â†’ P-FLT-001 â†’ D-P-FLT-001 â†’ P-RAD-002 â†’ P-RAD-003 â†’ P-FLT-002 â†’ P-NAV-001 â†’ D-P-RAD-001 â†’ P-RAD-004 â†’ P-FLT-003 â†’ P-FLT-005 â†’ P-NAV-002 â†’ P-NAV-003 â†’ P-NAV-005 â†’ P-NAV-006 â†’ P-WPN-002 â†’ D-P-WPN-001 â†’ P-WPN-004 â†’ P-RAD-005 â†’ P-RAD-008 â†’ P-FLT-004 â†’ P-FLT-006 â†’ P-FLT-009 â†’ P-NAV-004 â†’ P-NAV-007 â†’ P-NAV-008 â†’ P-WPN-005 â†’ P-RAD-007 â†’ P-RAD-006 â†’ P-FLT-007 â†’ P-FLT-008 â†’ P-WPN-008 â†’ P-FLT-010 â†’ P-INT-005 â†’ P-INT-006

Every package is assigned once; P-INT-006 requires all other 45 package completion/dispositions. Optional selected-off/no-go decisions are required; optional hardware activation is not automatic.

## Package instructions

### P-INT-001 â€” Adopt fresh baseline, selected profile and shared contracts

Accountable **chat2**; status **planned**; prerequisites: none.

Scope: policy/profile/contracts, not simulation rewrite. Exclusions: No aircraft edits during this audit.; No optional capability activation without separate applicable profile/host decision..

Requirements: R-INT-001, R-INT-007. Findings: retention/qualification. Cleanup: caller migration assessed within tasks.

1. Recheck branch, HEAD, status and all affected hashes against BASELINE and SOURCE-DRIFT; audit deltas before edits.
2. Create approved per-capability table of implementation, selection, evidence, calibration, installed identity and runtime qualification.
3. Agree provider/consumer fields, clocks, validity, generation and cancellation before either side changes. Assign physical owner chat1; nav/cockpit integrator chat2; radar chat3; weapons/fusion chat4.

Acceptance: Every selected capability has exactly one owner and explicit missing/host-limited dispositions.; Unsupported profile/ABI withdraws affected capabilities without healthy defaults.; No historical tag reset, new worktree or unrelated staging.; .

Contracts provided: . Consumed: . Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Only assigned owning regions; chat2 serializes shared files per shared instructions.. Effort/uncertainty: 2-4 focused sessions; host qualification uncertain. Completion: focused commits integrated on main; new requirement-test results and untested limits; source/build/package manifest; updated package status. Verification cases: VS-009, VS-REQ-INT-007.

### P-INT-003 â€” Make build/package provenance and qualification explicit

Accountable **chat2**; status **planned**; prerequisites: P-INT-001.

Scope: build output, package manifests, default controls and loaded identity. Exclusions: No aircraft edits during this audit.; No optional capability activation without separate applicable profile/host decision..

Requirements: R-HOOK-001, R-INT-003, R-INT-005. Findings: F-INT-001, F-INT-002, F-HOOK-001. Cleanup: C-HOOK-001.

1. Change hard-coded DLL output policy before implementation builds so chosen build path cannot silently replace source bin. Build/install remain explicit separate actions.
2. Capture current source-to-installed input differences and preserve saved-user diffs; decide whether default differences are deliberate.
3. Generate source/toolchain/configuration/dependency/build manifest and package hashes; qualify the actual loaded binary, not just a same-named DLL.
4. Install finished slices into normal mod only under later execution authorization/current project policy; never kill DCS or overwrite user assets incidentally.
5. Include all 5installedhooks hashes/counterparts, mission/control/eval paths, source-drift and active/passive authority in runtime qualification manifest; hook identities separate from aircraft DLL hash
6. Capture actual loaded hook/callback identities during later authorized qualification

Acceptance: External build output contains only intended artifacts; production source bin untouched by test build.; DLL/assets/defaults are attributable to source build; DCS module-path/build identity captured after current DLL timestamp.; Bindings/HUD/audio retained and imported actions verified.; .

Contracts provided: . Consumed: . Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Only assigned owning regions; chat2 serializes shared files per shared instructions.. Effort/uncertainty: 2-4 focused sessions; host qualification uncertain. Completion: focused commits integrated on main; new requirement-test results and untested limits; source/build/package manifest; updated package status. Verification cases: VS-004, VS-REQ-HOOK-001, VS-REQ-INT-003.

### P-INT-004 â€” Adopt new audit and retire obsolete handoff authority

Accountable **chat2**; status **planned**; prerequisites: P-INT-001.

Scope: canonical documentation adoption only. Exclusions: No aircraft edits during this audit.; No optional capability activation without separate applicable profile/host decision..

Requirements: R-INT-007. Findings: retention/qualification. Cleanup: C-INT-001.

1. Update docs/audit entry/companions from new audit with old claim dispositions retained.
2. Update docs/overhaul entry/BACKLOG from new DAG and accurately distinguish planned vs existing implemented behavior.
3. Replace docs/handoffs README/shared/fourprompts from this new run, resolving absolute paths and IDs; remove obsolete worktree/tag instructions.
4. Do not duplicate old full research/source catalogue; retain original lineage and access scopes.

Acceptance: Canonical links resolve new baseline and actual assigned packages.; All 566historical records retain fresh disposition and old reference; no historical finding silently dropped.; Four handoffs each standalone and every package has exactly one accountable chat.; .

Contracts provided: . Consumed: . Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Only assigned owning regions; chat2 serializes shared files per shared instructions.. Effort/uncertainty: 2-4 focused sessions; host qualification uncertain. Completion: focused commits integrated on main; new requirement-test results and untested limits; source/build/package manifest; updated package status. Verification cases: VS-REQ-INT-007.

### P-INT-002 â€” Delete and rebuild common test harness; allocate domain remakes

Accountable **chat2**; status **planned**; prerequisites: P-INT-001, P-INT-003.

Scope: Execution-time common runner/fixture/host-contract remake and exact domain test replacement allocation. Domain replacements and actual hook/aircraft qualifications close in their own packages and P-INT-006.. Exclusions: No aircraft edits during this audit.; No optional capability activation without separate applicable profile/host decision..

Requirements: R-HOOK-003, R-HOOK-004, R-INT-002. Findings: F-HOOK-002. Cleanup: C-HOOK-001, C-HOOK-002.

1. Re-inventory the 243 captured test-directory artifacts plus later additions by hash; assign every old test/fixture/runner to one replacement owner; distinguish preserved original research evidence.
2. Derive independent common numerical/state expectations and actual host return/type/clock/lifecycle contracts before using any old assertion.
3. During execution delete/remake the common fixture/runner layer; serialize old namespace consumers while each domain deletes/remakes its own assigned tests. No parallel legacy acceptance authority.
4. Self-test the new harness with independent finite/type/time/generation/capacity/native-status fixtures and representative actual-owner audit reproductions. Record known pre-fix failures explicitly; domain remedies need not pass for harness readiness.
5. Publish per-domain replacement ports, ownership and remaining old-test inventory to P-INT-006. Final reconciliation of all old tests is P-INT-006, not an initial prerequisite to domain implementation.
6. Remake source-controlled bounded diagnostic driver protocols and dry-run host fixtures; prepare exact installed hook retirement manifest. Actual installed hook replacement and callback/DCS qualification belong to P-INT-005/007 and final P-INT-006 under execution authorization.
7. Retain user CSV/log/image/mission recordings and original source measurements as evidence; do not preserve old test assertions as acceptance.

Acceptance: The new common runner/fixtures execute harmlessly from explicit external build output; missing exports, failed reads, nil/wrong types, stale/generation and bounded capacity are represented from real host contracts.; Every captured old test artifact has one replacement owner and an execution disposition; domain remakes may be pending. Common legacy infrastructure is deleted/remade during execution.; Independent harness self-checks pass; representative known aircraft failures are reproducible and recorded as expected pre-fix failures, not silently passed or prerequisites requiring completed remedies.; Domain ports and hook dry-run protocols are ready. A package status of harness_ready grants no aircraft, actual hook, DCS, or final test-retirement qualification.; .

Contracts provided: . Consumed: . Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Only assigned owning regions; chat2 serializes shared files per shared instructions.. Effort/uncertainty: 2-4 focused sessions; host qualification uncertain. Completion: focused common-harness commit on main; new actual-host fixture contract and self-check results; explicit expected pre-fix failure log; exact old-test/research classification and replacement owner map; domain port/hook dry-run specification and P-INT-006 handoff. Verification cases: VS-REQ-HOOK-003, VS-REQ-HOOK-004, VS-REQ-INT-002.

### P-INT-007 â€” Migrate shared loader/control cleanup without breaking saved use

Accountable **chat2**; status **planned**; prerequisites: P-INT-001, P-INT-002.

Scope: shared load paths/default controls and residual duplicate publications; domain algorithms remain with their owners. Exclusions: No aircraft edits during this audit.; No optional capability activation without separate applicable profile/host decision..

Requirements: R-HOOK-002, R-HOOK-004, R-INT-005, R-INT-006. Findings: F-HOOK-001. Cleanup: C-INT-002, C-HOOK-001, C-HOOK-002.

1. Resolve each CLEANUP record through registrations, dynamic loaders, host callbacks, exports, profiles and actual consumers.
2. Migrate obsolete owners/callers then delete obsolete production paths; preserve healthy degraded modes and selected-off supported data.
3. Review current control_cleanup aliases as retained saved-control boundaries; no removal from no-simple-caller evidence alone.
4. Remove stale canonical guidance only after adoption map and new paths are installed; no production or test deletion during this audit.
5. Migrate exact managed diagnostic loader/control path after replacement; classify passive recorder separately; preserve all user recordings and requiredmission callbacks

Acceptance: Exactly one active owner per migrated field; no new default compatibility wrapper.; Saved controls and held/release cancellation pass rebuilt host-contract and DCS import cases.; Retained host-invoked/diagnostic/evidence materials have explicit reason and retirement gate.; .

Contracts provided: . Consumed: . Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Only assigned owning regions; chat2 serializes shared files per shared instructions.. Effort/uncertainty: 2-4 focused sessions; host qualification uncertain. Completion: focused commits integrated on main; new requirement-test results and untested limits; source/build/package manifest; updated package status. Verification cases: VS-004, VS-REQ-HOOK-002, VS-REQ-HOOK-004, VS-REQ-INT-006.

### P-INT-008 â€” Qualify and migrate shared native parameter read/readiness contract

Accountable **chat2**; status **planned**; prerequisites: P-INT-001, P-INT-002.

Scope: Two shared runtime parameter wrapper headers and affected actual caller regions; no SDK ABI change. Exclusions: No mass rewrite of externally supplied SDK declarations; No blanket zero-value rejection.

Requirements: R-INT-008. Findings: F-INT-003. Cleanup: caller migration assessed within tasks.

1. Agree checked resolve/read return domains with all four owners before caller changes.
2. During execution delete/remake old native host mocks/tests independently; inject missingexports, conversionfalse, validzero and lifecycle epoch changes through actual wrapper.
3. Migrate producers/consumers to retain per-read validity; remove unchecked obsolete contract once callers moved.
4. Prove readiness/handle invalidation on restart/teardown and no exceptions escape host callbacks under tested guards.

Acceptance: normal: Typed success/validzero preserved; limit: No unsupported/nonfinite value admitted to affected fields; failure: Absent module/export/failedread yields unavailable without unchecked call; recovery: Only current qualified context/epoch restores authority; .

Contracts provided: I-INT-003. Consumed: native DCS parameter API. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Only assigned owning regions; chat2 serializes shared files per shared instructions.. Effort/uncertainty: 2-4focused sessions plus unmeasured host lifetime; caller breadth uncertain. Completion: all caller references migrated; new tests detect pre-fix failure; matched source/build results; focused main commits and open host limits. Verification cases: VS-001.

### P-RAD-001 â€” Remove obsolete enclosing scan and retired measurement paths

Accountable **chat3**; status **planned**; prerequisites: P-INT-001, P-INT-002.

Scope: Radar_Computer scan_plan/inside/update; Radar_System scan/support fields; AESA_Control publish; PMFD radar_format scan status via chat2; Engagement uncovered consumer via chat4. Exclusions: No audit implementation/install; No invented F22 parameters; No duplicate simulation owner.

Requirements: R-RAD-001, R-RAD-011, R-RAD-020. Findings: F-RAD-001, F-RAD-007. Cleanup: C-RAD-001, C-RAD-002.

1. Before edits recheck main HEAD/status/hashes; serialize contended edits/tests/commits via chat2.
2. Delete and remake assigned existing tests from independent requirements/host contracts, not old answers.
3. Agree actual task/report interface before edits.
4. Make C++ sensed source 2 reports authoritative; retain finite/age/generation and cue provenance.
5. Migrate scan/support warnings to completed task/deadline/age, retire second enclosure.
6. Prove then remove F22G/noise decoder/overlay and obsolete fixtures.

Acceptance: Current source 2 hits at 0deg and50deg both admitted when actual search half60deg.; Stale/torn/out-of-physical-FOV/ambiguous sources remain invalid.; No support degradation solely from an enclosure C++ never used.; No old production noise caller after migration; saved IDs unchanged.; .

Contracts provided: . Consumed: . Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Only assigned owning regions; chat2 serializes shared files per shared instructions.. Effort/uncertainty: medium / moderate uncertainty. Completion: Requirement links/new test results/uncovered decisions; Focused main commit plus source/build/package hashes; Actual runtime qualification or precise remaining limits. Verification cases: VS-005, VS-REQ-RAD-011, VS-REQ-RAD-020.

### P-WPN-001 â€” Close release/station failure transactions

Accountable **chat4**; status **planned**; prerequisites: P-INT-001, P-INT-002.

Scope: Weapon_System/AG_Stores/capability ingress/native launch record. Exclusions: No production implementation/deletion/install in this audit.; No undocumented aircraft performance, RF/guidance recipes or optional activation by flag alone..

Requirements: R-WPN-001. Findings: F-WPN-001, F-WPN-005. Cleanup: caller migration assessed within tasks.

1. Reproduce F001 independently in remade harness, define absent/throwing backend transition before selection/ACK.
2. Withdraw authority, retain unresolved effect, normalize all station payload shapes once and keep remaining stations alive.
3. Prove rearm/jettison/cancel/count/native launch causality through real owner/publication.

Acceptance: No Lua exception on device loss pending; no launch replay after recovery.; Wrong-type station is unavailable, not fatal; real valid host shapes unchanged.; Only matching armed native launch completes, delayed count cannot ACK next request.; .

Contracts provided: . Consumed: qualified physical snapshot; radar qualified association/support and source 2 gun motion; shared input/entry/audio leases. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Weapons/EW Lua and named native closure; native radar provider chat3, bay/utility physical authority chat1, shared MFD/UFC/audio dispatch integrator chat2. Serialize shared NativeSidewinder/RAPTOR regions.. Effort/uncertainty: 1-3 focused implementation sessions each; native/runtime and optional-host feasibility uncertain. Completion: focused main commits and drift manifest; independently remade tests/fixtures result ledger; actual native/DCS effect qualification where required; retained behavior and unresolved limits. Verification cases: VS-007.

### P-WPN-003 â€” Finish CM event-to-effect and clock readiness

Accountable **chat4**; status **planned**; prerequisites: P-INT-001, P-INT-002.

Scope: EW source event interface, consent engine and DEF status. Exclusions: No production implementation/deletion/install in this audit.; No undocumented aircraft performance, RF/guidance recipes or optional activation by flag alone..

Requirements: R-WPN-003. Findings: F-WPN-003, F-WPN-006. Cleanup: caller migration assessed within tasks.

1. Resolve declared abstract game warning event/selection policy without real response recipes.
2. Connect qualified event IDs/time/generation to SEMI/AUTO, or show unavailable until source present.
3. Remove false missing-clock readiness and qualify MAN/direct timing/cancellation/depletion/readback.

Acceptance: Normal warning/event chain demonstrably reaches observed native cartridge count effect.; One-event SEMI and explicit AUTO authorization cannot replay stale/duplicate events.; No AUTO_AVAILABLE without event source/qualified clock; draft/direct behavior retained.; .

Contracts provided: . Consumed: qualified physical snapshot; radar qualified association/support and source 2 gun motion; shared input/entry/audio leases. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Weapons/EW Lua and named native closure; native radar provider chat3, bay/utility physical authority chat1, shared MFD/UFC/audio dispatch integrator chat2. Serialize shared NativeSidewinder/RAPTOR regions.. Effort/uncertainty: 1-3 focused implementation sessions each; native/runtime and optional-host feasibility uncertain. Completion: focused main commits and drift manifest; independently remade tests/fixtures result ledger; actual native/DCS effect qualification where required; retained behavior and unresolved limits. Verification cases: VS-008.

### P-WPN-006 â€” Retain and qualify highrate source 2 gun/native lifetime

Accountable **chat4**; status **planned**; prerequisites: P-INT-001, P-INT-002.

Scope: Gun director/trajectory solver; full native payload/passive lifecycle closure. Exclusions: No production implementation/deletion/install in this audit.; No undocumented aircraft performance, RF/guidance recipes or optional activation by flag alone..

Requirements: R-WPN-006, R-WPN-008, D-R-WPN-002. Findings: F-WPN-007, D-WPN-002. Cleanup: caller migration assessed within tasks.

1. Freeze intentional source 2 analogue separate from measured radar and diagnostic missile truth.
2. Remake independent packet/kinematic/forward-projectile oracles preserving120Hz current attitude and same-epoch directions.
3. Establish payload/native callback thread/retirement contracts and prove blocked/late callback reset paths; add coherent snapshot generation where necessary.
4. Qualify actual native gun pose/shell/host burst behavior without claiming production accuracy.
5. Apply D-R-WPN-002 finite clock/age admission to actual native ground solver and preserve existing Lua rejection; broaden relevant native clock/result publication review without duplicating F-INT-003.

Acceptance: No blind removal/damping of requested highrate primary aim.; Fresh qualified association/generation/resource gates source 2; same-epoch packet correction and current frame maintained.; No escaped native callback exception, stale lifetime use or late callback authority under declared tested host contract.; NaN clock cannot yield native VALID1 or nonfinite valid timestamp; finite restoration passes independent shell-contract cases.

Contracts provided: . Consumed: qualified physical snapshot; radar qualified association/support and source 2 gun motion; shared input/entry/audio leases. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Weapons/EW Lua and named native closure; native radar provider chat3, bay/utility physical authority chat1, shared MFD/UFC/audio dispatch integrator chat2. Serialize shared NativeSidewinder/RAPTOR regions.. Effort/uncertainty: 1-3 focused implementation sessions each; native/runtime and optional-host feasibility uncertain. Completion: focused main commits and drift manifest; independently remade tests/fixtures result ledger; actual native/DCS effect qualification where required; retained behavior and unresolved limits. Verification cases: VS-REQ-WPN-006, VS-REQ-WPN-008, DVS-WPN-002.

### P-WPN-007 â€” Resolve equipment/legacy store and AI registration applicability

Accountable **chat4**; status **planned**; prerequisites: P-INT-001, P-INT-002.

Scope: Equipment capability table, legacy bomb alias, optional registration/preset/host scope. Exclusions: No production implementation/deletion/install in this audit.; No undocumented aircraft performance, RF/guidance recipes or optional activation by flag alone..

Requirements: R-REG-001, R-REG-002, R-WPN-007. Findings: F-WPN-004, F-REG-001. Cleanup: C-WPN-003, C-WPN-006.

1. Adopt registration-review results and distinguish player selected capability from AI native sensor/CM/pylons.
2. Withdraw unsupported legacy JDAM operational label and migrate presets/callers to stock qualified store; preserve explicit mission alias disposition.
3. Decide each optional pod/IRDS/HMD/additional weapon separately; require full video/LOS/pose/native-effect feasibility before activation.
4. Annotate or segregate unselected experimental presets; do not silently remove saved missions.
5. Correct preset14 unregistered old IRST_SENSOR_Pod on stations4/8 under registration reviewer migration; valid F22_IRST is station6. Preserve compatibility decision and profile separation.
6. Repair supplied preset14 exact-ID/station mismatch while preserving user missions
7. Catalog all selected-off experimental presets and label availability; preserve Store_Capabilities additional_weapons gates
8. Separate legacyJDAM compatibility from actual supported delivery and native4level class
9. Treat custom missile/IRST performance, multi-stage fuel/scheme precedence and warhead helpers as declared estimates pending host/native validation

Acceptance: Every advertised player store has actual native type and complete supported delivery.; Selected-off optional equipment cannot provide player release authority; AI/MP consequences documented.; HMD/pod/IRDS missing backend remains explicit optional host/evidence blocker.; All 24presets satisfy actual declared station/CLSID/forbidden constraints; Actual native inventory type matches capability/handoff expectations; Optional absent/selectedoff equipment never receives fabricated usable state.

Contracts provided: . Consumed: qualified physical snapshot; radar qualified association/support and source 2 gun motion; shared input/entry/audio leases. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Weapons/EW Lua and named native closure; native radar provider chat3, bay/utility physical authority chat1, shared MFD/UFC/audio dispatch integrator chat2. Serialize shared NativeSidewinder/RAPTOR regions.. Effort/uncertainty: 1-3 focused implementation sessions each; native/runtime and optional-host feasibility uncertain. Completion: focused main commits and drift manifest; independently remade tests/fixtures result ledger; actual native/DCS effect qualification where required; retained behavior and unresolved limits. Verification cases: VS-009, VS-REQ-REG-001, VS-REQ-REG-002.

### P-WPN-009 â€” Qualify residual host effects, registration and source limits

Accountable **chat4**; status **planned**; prerequisites: P-INT-001, P-INT-002.

Scope: Actual host failure/effect/registration and native callback/provider qualification; source/evidence decisions. Completed presentation, registration and RWR/Tactical Lua review is baseline evidence, not deferred mandatory audit work.. Exclusions: No production implementation/deletion/install in this audit.; No undocumented aircraft performance, RF/guidance recipes or optional activation by flag alone..

Requirements: R-REG-003, R-WPN-004, R-WPN-007, R-WPN-008, R-WPN-009. Findings: retention/qualification. Cleanup: caller migration assessed within tasks.

1. Use the completed registration/defensive display/RWR/Tactical_Situation AST review records in COVERAGE and reviews/assurance plus lead display reviews. Recheck only execution-time source drift and touched/new functions; do not repeat or relabel already completed audit coverage as unfinished.
2. Qualify named native default/callback/SDK provider paths with matched host build, status/lifetime/thread and actual effect evidence. If native layout or callback assumptions change, use compiler-aware inventory to supplement the lexical inventory; no claim of exhaustive existing native body or ABI correctness.
3. Execute specifically deferred host/evidence probes from the fresh historical crosswalk and linked requirements. Preserve the existing fresh dispositions and source-access limits; hash equality is identity evidence, not effect/fidelity confirmation.
4. Adopt completed independent registration and defensive display evidence with canonical audit updates; preserve original per-function review and actual native/2D/VR limits.
5. Assign and qualify the actual host or physical owner/effect for each of the eleven legacy failure IDs with Chat 1 physical and Chat 2 integration review; retain host names until actual applicability is resolved.
6. Qualify actual CM charge accounting, gun host identity/geometry and inherited AI sensor metadata separately from owned pilot services.

Acceptance: Completed mandatory current Lua review remains traceable; every touched/new function has substantive updated records and explicit native/runtime limits. Parsing alone does not confer review credit.; Every deferred host/evidence probe has an actual demonstrated result or a precise host/evidence/no-go disposition. No unknown source parameter is promoted to aircraft fact.; Actual failure IDs, host registrations, CM accounting and native callback effects are qualified or explicitly limited; no silent capability deletion.; Each advertised fault has valid source->actual effect->pilot feedback/recovery evidence or explicit unsupported decision; No real-aircraft identity/performance inferred from inherited host sensor strings.

Contracts provided: . Consumed: qualified physical snapshot; radar qualified association/support and source 2 gun motion; shared input/entry/audio leases. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Weapons/EW Lua and named native closure; native radar provider chat3, bay/utility physical authority chat1, shared MFD/UFC/audio dispatch integrator chat2. Serialize shared NativeSidewinder/RAPTOR regions.. Effort/uncertainty: 1-3 focused implementation sessions each; native/runtime and optional-host feasibility uncertain. Completion: focused main commits and drift manifest; independently remade tests/fixtures result ledger; actual native/DCS effect qualification where required; retained behavior and unresolved limits. Verification cases: VS-009, VS-REQ-REG-003, VS-REQ-WPN-004, VS-REQ-WPN-008, VS-REQ-WPN-009.

### P-FLT-001 â€” Repair field-group validity and lifecycle

Accountable **chat1**; status **planned**; prerequisites: P-INT-001, P-INT-002.

Scope: Input provenance and validity; Lifecycle/input. Exclusions: Undisclosed production parameters; incidental install or simulator takeover; radar/fusion native internals.

Requirements: R-FLT-001, R-FLT-013. Findings: F-FLT-001. Cleanup: C-FLT-001.

1. Direct atmosphere/physical callback validity fixes can proceed independently of P-INT-008. Keep the VS-001 failed-read subcase under P-INT-008 separate; do not treat a shared verification specification as a blanket provider dependency.
2. Carry host-source validity through environmental/HUD groups, preserve independent sources
3. Audit/reset retained input filters including currently unreset smoothed_yaw_discrete with independent restart sequence
4. Retire proven unused numerical helpers after call/export gate
5. Use independent standby-pressure challenge: ADC-only fault must preserve independently valid standby; shared pressure invalidity must not publish a fabricated sea-level valid standby. Retain independent valid kinematics and backup oxygen.

Acceptance: normal: Complete request->owner->achieved effect->valid publication->pilot feedback; healthy behavior retained; limit: Finite domains; zero/invalid dt no advance;<=1s/50substeps; no resource creation; atomic ledger; failure: Reject stale/torn/missing/wronggeneration/wrongtype; withdraw affected source; recovery: Qualified source restoration without stale action replay or unrelated resource repair; Currentpressure itselfNaN is separately tested from a sensor-health failure; restore requires qualified actual pressure, not fallback101325 Pa..

Contracts provided: I-FLT-001; I-FLT-002; I-FLT-003. Consumed: Admitted navigation AFCS; Weapon achieved doors/native carriage. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Chat 1 physical modules and physical RAPTOR callback regions; chat2 single integrator serializes shared RAPTOR/Signals/Engine_System/Electrical_System/mainpanel changes; do not stage another chat work. Effort/uncertainty: Medium-large; host/calibration high uncertainty until probes. Completion: commit/hash IDs; new independent requirement-test traceability; actual logs/uncovered decisions; loaded/native identity and calibration limits. Verification cases: VS-001, VS-REQ-FLT-013.

### D-P-FLT-001 â€” Reset all transient input filters at aircraft generation boundaries

Accountable **chat1**; status **planned**; prerequisites: P-INT-001, P-INT-002.

Scope: Legacy RAPTOR yaw/pitch/roll smoother lifecycle and current input/achieved rudder consumers. Exclusions: No aircraft/test/install edits during this audit; no unselected equipment activation or undisclosed aircraft parameter promise..

Requirements: D-R-INT-001. Findings: D-INT-001. Cleanup: caller migration assessed within tasks.

1. Reset smoothed_yaw_discrete with the existing pitch/roll filters in the one common generation reset. Classify every other persistent control history explicitly.
2. Preserve matching keyboard release, opposite request, joystick precedence, saved command IDs and current physical yaw gain.
3. Delete/remake assigned old reset/input tests during execution from independent same-generation equivalence expectations, including actual release-before-reset controls.
4. Qualify cold/hot/air-hot/release/re-slot callback order; no old command/filter state may grant new-generation authority.

Acceptance: Same fresh input/time/motion gives the same achieved rudder after priorleft, priorright, neutral and explicit release histories.; Analogzero and matching/opposing release precedence remain correct; power/sensor/repair paths do not auto-reengage guidance.; No aircraft yaw gain or actual re-slot guarantee claimed from a fixture.; .

Contracts provided: I-DEEP-004. Consumed: I-FLT-001. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Named source/consumer regions only; Chat 2 serializes shared files, tests and commits on main with domain region owner.. Effort/uncertainty: 1-3 focused implementation sessions plus applicable supported-host qualification; scheduling/ABI evidence may remain a precise limitation.. Completion: Focused main commit and source/build/installed manifest; Independently rebuilt normal/limit/failure/recovery evidence and caller migration; Explicit native/DCS scope and remaining limitation; no synthetic schedule presented as observed host behavior. Verification cases: DVS-INT-001.

### P-RAD-002 â€” Finite scalar and explicit cursor cadence contracts

Accountable **chat3**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-RAD-001.

Scope: Radar_System closure/cursor; Radar_Data_Bridge consumer; AG_Radar_Computer slew. Exclusions: No audit implementation/install; No invented F22 parameters; No duplicate simulation owner.

Requirements: R-RAD-002, R-RAD-019. Findings: F-RAD-002. Cleanup: caller migration assessed within tasks.

1. Before edits recheck main HEAD/status/hashes; serialize contended edits/tests/commits via chat2.
2. Delete and remake assigned existing tests from independent requirements/host contracts, not old answers.
3. Validate every input/result before valid closure publication; preserve healthy geometry.
4. Unify STT/selected finite/age policy.
5. Choose full/active-pause input-time policy and bounded actual dt consistent with host callbacks.

Acceptance: NaN/inf/nil/wrong type -> closure valid0; true zero stays0 valid1.; Fresh valid recovery has no stale poison.; 30/60/240Hz, jitter same elapsed policy time -> cursor within 1e-6rad absent clipping.; Power/page/focus/clock loss cancels axes; no delayed motion.; .

Contracts provided: . Consumed: . Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Only assigned owning regions; chat2 serializes shared files per shared instructions.. Effort/uncertainty: small-medium / low uncertainty. Completion: Requirement links/new test results/uncovered decisions; Focused main commit plus source/build/package hashes; Actual runtime qualification or precise remaining limits. Verification cases: VS-006, VS-REQ-RAD-019.

### P-RAD-003 â€” Measured surface association and request handoff

Accountable **chat3**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-RAD-001.

Scope: GroundMovingTargets Measurements/Tracks; NativeGroundSensor reports/selected; AG_Radar_System native_track/update; target handoff consumers via chat4. Exclusions: No audit implementation/install; No invented F22 parameters; No duplicate simulation owner.

Requirements: R-RAD-003, R-RAD-015. Findings: F-RAD-003. Cleanup: caller migration assessed within tasks.

1. Before edits recheck main HEAD/status/hashes; serialize contended edits/tests/commits via chat2.
2. Delete and remake assigned existing tests from independent requirements/host contracts, not old answers.
3. Separate noisy samples, measured association and private host binding.
4. Introduce owned tokens/covariance innovation/ambiguity policy; fixed terrain FTT distinct.
5. Publish coherent source/time/generation/uncertainty, migrate all consumers once.
6. Reset pending reports on power/epoch/clock; preserve request correlation and original coordinate epoch.

Acceptance: Host-ID permutation alone does not renumber measured tracks.; Close/crossing/ambiguous returns coast without perfect identity; impossible jump cannot drag track.; FTT kind3 disclosed, no GMTT zero-speed masquerade.; Lost/duplicate/reordered ack, change pending, repair/power/rewind -> no stale revival.; .

Contracts provided: . Consumed: . Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Only assigned owning regions; chat2 serializes shared files per shared instructions.. Effort/uncertainty: large / moderate uncertainty. Completion: Requirement links/new test results/uncovered decisions; Focused main commit plus source/build/package hashes; Actual runtime qualification or precise remaining limits. Verification cases: VS-REQ-RAD-003, VS-REQ-RAD-015.

### P-FLT-002 â€” Complete finite supply/fuel/hydraulic providers

Accountable **chat1**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-FLT-001.

Scope: Fuel/feed/refueling/mass; Power/APU/SES; Hydraulics/utility demand. Exclusions: Undisclosed production parameters; incidental install or simulator takeover; radar/fusion native internals.

Requirements: R-FLT-004, R-FLT-006, R-FLT-007, D-R-FLT-002, D-R-FLT-003. Findings: F-FLT-006. Cleanup: caller migration assessed within tasks.

1. Reconcile consumer load/energy and normalized SES/startfuel recharge mass boundary
2. Specify mission/essential/utility feeds with chat2/chat4
3. Resolve dated hydraulic EW emergency generator applicability before selected addition
4. Complete servicing/tank observation generation handshake and utility pressure/demand routing
5. Rebuild finite fuel/mass/firstmoment property and64 slot refusal tests from independent inventory equations; retain successful current atomic behavior.
6. Make SES normalizedreserve versus kg/J boundary explicit; harden variablepublic requests or retain documented finite helper precondition; no inferred masscreation claim.

Acceptance: normal: Complete request->owner->achieved effect->valid publication->pilot feedback; healthy behavior retained; limit: Finite domains; zero/invalid dt no advance;<=1s/50substeps; no resource creation; atomic ledger; failure: Reject stale/torn/missing/wronggeneration/wrongtype; withdraw affected source; recovery: Qualified source restoration without stale action replay or unrelated resource repair; 20,000-event sequences and capacity failure preserve resources/moments; actualDCSmass/CG/inertia qualification remains separate..

Contracts provided: I-FLT-001; I-FLT-002; I-FLT-003. Consumed: Admitted navigation AFCS; Weapon achieved doors/native carriage. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Chat 1 physical modules and physical RAPTOR callback regions; chat2 single integrator serializes shared RAPTOR/Signals/Engine_System/Electrical_System/mainpanel changes; do not stage another chat work. Effort/uncertainty: Medium-large; host/calibration high uncertainty until probes. Completion: commit/hash IDs; new independent requirement-test traceability; actual logs/uncovered decisions; loaded/native identity and calibration limits. Verification cases: VS-REQ-FLT-004, VS-REQ-FLT-006, VS-REQ-FLT-007, DVS-FLT-002, DVS-FLT-003.

### P-NAV-001 â€” Qualify cockpit measurements and selected-reference interfaces

Accountable **chat2**; status **planned**; prerequisites: P-FLT-001, P-INT-001, P-INT-002, P-INT-008.

Scope: HUD/ADI altitude/VS, GINS/AFCS contracts; no flight controller retuning. Exclusions: No production calibration from tests; No unsupported host feature promised.

Requirements: R-NAV-001, R-NAV-003, R-NAV-007, R-NAV-013. Findings: F-NAV-001, F-NAV-003, F-NAV-006, F-NAV-010. Cleanup: caller migration assessed within tasks.

1. Before changing or qualifying RAPTOR getParameter consumers, require P-INT-008 checked native-read contract: navigationFrame/entry guidance and refuel/lighting adapters must preserve conversion status. Already safe direct bool-checked readers and independent physical callback work remain separate.
2. During actual execution delete/retire existing tests in this scope and remake them from requirements, independent expectations and actual host contracts. Historical tests are diagnostic only. No test deletion during audit.
3. First: reproduce stale altitude probe; define source/schema/generation/clock/age contract and enumerate all consumers.
4. Agree AFCS heading/attitude mapping with chat1; serialize RAPTOR navigationFrame edits.
5. Migrate HUD/ADI/warning readers and vv/VV alias; preserve explicit RDR fallback/STBY independence.

Acceptance: normal: Selected valid behavior complete through feedback; limit: Explicit finite bounds and age/clock rules; failure: Missing/stale/wrong-type/torn/native failed calls withdraw only affected capability; recovery: Fresh current source/request; no pre-failure replay; .

Contracts provided: . Consumed: . Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Only assigned owning regions; chat2 serializes shared files per shared instructions.. Effort/uncertainty: Medium to high; native runtime feasibility and optics uncertain. Completion: Focused main commit; Requirement/function/test trace; Caller and obsolete-owner removal proof; Runtime qualification or explicit blocker. Verification cases: VS-003, VS-004, VS-REQ-NAV-007, VS-REQ-NAV-013.

### D-P-RAD-001 â€” Repair native finite geometry, packet admission, source leases and ground epochs

Accountable **chat3**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-INT-008.

Scope: GroundVideoView/NativeGroundVideo frame admission; NativeAesaRadar Parameters.controls plus current AESA_Control publisher integration by chat2; NativeGroundSensor pending/selected/range/filter epoch and current Lua consumer guards; Radar_Tactical producer and NativeDatalink local snapshot admission with Chat 4 consumer-region review. Exclusions: No aircraft/test/install edits during this audit; no unselected equipment activation or undisclosed aircraft parameter promise..

Requirements: D-R-RAD-001, D-R-RAD-002, D-R-RAD-003, D-R-RAD-004, D-R-WPN-003. Findings: D-RAD-001, D-RAD-002, D-RAD-003, D-RAD-004, D-WPN-003. Cleanup: caller migration assessed within tasks.

1. Agree finite typed video frame admission, include scan_center/antenna_elevation and every used geometry term; validate derived matrix/projection before host copy. Reject malformed raw mode/expansion before floating-to-integer cast. Keep current captured image/epoch policy when a new frame is invalid; publish accurate unavailable reason.
2. Read finite/even sequence first, copy every control and priority field with status, then reread same sequence/epoch before committing Request. Alternatively publish immutable joined snapshot under a characterized host contract. Preserve producer observation stamp separately from receipt and revoke disabled packets coherently.
3. Give ground acquisition, queues, filter, range and selected state one explicit source-clock/epoch transition; clear or retire all together on rollback/large discontinuity. Propagate reset reason/generation across sampler, native publication, image-reference policy and Lua request/selection consumers. Require fresh consent/current report rather than old delayed outcome.
4. Preserve validated producer stamp in cached Request, retain separate receipt time only for explicit independent liveness, and enforce both source/context age at sensor/model/bridge admission. Preserve pause/clock policy and actual finite stamps; do not subtract unrelated clocks.
5. Preserve the existing correct AESA_Control odd/even producer and bool-checked numeric reader. Move every protected reader field inside the before/after validation interval.
6. Give Radar_Tactical/native transmitter one completed or explicitly in-progress packet contract; migrate every consumer under one schema. No old sequence may authenticate partially written source/position/identity.
7. Use actual writer/reader adversarial field-boundary tests independently, then measure/enforce supported callback scheduling. A modeled interleaving is not an observed DCS race.

Acceptance: NaN/+inf/-inf/wrong-type failure at actual parameter adapter and header cannot produce accepted nonfinite native matrix/projection.; Zero geometry remains accepted and finite; independent units/sign/layout reference unchanged.; Frozen/retained frame and reset/epoch/owner/fault latch transitions remain correct.; Independent actual writer/reader adversarial schedules at every read/write boundary yield complete old/new request or unavailable, never mixed enable/time/geometry.; Odd, changed, stale/future/wrong-type/failed-conversion sequence withdraws; zero enable and zero valid values remain legitimate.; If supported DCS guarantees serialization, document exact callback/thread evidence and still retain correct packet admission.; Rollback at queue/processing/acquisition/selected/ranging phases retires old pending/private histories or publishes explicit unavailable.; Actual Lua future sample remains rejected; explicit subsequent new request/current epoch restores only new target; no replay from old queue when numerical time catches up.; Normal .06/resource delayed report releases once with original stamp; monotone pause does not manufacture reset or new RF credit.; Producer10/copy 10.49/later10.8 is unavailable even if request receipt was recent.; Current source and receipt within leases admit; zero timestamps and same-clock no-work calls remain valid under explicit policy.; Actual host copier/driver phase characterization documents reachability; a serialized guarantee must be evidenced rather than inferred.; Tactical source 88/newposition cannot be sent with priorposition under unchanged old sequence; completeold, completenew or unavailable only.; Producer clock10/copy 10.49/current10.8 cannot acquire another source lease merely by being copied.; Keep current Lua future/stale sample rejection and rollback request cancellation; provider defect does not prove immediate pilot/weapon admission.; .

Contracts provided: I-DEEP-001; I-DEEP-003; I-DEEP-005. Consumed: I-RAD-001; I-RAD-003. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Named source/consumer regions only; Chat 2 serializes shared files, tests and commits on main with domain region owner.. Effort/uncertainty: 1-3 focused implementation sessions plus applicable supported-host qualification; scheduling/ABI evidence may remain a precise limitation.. Completion: Focused main commit and source/build/installed manifest; Independently rebuilt normal/limit/failure/recovery evidence and caller migration; Explicit native/DCS scope and remaining limitation; no synthetic schedule presented as observed host behavior. Verification cases: DVS-RAD-001, DVS-RAD-002, DVS-RAD-003, DVS-RAD-004, DVS-WPN-003.

### P-RAD-004 â€” Qualify current native/radar/image/support chain

Accountable **chat3**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-RAD-001, P-RAD-002, P-RAD-003, P-INT-003, P-INT-008, D-P-RAD-001.

Scope: NativeAesaRadar qualified API/driver/responder/reset; NativeGroundSensor callbacks; NativeGroundVideo/GroundVideoView; Resource/Donor/Focus/Telemetry; RAPTOR scheduling regions via chat2 integrator. Exclusions: No audit implementation/install; No invented F22 parameters; No duplicate simulation owner.

Requirements: R-RAD-004, R-RAD-005, R-RAD-006, R-RAD-007, R-RAD-010, R-RAD-014, R-RAD-016, R-RAD-017, R-RAD-018, D-R-RAD-001, D-R-RAD-002, D-R-RAD-003, D-R-RAD-004, D-R-WPN-003. Findings: F-RAD-005, D-RAD-001, D-RAD-002, D-RAD-003, D-RAD-004, D-WPN-003. Cleanup: C-RAD-003, C-RAD-004, C-RAD-005.

1. Before edits recheck main HEAD/status/hashes; serialize contended edits/tests/commits via chat2.
2. Delete and remake assigned existing tests from independent requirements/host contracts, not old answers.
3. Pin exact source, compiler, host hashes/PE, exports, vtable/context and loaded package.
4. Instrument callback threads/phases/quiescence; failed guards withdraw capability.
5. Prove airborne exported base velocity getter versus virtual38 (ground/gun use38) before changing ABI; mismatch is a question, not proven bug.
6. Qualify one then concurrent missile targets, AA/AG contention, donor, SIL/ACTIVE/FRZ, moving MAP/EXP.
7. Measure dense scene/jammer/default logging/opt-in probe costs; prebind handles/refactor bounded regions only with need.
8. Separate controlled power/cooling/array failure and repair sorties, then VR and multiplayer participants.
9. Agree D-R-WPN-003 single producer commit contract before changing Radar_Tactical; migrate all native/Lua readers under integrator serialization.

Acceptance: No stale authority past0.5s control/producer lease or0.25s physical stall; epoch/destruction withdraw.; Caps64tracks/32pending/128candidates/8returns/16LOS remain bounded and overload observable.; Foreign indicator rejected before typed getter; malformed buffer latched; camera/point/params same frame.; Actual target-specific missile effects evidenced, not ready flags.; Predeclare image registration tolerance<=1pixel or justified geometry tolerance; frozen images retain old sample epoch.; Record p50/p95/p99/max CPU/GPU and allocation costs; budgets based on measured integrated host, not standalone benchmark.; Unchanged old sequence cannot qualify partially written source/geometry tuples, or exact measured enforced host serialization excludes that schedule.

Contracts provided: . Consumed: I-DEEP-001; I-DEEP-003. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Only assigned owning regions; chat2 serializes shared files per shared instructions.. Effort/uncertainty: large / high host uncertainty. Completion: Requirement links/new test results/uncovered decisions; Focused main commit plus source/build/package hashes; Actual runtime qualification or precise remaining limits. Verification cases: VS-REQ-RAD-004, VS-REQ-RAD-005, VS-REQ-RAD-006, VS-REQ-RAD-007, VS-REQ-RAD-010, VS-REQ-RAD-014, VS-REQ-RAD-016, VS-REQ-RAD-017, VS-REQ-RAD-018, DVS-RAD-001, DVS-RAD-002, DVS-RAD-003, DVS-RAD-004, DVS-WPN-003.

### P-FLT-003 â€” Finish engine/FADEC/failure chain

Accountable **chat1**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-FLT-002.

Scope: Engine/start/FADEC. Exclusions: Undisclosed production parameters; incidental install or simulator takeover; radar/fusion native internals.

Requirements: R-FLT-008, D-R-FLT-004. Findings: retention/qualification. Cleanup: C-FLT-002.

1. Retain manual/automatic admitted starter/fuel/ignition behavior
2. Resolve fire isolation/nozzle supply/relight source evidence policy
3. Remove superseded timing fields after caller migration; retain declared estimated limits

Acceptance: normal: Complete request->owner->achieved effect->valid publication->pilot feedback; healthy behavior retained; limit: Finite domains; zero/invalid dt no advance;<=1s/50substeps; no resource creation; atomic ledger; failure: Reject stale/torn/missing/wronggeneration/wrongtype; withdraw affected source; recovery: Qualified source restoration without stale action replay or unrelated resource repair; .

Contracts provided: I-FLT-001; I-FLT-002; I-FLT-003. Consumed: Admitted navigation AFCS; Weapon achieved doors/native carriage. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Chat 1 physical modules and physical RAPTOR callback regions; chat2 single integrator serializes shared RAPTOR/Signals/Engine_System/Electrical_System/mainpanel changes; do not stage another chat work. Effort/uncertainty: Medium-large; host/calibration high uncertainty until probes. Completion: commit/hash IDs; new independent requirement-test traceability; actual logs/uncovered decisions; loaded/native identity and calibration limits. Verification cases: VS-REQ-FLT-008, DVS-FLT-004.

### P-FLT-005 â€” Unify gear/brake/hook achieved state

Accountable **chat1**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-FLT-002.

Scope: Gear/hook configuration; Contact/brakes/thermal. Exclusions: Undisclosed production parameters; incidental install or simulator takeover; radar/fusion native internals.

Requirements: R-FLT-002, R-FLT-011. Findings: F-FLT-002. Cleanup: caller migration assessed within tasks.

1. Define per-leg travel/door/lock/damage contract; migrate legacy lamp producer AND mainpanel consumers
2. Probe suspension damage IDs/native arrestment and slip/deceleration before missing effects
3. Preserve native anti-skid and finite heat/soak/tire/reserve owners

Acceptance: normal: Complete request->owner->achieved effect->valid publication->pilot feedback; healthy behavior retained; limit: Finite domains; zero/invalid dt no advance;<=1s/50substeps; no resource creation; atomic ledger; failure: Reject stale/torn/missing/wronggeneration/wrongtype; withdraw affected source; recovery: Qualified source restoration without stale action replay or unrelated resource repair; .

Contracts provided: I-FLT-001; I-FLT-002; I-FLT-003. Consumed: Admitted navigation AFCS; Weapon achieved doors/native carriage. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Chat 1 physical modules and physical RAPTOR callback regions; chat2 single integrator serializes shared RAPTOR/Signals/Engine_System/Electrical_System/mainpanel changes; do not stage another chat work. Effort/uncertainty: Medium-large; host/calibration high uncertainty until probes. Completion: commit/hash IDs; new independent requirement-test traceability; actual logs/uncovered decisions; loaded/native identity and calibration limits. Verification cases: VS-002, VS-REQ-FLT-011.

### P-NAV-002 â€” Consolidate cockpit owners and retire obsolete paths

Accountable **chat2**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-NAV-001.

Scope: MFD/Avionics page regions, PMFD transport/preferences, retired helpers; no radar/stores algorithm edits. Exclusions: No production calibration from tests; No unsupported host feature promised.

Requirements: R-NAV-002, R-NAV-011. Findings: F-NAV-002, F-NAV-008. Cleanup: C-NAV-001, C-NAV-002, C-NAV-003, C-NAV-004.

1. During actual execution delete/retire existing tests in this scope and remake them from requirements, independent expectations and actual host contracts. Historical tests are diagnostic only. No test deletion during audit.
2. Trace registration/dynamic loaders and saved IDs.
3. Move APU display supply intent to explicit common contract; remove Avionics page writes.
4. Remove dead PMFD regions and retired helpers after gates; keep physical transport/preferences.
5. Measure recurring descriptor allocation at requested6ms before optimization; do not invent performance bound.

Acceptance: normal: Selected valid behavior complete through feedback; limit: Explicit finite bounds and age/clock rules; failure: Missing/stale/wrong-type/torn/native failed calls withdraw only affected capability; recovery: Fresh current source/request; no pre-failure replay; .

Contracts provided: . Consumed: . Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Only assigned owning regions; chat2 serializes shared files per shared instructions.. Effort/uncertainty: Medium to high; native runtime feasibility and optics uncertain. Completion: Focused main commit; Requirement/function/test trace; Caller and obsolete-owner removal proof; Runtime qualification or explicit blocker. Verification cases: VS-004, VS-REQ-NAV-011.

### P-NAV-003 â€” Prove receiver context lifetime and ident feasibility

Accountable **chat2**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-NAV-001, P-INT-008.

Scope: NativeNavigation; shared RAPTOR callbacks serialized with chat1. Exclusions: No production calibration from tests; No unsupported host feature promised.

Requirements: R-NAV-004, R-NAV-006. Findings: F-NAV-004, F-NAV-005. Cleanup: caller migration assessed within tasks.

1. During actual execution delete/retire existing tests in this scope and remake them from requirements, independent expectations and actual host contracts. Historical tests are diagnostic only. No test deletion during audit.
2. Inspect reset/context ordering; actual-adapter contextA/B/null/reused-address fixture.
3. Prove matched allocate/construct/start/release/destroy and no exceptions escaping callback.
4. Probe ident monitor/mute/readback/retune separately from measurement channels; record exact unsupported capability.

Acceptance: normal: Selected valid behavior complete through feedback; limit: Explicit finite bounds and age/clock rules; failure: Missing/stale/wrong-type/torn/native failed calls withdraw only affected capability; recovery: Fresh current source/request; no pre-failure replay; .

Contracts provided: . Consumed: . Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Only assigned owning regions; chat2 serializes shared files per shared instructions.. Effort/uncertainty: Medium to high; native runtime feasibility and optics uncertain. Completion: Focused main commit; Requirement/function/test trace; Caller and obsolete-owner removal proof; Runtime qualification or explicit blocker. Verification cases: VS-REQ-NAV-004, VS-REQ-NAV-006.

### P-NAV-005 â€” Complete alert decisions and bounded audio qualification

Accountable **chat2**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-NAV-001.

Scope: Pilot warnings/fault catalogue and display outputs; physical causes remain chat1. Exclusions: No production calibration from tests; No unsupported host feature promised.

Requirements: R-NAV-009, R-NAV-010, R-NAV-016. Findings: F-NAV-007. Cleanup: caller migration assessed within tasks.

1. During actual execution delete/retire existing tests in this scope and remake them from requirements, independent expectations and actual host contracts. Historical tests are diagnostic only. No test deletion during audit.
2. Choose overspeed provider/envelope with chat1; label unverified thresholds estimates.
3. Decide low-fuel/bingo independently from F-22 evidence.
4. Extend per-cause validity/onset/clear/ACK/recovery; preserve recordings and confirmed delivery.
5. Measure urgent audio latency across actual clip lengths and MWS/RWR contention before choosing budget.
6. Preserve existing11714/F22_BINGO_KG_REQUEST threshold. Consume I-NAV-006 qualified current native cause for lamp/registry/audio; agree provider validity/clock with chat1. Delete/remake alert tests during execution from independent current cause/ACK/hysteresis requirements.
7. R-NAV-016: delete/retire existing terrain tests during execution and remake from independent flat/slope/ridge/obstruction/source-failure expectations. Cover world wind/frame, 0.8sreaction/roll/Gphases, 12kquery cap, cache direction/wind changes<=.2s, clockrollback, ground/power/FCS/airdata loss, onset ties/staggering, live bank and no-escape cue. Preserve advisory-only authority and distinct speech/display clocks.

Acceptance: normal: Selected valid behavior complete through feedback; limit: Explicit finite bounds and age/clock rules; failure: Missing/stale/wrong-type/torn/native failed calls withdraw only affected capability; recovery: Fresh current source/request; no pre-failure replay; .

Contracts provided: . Consumed: I-NAV-006; I-NAV-007. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Only assigned owning regions; chat2 serializes shared files per shared instructions.. Effort/uncertainty: Medium to high; native runtime feasibility and optics uncertain. Completion: Focused main commit; Requirement/function/test trace; Caller and obsolete-owner removal proof; Runtime qualification or explicit blocker. Verification cases: VS-REQ-NAV-009, VS-REQ-NAV-010, VS-REQ-NAV-016.

### P-NAV-006 â€” Resolve navigation depth and mission data decisions

Accountable **chat2**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-NAV-001.

Scope: Navigation_System/GINS/INS/Mission_Data and radio/route consumer contracts. Exclusions: No production calibration from tests; No unsupported host feature promised.

Requirements: R-NAV-007, R-NAV-012. Findings: F-NAV-006. Cleanup: caller migration assessed within tasks.

1. During actual execution delete/retire existing tests in this scope and remake them from requirements, independent expectations and actual host contracts. Historical tests are diagnostic only. No test deletion during audit.
2. Retain independent marks/manualUTC/timing/route sequencing.
3. Decide manual independent fix, altitude update, flyby/overfly, DTC zones/presets/network partitions/cartography by applicability and host feasibility.
4. Implement only selected feasible complete chains; optional HMD/TGP/recovery shared with chat4.
5. Separate calibration datasets from independent validation; sensitivity/convergence checks on estimated alignment/coast.

Acceptance: normal: Selected valid behavior complete through feedback; limit: Explicit finite bounds and age/clock rules; failure: Missing/stale/wrong-type/torn/native failed calls withdraw only affected capability; recovery: Fresh current source/request; no pre-failure replay; .

Contracts provided: . Consumed: . Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Only assigned owning regions; chat2 serializes shared files per shared instructions.. Effort/uncertainty: Medium to high; native runtime feasibility and optics uncertain. Completion: Focused main commit; Requirement/function/test trace; Caller and obsolete-owner removal proof; Runtime qualification or explicit blocker. Verification cases: VS-REQ-NAV-007, VS-REQ-NAV-012.

### P-WPN-002 â€” Unify achieved bay and ballistic supply contract

Accountable **chat4**; status **planned**; prerequisites: P-FLT-002, P-INT-001, P-INT-002, P-WPN-001.

Scope: Ballistic bay forecast consumer and chat1 physical-provider interface. Exclusions: No production implementation/deletion/install in this audit.; No undocumented aircraft performance, RF/guidance recipes or optional activation by flag alone..

Requirements: R-WPN-002, D-R-WPN-002. Findings: F-WPN-002. Cleanup: caller migration assessed within tasks.

1. P-FLT-002 must demonstrate qualified utility supply, current achieved-door feedback, clock/generation and actuator eligibility before forecast/consumer migration. Preserve existing achieved-door reads; this is not a request for a second door integrator. Gear/hook P-FLT-005 is not a bay dependency unless execution moves that provider region there.
2. Agree one physical utility/clock/station envelope with chat1.
3. Migrate raw EFM_ACTUATOR_AVAILABLE forecast to qualified current achieved-state contract.
4. Define variable-dt/pause/failure behavior and eliminate any duplicate physical integration only with chat1 owner migration.

Acceptance: Divergent utility/flight supplies yield prediction matching actual doors or explicit unavailable.; Torn/stale/future frame cannot keep valid release prediction.; Current bay/IR/gun clearance preserved.; .

Contracts provided: . Consumed: qualified physical snapshot; radar qualified association/support and source 2 gun motion; shared input/entry/audio leases. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Weapons/EW Lua and named native closure; native radar provider chat3, bay/utility physical authority chat1, shared MFD/UFC/audio dispatch integrator chat2. Serialize shared NativeSidewinder/RAPTOR regions.. Effort/uncertainty: 1-3 focused implementation sessions each; native/runtime and optional-host feasibility uncertain. Completion: focused main commits and drift manifest; independently remade tests/fixtures result ledger; actual native/DCS effect qualification where required; retained behavior and unresolved limits. Verification cases: VS-REQ-WPN-002, DVS-WPN-002.

### D-P-WPN-001 â€” Preserve identity provenance through the complete donor wire and fusion chain

Accountable **chat4**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-INT-008, D-P-RAD-001.

Scope: Versioned own IFDL identity known/status/time/clock/epoch fields, actual native transport and Lua fusion/pilot age consumers. Exclusions: No aircraft/test/install edits during this audit; no unselected equipment activation or undisclosed aircraft parameter promise..

Requirements: D-R-WPN-001. Findings: D-WPN-001. Cleanup: caller migration assessed within tasks.

1. Define identity-specific original source time or qualified age/clock mapping, known/status and epoch independently of kinematic sample/receipt. Preserve unknown explicitly.
2. Migrate own native report/wire/receive publication and all Lua fusion/identity/pilot qualifiers as one versioned chain; source/report/peer identity remains independent.
3. Withdraw unsupported own packet versions or precisely disclose unknown identity age; do not introduce an unchecked legacy compatibility authority. Preserve independent valid geometry and friendly-protection/conflict semantics.
4. Delete/remake assigned donor/native mocks and tests during execution from independent source-age expectations. Exercise different clock origins, delay/repeat/epoch/reset/contradictory evidence.
5. Qualify actual supported native radio with two participants before MP provenance claims. Baseline unknown IFF remains unknown until the separate provider-ready decision.

Acceptance: Identity unknown orsource10 withgeometry200 cannot become knownidentitytime200.; Fresh independently qualified identity replaces retained evidence once; receipt/geometry updates never renew it.; Invalid/missing/old-version identity provenance affects only identity, with truthful unknown age and existing no-offboard-weapon-authority rule.; Actual two-participant effects and sourceclock mapping are demonstrated or precisely unqualified; no RF/crypto authenticity inferred.; .

Contracts provided: I-DEEP-002. Consumed: I-DEEP-005; I-WPN-007. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Named source/consumer regions only; Chat 2 serializes shared files, tests and commits on main with domain region owner.. Effort/uncertainty: 1-3 focused implementation sessions plus applicable supported-host qualification; scheduling/ABI evidence may remain a precise limitation.. Completion: Focused main commit and source/build/installed manifest; Independently rebuilt normal/limit/failure/recovery evidence and caller migration; Explicit native/DCS scope and remaining limitation; no synthetic schedule presented as observed host behavior. Verification cases: DVS-WPN-001.

### P-WPN-004 â€” Qualify identity/fusion/donor and native terminal

Accountable **chat4**; status **planned**; prerequisites: P-INT-001, P-INT-002, D-P-WPN-001.

Scope: Achieved IFF backend feasibility/unknown decision, own responder, fusion identity/provenance and native datalink terminal. Radar request/display integration closes separately in P-RAD-007.. Exclusions: No production implementation/deletion/install in this audit.; No undocumented aircraft performance, RF/guidance recipes or optional activation by flag alone..

Requirements: R-WPN-004, R-WPN-008, D-R-WPN-001, D-R-WPN-003. Findings: D-WPN-001, D-WPN-003. Cleanup: caller migration assessed within tasks.

1. Chat 4 owns the achieved IFF reply-backend feasibility probe: identify an actual current-host independent interrogation/reply endpoint, request/source/epoch/time correlation, native guard/read status, rejection and destruction ordering. Test the actual matched host interface under execution authorization. If absent/unqualified, publish an explicit no-go/unavailable contract and evidence; never substitute coalition/scene truth or scripted friendly replies.
2. Agree actual IFF unknown/reply provenance contract with chat3; no coalition truth substitute for missing interrogation.
3. Keep simulated own responder explicitly simulated and document selected surviving-resource limitations.
4. Prove donor unknown sample/receipt/epoch, contradictory identity and no weapon authority through native queue and Lua picture.
5. Qualify terminal destruction/re-slot and2client exchange.
6. Publish provider_ready with measured backend evidence or explicit no-go/unknown, exact schema and independent event/lifecycle tests to Chat 3. Close this provider/fusion package without requiring the later radar consumer migration; P-RAD-007 and P-INT-006 close the joined request/reply/indication chain.
7. Require D-P-WPN-001 versioned identity wire/consumer migration before achieved IFF/donor availability claims; consume its result rather than duplicate transport ownership.
8. Coordinate D-R-WPN-003 radar typed commit with Chat 3/Chat 2 integrator; qualify actual callback scheduling or enforce in-progress snapshot rejection.

Acceptance: Bare no-reply unknown, conflicting evidence visible and friendly protection retained.; Unknown donor sample holds position; FOLLOW/cue never grants lock/release.; Actual donor capability limited to tested producer/platform/MP cases.; Provider_ready is demonstrated actual correlated reply behavior or a truthful tested unavailable/no-go interface; no-go is a host limitation, never passed IFF capability. Own responder remains explicitly simulated where applicable. Radar integration is a later consumer gate.; Actual sender original identity time 10 and unknown-100 never become geometry-time 200 known identity at receiver; Independently preempt every radar field boundary and test packet/no packet decision, then qualify actual two-participant native radio paths.

Contracts provided: I-WPN-006; I-WPN-007. Consumed: qualified physical snapshot; radar qualified association/support and source 2 gun motion; shared input/entry/audio leases; I-DEEP-002; I-DEEP-005. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Weapons/EW Lua and named native closure; native radar provider chat3, bay/utility physical authority chat1, shared MFD/UFC/audio dispatch integrator chat2. Serialize shared NativeSidewinder/RAPTOR regions.. Effort/uncertainty: 1-3 focused implementation sessions each; native/runtime and optional-host feasibility uncertain. Completion: focused main commits and drift manifest; independently remade tests/fixtures result ledger; actual native/DCS effect qualification where required; retained behavior and unresolved limits. Verification cases: VS-REQ-WPN-004, VS-REQ-WPN-008, DVS-WPN-001, DVS-WPN-003.

### P-RAD-005 â€” Coherent SAR applicability and host feasibility

Accountable **chat3**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-RAD-004.

Scope: SAR research notes/tools as nonproduction evidence; new bounded host environment/output probes. Exclusions: No audit implementation/install; No invented F22 parameters; No duplicate simulation owner.

Requirements: R-RAD-008, R-RAD-013. Findings: F-RAD-004. Cleanup: caller migration assessed within tasks.

1. Before edits recheck main HEAD/status/hashes; serialize contended edits/tests/commits via chat2.
2. Delete and remake assigned existing tests from independent requirements/host contracts, not old answers.
3. Decide selected addition versus retained DBS approximation.
4. Qualify terrain/depth/object/visibility ABI, thread, output buffer/layout with independent assembly/runtime evidence.
5. Qualify owned texture publication after actual render pass; restore borrowed context, no blocking readback.
6. Declare bounded scatterer/reflectivity/nav-error assumptions and forward-looking ambiguity.

Acceptance: Written go/no-go lists actual usable environment/output contracts, exact profiles, bounds and blockers.; Point-target CPU reference and independent geometry validate formation; no direct known-target pixel drawing.; Missing support leaves coherent SAR unavailable while current useful approximation retained.; .

Contracts provided: . Consumed: . Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Only assigned owning regions; chat2 serializes shared files per shared instructions.. Effort/uncertainty: research / high uncertainty. Completion: Requirement links/new test results/uncovered decisions; Focused main commit plus source/build/package hashes; Actual runtime qualification or precise remaining limits. Verification cases: VS-REQ-RAD-008, VS-REQ-RAD-013.

### P-RAD-008 â€” Bound radar evidence, calibration and selected depth

Accountable **chat3**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-RAD-004.

Scope: AesaRadar Policy/detect/queue/dwell; AesaTrackFilter thresholds; AesaReceiver/native interference; Equipment_Profile via chat2. Exclusions: No audit implementation/install; No invented F22 parameters; No duplicate simulation owner.

Requirements: R-RAD-012, R-RAD-013, R-RAD-017. Findings: F-RAD-008. Cleanup: caller migration assessed within tasks.

1. Before edits recheck main HEAD/status/hashes; serialize contended edits/tests/commits via chat2.
2. Delete and remake assigned existing tests from independent requirements/host contracts, not old answers.
3. Version parameter/evidence ledger separating historical F22,named analogues, estimates.
4. Predefine matched geometry/RCS/LOS/ECM, seed/sensitivity/convergence metrics; reserve independent validation data.
5. Decide CFAR/false-alarm/ambiguity/deception/ground-jammer/LPI depth and complete-chain feasibility.
6. Implement only selected feasible bounded receiver/measurement/quality/consumer behavior.

Acceptance: No production range/resolution/waveform claim from constants.; Independent seed ensembles verify inverse-fourth echo/inverse-square noise trends/uncertainty under declared simplified model.; Unknown/unsupported profile/ECM/capacity explicit, not healthy zero; runtime impact measured.; .

Contracts provided: . Consumed: . Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Only assigned owning regions; chat2 serializes shared files per shared instructions.. Effort/uncertainty: evidence/model / high aircraft uncertainty. Completion: Requirement links/new test results/uncovered decisions; Focused main commit plus source/build/package hashes; Actual runtime qualification or precise remaining limits. Verification cases: VS-REQ-RAD-012, VS-REQ-RAD-013, VS-REQ-RAD-017.

### P-FLT-004 â€” Complete FCS/configuration law authority

Accountable **chat1**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-FLT-002, P-FLT-003, D-P-FLT-001.

Scope: FCS/trim/vectoring. Exclusions: Undisclosed production parameters; incidental install or simulator takeover; radar/fusion native internals.

Requirements: R-FLT-009, D-R-INT-001, D-R-FLT-004. Findings: D-INT-001. Cleanup: C-DEEP-001, C-DEEP-002.

1. Select source-limited approach/refuel/single-engine law
2. Specify mass/config bounds and resettable FCS faults; preserve pitch-priority saturation
3. Consume admitted AFCS controls at one physical surface/vector owner
4. Consume D-P-FLT-001 completed reset/retention contract; do not implement a second input-filter owner.
5. Resolve C-DEEP-001 precise unused-state/local retirement gate; retain all enclosing host callbacks and current gain/achieved-state behavior.
6. Resolve C-DEEP-002 precise unused-state/local retirement gate; retain all enclosing host callbacks and current gain/achieved-state behavior.

Acceptance: normal: Complete request->owner->achieved effect->valid publication->pilot feedback; healthy behavior retained; limit: Finite domains; zero/invalid dt no advance;<=1s/50substeps; no resource creation; atomic ledger; failure: Reject stale/torn/missing/wronggeneration/wrongtype; withdraw affected source; recovery: Qualified source restoration without stale action replay or unrelated resource repair; .

Contracts provided: I-FLT-001; I-FLT-002; I-FLT-003. Consumed: Admitted navigation AFCS; Weapon achieved doors/native carriage; I-DEEP-004. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Chat 1 physical modules and physical RAPTOR callback regions; chat2 single integrator serializes shared RAPTOR/Signals/Engine_System/Electrical_System/mainpanel changes; do not stage another chat work. Effort/uncertainty: Medium-large; host/calibration high uncertainty until probes. Completion: commit/hash IDs; new independent requirement-test traceability; actual logs/uncovered decisions; loaded/native identity and calibration limits. Verification cases: VS-REQ-FLT-009, DVS-INT-001, DVS-FLT-004.

### P-FLT-006 â€” Connect environment/oxygen/canopy native effects

Accountable **chat1**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-FLT-001, P-FLT-002, P-FLT-003.

Scope: Canopy/escape; Oxygen/cabin native effects. Exclusions: Undisclosed production parameters; incidental install or simulator takeover; radar/fusion native internals.

Requirements: R-FLT-003, R-FLT-005, D-R-FLT-001, D-R-FLT-004. Findings: F-FLT-004. Cleanup: C-FLT-004.

1. Probe SDK oxygen/pressurization and canopy seal APIs before implementation
2. Chat 2 adapter under chat1 physical contract; route finite backup/source-loss effects
3. Select oxygen era and label thermal/cabin schedules estimates
4. Resolve D-Q-FLT-001 oxygen publication time meaning before altering depletion boundaries.
5. Declare thermal fuel inlet/massflow enthalpy approximation and measure parameter/dt sensitivity before claiming energy closure.

Acceptance: normal: Complete request->owner->achieved effect->valid publication->pilot feedback; healthy behavior retained; limit: Finite domains; zero/invalid dt no advance;<=1s/50substeps; no resource creation; atomic ledger; failure: Reject stale/torn/missing/wronggeneration/wrongtype; withdraw affected source; recovery: Qualified source restoration without stale action replay or unrelated resource repair; Zero/exact/substep reserve cases obey declared endstate/interval meaning; native physiological effect is explicitly qualified or unavailable..

Contracts provided: I-FLT-001; I-FLT-002; I-FLT-003. Consumed: Admitted navigation AFCS; Weapon achieved doors/native carriage. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Chat 1 physical modules and physical RAPTOR callback regions; chat2 single integrator serializes shared RAPTOR/Signals/Engine_System/Electrical_System/mainpanel changes; do not stage another chat work. Effort/uncertainty: Medium-large; host/calibration high uncertainty until probes. Completion: commit/hash IDs; new independent requirement-test traceability; actual logs/uncovered decisions; loaded/native identity and calibration limits. Verification cases: VS-REQ-FLT-003, VS-REQ-FLT-005, DVS-FLT-001, DVS-FLT-004.

### P-FLT-009 â€” Finish refueling/lighting adapters

Accountable **chat1**; status **planned**; prerequisites: P-FLT-002, P-FLT-005, P-INT-001, P-INT-002, P-INT-008.

Scope: Fuel/feed/refueling/mass; Lighting/refuel adapters. Exclusions: Undisclosed production parameters; incidental install or simulator takeover; radar/fusion native internals.

Requirements: R-FLT-004, R-FLT-014. Findings: F-FLT-003. Cleanup: C-FLT-003.

1. Before changing or qualifying RAPTOR getParameter consumers, require P-INT-008 checked native-read contract: navigationFrame/entry guidance and refuel/lighting adapters must preserve conversion status. Already safe direct bool-checked readers and independent physical callback work remain separate.
2. Chat 1 physical provider, chat2 serializes cockpit/native shared-file adapter changes
3. Connect actual door/ready/contact/disconnect/emitter intensity and retain native controls/audio
4. Retire only proven unused audio wrappers after host gate

Acceptance: normal: Complete request->owner->achieved effect->valid publication->pilot feedback; healthy behavior retained; limit: Finite domains; zero/invalid dt no advance;<=1s/50substeps; no resource creation; atomic ledger; failure: Reject stale/torn/missing/wronggeneration/wrongtype; withdraw affected source; recovery: Qualified source restoration without stale action replay or unrelated resource repair; .

Contracts provided: I-FLT-001; I-FLT-002; I-FLT-003. Consumed: Admitted navigation AFCS; Weapon achieved doors/native carriage. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Chat 1 physical modules and physical RAPTOR callback regions; chat2 single integrator serializes shared RAPTOR/Signals/Engine_System/Electrical_System/mainpanel changes; do not stage another chat work. Effort/uncertainty: Medium-large; host/calibration high uncertainty until probes. Completion: commit/hash IDs; new independent requirement-test traceability; actual logs/uncovered decisions; loaded/native identity and calibration limits. Verification cases: VS-REQ-FLT-004, VS-REQ-FLT-014.

### P-NAV-004 â€” Resolve optional complete clear-voice CNI

Accountable **chat2**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-NAV-003.

Scope: Optional voice CNI only; no secure/hopping/cryptography simulation claim. Exclusions: No production calibration from tests; No unsupported host feature promised.

Requirements: R-NAV-005. Findings: F-NAV-005. Cleanup: caller migration assessed within tasks.

1. During actual execution delete/retire existing tests in this scope and remake them from requirements, independent expectations and actual host contracts. Historical tests are diagnostic only. No test deletion during audit.
2. Keep backend selected off until native lifecycle/tune/RX/TX/PTT/audio proof.
3. If feasible select explicit optional profile and implement requested/accepted/achieved settings, presets, monitor/guard and boundedPTT lease.
4. If blocked give exact host/provenance blocker; retain menu/unavailable behavior.
5. Lost focus/pause/power/restart must releasePTT; no pre-outage transmission replay.

Acceptance: normal: Selected valid behavior complete through feedback; limit: Explicit finite bounds and age/clock rules; failure: Missing/stale/wrong-type/torn/native failed calls withdraw only affected capability; recovery: Fresh current source/request; no pre-failure replay; .

Contracts provided: . Consumed: . Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Only assigned owning regions; chat2 serializes shared files per shared instructions.. Effort/uncertainty: Medium to high; native runtime feasibility and optics uncertain. Completion: Focused main commit; Requirement/function/test trace; Caller and obsolete-owner removal proof; Runtime qualification or explicit blocker. Verification cases: VS-REQ-NAV-005.

### P-NAV-007 â€” Qualify whole cockpit/manual recovery on pinned installation

Accountable **chat2**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-NAV-002, P-NAV-003, P-NAV-005, P-NAV-006.

Scope: Chat 2 accountable whole-mission integration and cockpit qualification; no incidental DCS takeover. Exclusions: No production calibration from tests; No unsupported host feature promised.

Requirements: R-NAV-008, R-NAV-009, R-NAV-016. Findings: F-NAV-009. Cleanup: caller migration assessed within tasks.

1. During actual execution delete/retire existing tests in this scope and remake them from requirements, independent expectations and actual host contracts. Historical tests are diagnostic only. No test deletion during audit.
2. Record source/build/package/loaded identity independently.
3. Nominal coldstart/taxi/takeoff/navigation/received manual approach/landing/shutdown in2D thenVR with exact atmosphere/mass/stores.
4. Separate controlled source/supply/gear/receiver/audio failures and restart/repair cycles.
5. Chat 2 integrates serialized shared regions; each domain owner supplies provider evidence. Multiplayer requires actual participants/authority testing.
6. R-NAV-016: qualify native terrain.GetHeight/isVisible world axes, terrain edits/obstructions/missing service, sensor currentness and bounded worst-case advisory work; compare live HUD cue versus voice timing in controlled2D/VR. Do not claim automaticGCAS.

Acceptance: normal: Selected valid behavior complete through feedback; limit: Explicit finite bounds and age/clock rules; failure: Missing/stale/wrong-type/torn/native failed calls withdraw only affected capability; recovery: Fresh current source/request; no pre-failure replay; .

Contracts provided: . Consumed: . Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Only assigned owning regions; chat2 serializes shared files per shared instructions.. Effort/uncertainty: Medium to high; native runtime feasibility and optics uncertain. Completion: Focused main commit; Requirement/function/test trace; Caller and obsolete-owner removal proof; Runtime qualification or explicit blocker. Verification cases: VS-REQ-NAV-008, VS-REQ-NAV-009, VS-REQ-NAV-016.

### P-NAV-008 â€” Close side-display validity and physical control lifecycle contracts

Accountable **chat2**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-NAV-001, P-NAV-002, P-FLT-001.

Scope: Avionics side indication/input regions, UFD/common ADI consumers, clickable/default contracts; native producer contract adapters only by chat1 coordination. Exclusions: No production calibration from tests; No unsupported host feature promised.

Requirements: R-NAV-013, R-NAV-014, R-NAV-015. Findings: F-NAV-010, F-NAV-011, F-NAV-012, F-NAV-013. Cleanup: C-NAV-004, C-NAV-005.

1. During execution delete/retire existing tests scoped to these paths and remake from R-NAV-013..015 independent expectations, source units/frame tables and actual host contracts. No deletion during audit.
2. Agree native field/schema/generation/stamp/source/reference/power and missing-data policies with chat1; determine exact side-field capability after ADC/GINS/radar loss. No raw host truth fallback.
3. Migrate side readouts to qualified fields and unavailable glyph; preserve current texture/font/position/color unless specific native type or duplicate-node correction requires local change.
4. Define maintained/toggle aliases and explicit releases; wire SMFD up, add lifecycle cancellation, retain stable input IDs and validate real user diff retention.
5. Decide selected common ADI LOC/GS applicability then implement independent current axes with documented units/sign/full-scale, or delete obsolete graph after applicability/caller decision.
6. Remove obsolete side publishers/unused locals and duplicate right G graph only after consumer migration and dynamic-load gates.
7. Run remade requirement/owner-order/edge/failure tests, actual host callback/type tests, then controlled DCS cold/hot/air2D and VR captures with source/build/package/loaded identity. Record runtime blockers explicitly.

Acceptance: normal: One press cycle one action; each valid side field correct selected units/reference, no changed intended appearance; independent manual LOC/GS if selected.; limit: Finite/wrong-type/torn/zero/negative units boundaries, 270/360headingwrap, controller input decode, per-field age lease, masked source stale values, saved IDs.; failure: ADC/GINS/radar/native context/page/focus/power/pause loss withdraws only affected indication/held input. A healthy attitude neighbor cannot imply healthy airspeed.; recovery: Fresh publication and new press after up; no pre-loss replay, independent axes restore, threshold/user settings retention explicit.; .

Contracts provided: Per-field display admission and control edge/release protocol. Consumed: I-NAV-001; I-NAV-005; I-NAV-006 for alert integration; Current native LOC/GS and GINS/ADC snapshots; chat1 qualified native measurement/power providers; I-FLT-001. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Only assigned owning regions; chat2 serializes shared files per shared instructions.. Effort/uncertainty: Medium to high; native runtime feasibility and optics uncertain. Completion: Focused main commit; Requirement/function/test trace; Caller and obsolete-owner removal proof; Runtime qualification or explicit blocker. Verification cases: VS-REQ-NAV-013, VS-REQ-NAV-014, VS-REQ-NAV-015.

### P-WPN-005 â€” Qualify complete IR readiness and audible lifecycle

Accountable **chat4**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-WPN-001, P-WPN-002.

Scope: Selected side-bay seeker/native feedback/HUD/audio. Exclusions: No production implementation/deletion/install in this audit.; No undocumented aircraft performance, RF/guidance recipes or optional activation by flag alone..

Requirements: R-WPN-005. Findings: retention/qualification. Cleanup: caller migration assessed within tasks.

1. Retain caged-before-consent selected-bay preparation, current generation and independent radar-off acquisition.
2. Remake coherent frame/instance/exposure and requested audio loop tests, then runtime qualify exact loaded combined DLL/Lua.
3. Declare mount aperture approximation/LOAL/cooling/target association limits rather than invent health.

Acceptance: No generic pickle for typed IR; actual native lock/ID required.; Power/rearm/station/held release cannot launch old instance.; Tones/HUD reflect qualified fresh feedback and warning priority, actual audio listened in host.; .

Contracts provided: . Consumed: qualified physical snapshot; radar qualified association/support and source 2 gun motion; shared input/entry/audio leases. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Weapons/EW Lua and named native closure; native radar provider chat3, bay/utility physical authority chat1, shared MFD/UFC/audio dispatch integrator chat2. Serialize shared NativeSidewinder/RAPTOR regions.. Effort/uncertainty: 1-3 focused implementation sessions each; native/runtime and optional-host feasibility uncertain. Completion: focused main commits and drift manifest; independently remade tests/fixtures result ledger; actual native/DCS effect qualification where required; retained behavior and unresolved limits. Verification cases: VS-REQ-WPN-005.

### P-RAD-007 â€” Integrate achieved identification at radar seam

Accountable **chat3**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-RAD-001, P-WPN-004.

Scope: Radar_IFF legacy reply/control; AESA_Control observation identity; Radar_System IFF indications; Radar_Tactical identity. Exclusions: No audit implementation/install; No invented F22 parameters; No duplicate simulation owner.

Requirements: R-RAD-009, R-RAD-010, R-RAD-014. Findings: F-RAD-006. Cleanup: caller migration assessed within tasks.

1. Before edits recheck main HEAD/status/hashes; serialize contended edits/tests/commits via chat2.
2. Delete and remake assigned existing tests from independent requirements/host contracts, not old answers.
3. Wait for P-WPN-004 IFF_PROVIDER_READY. Chat 4 owns the achieved backend/transponder/fusion decision; Chat 3 owns radar request/control/reply indication integration. Agree source/time/epoch/request/reply/errors, and consume an explicit no-go as unavailable/unknown.
4. Distinguish request/automatic from achieved reply/unavailability; never use scene coalition.
5. Migrate once and retire unused reply method after caller proof; retain controls and separate fusion identity.

Acceptance: Request unavailable/rejected visible; no invented friend/hostile.; No response unknown, old identity not renewed by new geometry.; Qualified reply correlated with source/request/epoch/time or capability disclosed unavailable.; Full radar request -> achieved reply or explicit unavailable -> valid identity publication -> pilot indication is qualified with Chat 4 signoff. Never reopen a reverse prerequisite requiring P-RAD-007 before the provider decision.; .

Contracts provided: . Consumed: I-WPN-007. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Only assigned owning regions; chat2 serializes shared files per shared instructions.. Effort/uncertainty: medium / external backend feasibility. Completion: Requirement links/new test results/uncovered decisions; Focused main commit plus source/build/package hashes; Actual runtime qualification or precise remaining limits. Verification cases: VS-REQ-RAD-009, VS-REQ-RAD-010, VS-REQ-RAD-014.

### P-RAD-006 â€” Integrate selected leased SAR collection/formation

Accountable **chat3**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-RAD-005.

Scope: new SAR collection/formation modules; AesaRadar surface job lease; NativeGroundVideo texture publication; AG collection/status controls. Exclusions: No audit implementation/install; No invented F22 parameters; No duplicate simulation owner.

Requirements: R-RAD-004, R-RAD-007, R-RAD-008, R-RAD-017. Findings: F-RAD-004. Cleanup: caller migration assessed within tasks.

1. Before edits recheck main HEAD/status/hashes; serialize contended edits/tests/commits via chat2.
2. Delete and remake assigned existing tests from independent requirements/host contracts, not old answers.
3. Freeze collection generation/grid/waveform/reference; only granted illuminations contribute.
4. Bound pulse/processing queues; stream GPU batches, retain last complete image shared by both VR eyes.
5. Cancel incompatible geometry/profile/power/clock/nav state; separate image progress/quality from target authority.
6. One selected imagery owner; retire old selected path only after proven cutover.

Acceptance: Independent bandwidth/aperture/motion error/two-target/forward-ambiguity experiments match declared physics.; Complex GPU-reference SER>=40dB for specified synthetic cases (numerical, not aircraft evidence).; No generation mixing, display-time RF credit or image-derived fire-control authority.; Full footprint/VR measured cost meets P-RAD-004/005 budgets; bounded worst batch.; .

Contracts provided: . Consumed: . Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Only assigned owning regions; chat2 serializes shared files per shared instructions.. Effort/uncertainty: large / high uncertainty; execute only after capability go. Completion: Requirement links/new test results/uncovered decisions; Focused main commit plus source/build/package hashes; Actual runtime qualification or precise remaining limits. Verification cases: VS-REQ-RAD-004, VS-REQ-RAD-007, VS-REQ-RAD-008, VS-REQ-RAD-017.

### P-FLT-007 â€” Reconcile damage/fault/repair outcomes

Accountable **chat1**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-FLT-003, P-FLT-004, P-FLT-005, P-FLT-006.

Scope: Damage/fault/repair. Exclusions: Undisclosed production parameters; incidental install or simulator takeover; radar/fusion native internals.

Requirements: R-FLT-012. Findings: retention/qualification. Cleanup: caller migration assessed within tasks.

1. Map every registered cell/planned fault to physical/native/feedback consequences
2. Distinguish controller reset, repair and resource servicing; no implicit refuel/cooling/start

Acceptance: normal: Complete request->owner->achieved effect->valid publication->pilot feedback; healthy behavior retained; limit: Finite domains; zero/invalid dt no advance;<=1s/50substeps; no resource creation; atomic ledger; failure: Reject stale/torn/missing/wronggeneration/wrongtype; withdraw affected source; recovery: Qualified source restoration without stale action replay or unrelated resource repair; .

Contracts provided: I-FLT-001; I-FLT-002; I-FLT-003. Consumed: Admitted navigation AFCS; Weapon achieved doors/native carriage. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Chat 1 physical modules and physical RAPTOR callback regions; chat2 single integrator serializes shared RAPTOR/Signals/Engine_System/Electrical_System/mainpanel changes; do not stage another chat work. Effort/uncertainty: Medium-large; host/calibration high uncertainty until probes. Completion: commit/hash IDs; new independent requirement-test traceability; actual logs/uncovered decisions; loaded/native identity and calibration limits. Verification cases: VS-002.

### P-FLT-008 â€” Characterize physics and validate airborne envelope

Accountable **chat1**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-FLT-003, P-FLT-004, P-FLT-005.

Scope: Aerodynamics/performance; Frames/air data/inertia. Exclusions: Undisclosed production parameters; incidental install or simulator takeover; radar/fusion native internals.

Requirements: R-FLT-010, R-FLT-015, D-R-FLT-003, D-R-FLT-004. Findings: F-FLT-005. Cleanup: caller migration assessed within tasks.

1. Probe host specific-force/gravity/inertia/ground effect/store drag ownership
2. Verify force/moment/mass identities before tuning
3. Predeclare conditions/tolerances/uncertainty, separate calibration from held-out validation
4. Adopt the six-family coefficient/capacity provenance and sensitivity matrix; use numerical invariants independently from held-out flight evidence.
5. Characterize native force/gravity/inertia/ground effect/store-drag ownership before adding a second contribution.
6. Keep historical high-alpha documentation and add dated current-code correction during canonicaladoption ratherthan inheriting obsolete drag-discontinuity sentence.

Acceptance: normal: Complete request->owner->achieved effect->valid publication->pilot feedback; healthy behavior retained; limit: Finite domains; zero/invalid dt no advance;<=1s/50substeps; no resource creation; atomic ledger; failure: Reject stale/torn/missing/wronggeneration/wrongtype; withdraw affected source; recovery: Qualified source restoration without stale action replay or unrelated resource repair; Current source truth and numerical convergence credited without authenticating F119/FCS gains or whole-aircraft envelope.; Independentmatchedconditiondataanduncertainty, actualsource/loadedidentity and calibration/holdout split retained..

Contracts provided: I-FLT-001; I-FLT-002; I-FLT-003. Consumed: Admitted navigation AFCS; Weapon achieved doors/native carriage. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Chat 1 physical modules and physical RAPTOR callback regions; chat2 single integrator serializes shared RAPTOR/Signals/Engine_System/Electrical_System/mainpanel changes; do not stage another chat work. Effort/uncertainty: Medium-large; host/calibration high uncertainty until probes. Completion: commit/hash IDs; new independent requirement-test traceability; actual logs/uncovered decisions; loaded/native identity and calibration limits. Verification cases: VS-REQ-FLT-010, VS-REQ-FLT-015, DVS-FLT-003, DVS-FLT-004.

### P-WPN-008 â€” Retire obsolete owners and remake assigned tests

Accountable **chat4**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-WPN-001, P-WPN-003, P-WPN-004, P-WPN-005, P-WPN-006, P-WPN-007.

Scope: Dead helper/caller migration, complexity/performance and tests retirement closure. Exclusions: No production implementation/deletion/install in this audit.; No undocumented aircraft performance, RF/guidance recipes or optional activation by flag alone..

Requirements: R-WPN-009. Findings: retention/qualification. Cleanup: C-WPN-001, C-WPN-002, C-WPN-004, C-WPN-005.

1. Inventory exact legacy tests/fixtures/runners by hash with P-INT002; DELETE AND REMAKE every assigned artifact during execution.
2. Remove dead production measured-gun/gravity/exact-ID helpers only after host/dynamic/research caller proof; no default compatibility wrapper.
3. Focused phase extraction and hard count limits for time-window histories; prebind/preallocate measured native recurring scratch where useful.
4. Keep original resources/evidence and classify non-test research separately; no backup source trees.

Acceptance: Each old assigned test deleted/replaced or retired requirement explicitly accounted.; Replacement expectations independent, catch demonstrated failures and critical mutations.; Exactly one live physical/data owner, no dead synthetic authority or unbounded history; measured callback/GC limits reported.; .

Contracts provided: . Consumed: qualified physical snapshot; radar qualified association/support and source 2 gun motion; shared input/entry/audio leases. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Weapons/EW Lua and named native closure; native radar provider chat3, bay/utility physical authority chat1, shared MFD/UFC/audio dispatch integrator chat2. Serialize shared NativeSidewinder/RAPTOR regions.. Effort/uncertainty: 1-3 focused implementation sessions each; native/runtime and optional-host feasibility uncertain. Completion: focused main commits and drift manifest; independently remade tests/fixtures result ledger; actual native/DCS effect qualification where required; retained behavior and unresolved limits. Verification cases: VS-REQ-WPN-009.

### P-FLT-010 â€” Whole-vehicle mission/failure qualification

Accountable **chat1**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-FLT-007, P-FLT-008, P-FLT-009, P-INT-003.

Scope: Input provenance and validity; Gear/hook configuration; Canopy/escape; Fuel/feed/refueling/mass; Oxygen/cabin native effects; Power/APU/SES; Hydraulics/utility demand; Engine/start/FADEC; FCS/trim/vectoring; Aerodynamics/performance; Contact/brakes/thermal; Damage/fault/repair; Lifecycle/input; Lighting/refuel adapters; Frames/air data/inertia. Exclusions: Undisclosed production parameters; incidental install or simulator takeover; radar/fusion native internals.

Requirements: R-FLT-001, R-FLT-002, R-FLT-003, R-FLT-004, R-FLT-005, R-FLT-006, R-FLT-007, R-FLT-008, R-FLT-009, R-FLT-010, R-FLT-011, R-FLT-012, R-FLT-013, R-FLT-014, R-FLT-015. Findings: retention/qualification. Cleanup: caller migration assessed within tasks.

1. During actual execution delete/remake old in-scope tests from independently specified requirements per user steering
2. Run new owner/state-transition/native suites and controlled normal/failure DCS sorties under runtime authorization
3. Record loaded identity, 2D/VR feedback and MP authority only where actually tested
4. Exercise freshspawn/respawn/re-slot with keyboard andanalog histories, explicit keyrelease andidentical newgeneration input; no retainedtransientfilter maycrossgeneration. Parentleadownsreset finding; use independentchallenge as acceptance evidence.

Acceptance: normal: Complete request->owner->achieved effect->valid publication->pilot feedback; healthy behavior retained; limit: Finite domains; zero/invalid dt no advance;<=1s/50substeps; no resource creation; atomic ledger; failure: Reject stale/torn/missing/wronggeneration/wrongtype; withdraw affected source; recovery: Qualified source restoration without stale action replay or unrelated resource repair; Priorleft/priorright keyboardhistory produces same newgeneration ruddertrajectory under samefreshinput; saved bindings preserved. ActualDCSre-slot sequence remains required..

Contracts provided: I-FLT-001; I-FLT-002; I-FLT-003. Consumed: Admitted navigation AFCS; Weapon achieved doors/native carriage. Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Chat 1 physical modules and physical RAPTOR callback regions; chat2 single integrator serializes shared RAPTOR/Signals/Engine_System/Electrical_System/mainpanel changes; do not stage another chat work. Effort/uncertainty: Medium-large; host/calibration high uncertainty until probes. Completion: commit/hash IDs; new independent requirement-test traceability; actual logs/uncovered decisions; loaded/native identity and calibration limits. Verification cases: VS-001, VS-002, VS-REQ-FLT-003, VS-REQ-FLT-004, VS-REQ-FLT-005, VS-REQ-FLT-006, VS-REQ-FLT-007, VS-REQ-FLT-008, VS-REQ-FLT-009, VS-REQ-FLT-010, VS-REQ-FLT-011, VS-REQ-FLT-013, VS-REQ-FLT-014, VS-REQ-FLT-015.

### P-INT-005 â€” Qualify shared lifecycle, performance and multiplayer boundaries

Accountable **chat2**; status **planned**; prerequisites: P-FLT-007, P-INT-002, P-INT-007, P-INT-008, P-NAV-008, P-RAD-004, P-RAD-007, P-WPN-003, P-WPN-004, P-WPN-005, P-WPN-006, D-P-FLT-001, D-P-RAD-001, D-P-WPN-001.

Scope: cross-system orchestration, authority and measurement. Exclusions: No aircraft edits during this audit.; No optional capability activation without separate applicable profile/host decision..

Requirements: R-HOOK-002, R-HOOK-003, R-INT-004, D-R-INT-001, D-R-WPN-001, D-R-WPN-003. Findings: F-HOOK-002, D-INT-001, D-WPN-001. Cleanup: caller migration assessed within tasks.

1. Compose independently rebuilt owner tests through actual providers/consumers; verify reset/power/rearm/refuel/page/dt/teardown combinations.
2. Measure per-thread callback duration, allocations/GC, queue maxima, dropped/capped work and dt behavior under declared hardware/contact load before assigning real-time budgets. Keep current code caps until measured justified replacements.
3. Characterize host/client ownership and replication with at least2participants; no assumption that local publication or native host callback implies replication.
4. Run controlled source-loss while guidance engaged, late acknowledgements across servicing, silent radar with retained tracks, competing warning/seeker audio.
5. Qualify hook callback coexistence/order, modeltime/renderframe and global/activepause behavior, pending action lifecycle and teardown; measure any callback/log/I/O budget before claiming real-time bounds
6. Qualify repeated cold/hot/air-hot/release/re-slot transitions with prior held/released/opposing input state; check actual host callback ordering.
7. Measure exact producer/Lua/native callback scheduling and enforce/document memory publication and reset retirement; distinguish deterministic interleaving probes from observed host schedules.
8. Keep all current F-WPN-007 payload-hook/terminal/MWS lifetime questions; independently trace reset/re-slot/late callback under matched native host.

Acceptance: No stale command revival, duplicate resource integrator or invented measured data.; Report measured p50/p95/p99/max plus measurement conditions; no unsupported hard-real-time claim.; Multiplayer client/host observations match declared authority and loss/rejoin behavior, or release limitation explicitly excludes unsupported cases.; No actual host coherence/lifetime claim based only on readable pointer, sequence equality or SEH.

Contracts provided: . Consumed: . Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Only assigned owning regions; chat2 serializes shared files per shared instructions.. Effort/uncertainty: 2-4 focused sessions; host qualification uncertain. Completion: focused commits integrated on main; new requirement-test results and untested limits; source/build/package manifest; updated package status. Verification cases: VS-007, VS-008, VS-REQ-HOOK-002, VS-REQ-HOOK-003, DVS-INT-001, DVS-WPN-001, DVS-WPN-003.

### P-INT-006 â€” Run staged whole-mission and controlled failure qualification

Accountable **chat2**; status **planned**; prerequisites: P-INT-001, P-INT-002, P-INT-003, P-INT-004, P-INT-005, P-INT-007, P-INT-008, P-FLT-001, P-FLT-002, P-FLT-003, P-FLT-004, P-FLT-005, P-FLT-006, P-FLT-007, P-FLT-008, P-FLT-009, P-FLT-010, P-NAV-001, P-NAV-002, P-NAV-003, P-NAV-004, P-NAV-005, P-NAV-006, P-NAV-007, P-RAD-001, P-RAD-002, P-RAD-003, P-RAD-004, P-RAD-005, P-RAD-006, P-RAD-007, P-RAD-008, P-WPN-001, P-WPN-002, P-WPN-003, P-WPN-004, P-WPN-005, P-WPN-006, P-WPN-007, P-WPN-008, P-WPN-009, P-NAV-008, D-P-FLT-001, D-P-RAD-001, D-P-WPN-001.

Scope: whole aircraft release gates; domain qualifications added as dependencies at synthesis. Exclusions: No aircraft edits during this audit.; No optional capability activation without separate applicable profile/host decision..

Requirements: R-INT-003, R-INT-004, R-INT-005. Findings: retention/qualification. Cleanup: caller migration assessed within tasks.

1. Use VERIFICATION procedures with exact current source/build/package/profile, weather/mass/stores and observer collection.
2. Progress startup/taxi/takeoff/navigation/manual recovery, radar/fusion/weapon effect sorties, then separately controlled failures; no combined destructive failure pileup masking causes.
3. Qualify2DandVR optics/HUD alignment, saved controls, native text formatting, recorded audio mix and optional equipment exclusion.
4. Publish supported envelope, numerical uncertainty, host limitations and unexecuted checks; close only actual demonstrated requirements.
5. Reconcile every captured and subsequently added old test/fixture/runner plus actual managed hook to deleted/remade, retired requirement, or preserved original research evidence. Collect all domain replacements after HARNESS_READY; no old acceptance suite remains authoritative.
6. Require P-INT-004 adoption, P-INT-007 control/loader preservation, and an explicit P-NAV-004 selected-off/no-go or qualified selected implementation disposition. Optional capability implementation is not required when deliberately unselected or host-limited; its decision and truthful feedback are required.

Acceptance: Every core requirement has rebuilt offline evidence plus applicable native/DCS gates; unqualified features accurately limited.; Independent numerical validation data not reused calibration data; predefined tolerances met or uncertainty retained.; All old test files accounted deleted/remade during execution; no false green based on old suite.; .

Contracts provided: . Consumed: . Current versus planned status is explicit in INTERFACES.json.

Edit boundary: Only assigned owning regions; chat2 serializes shared files per shared instructions.. Effort/uncertainty: 2-4 focused sessions; host qualification uncertain. Completion: focused commits integrated on main; new requirement-test results and untested limits; source/build/package manifest; updated package status. Verification cases: VS-004, VS-007, VS-008, VS-REQ-INT-003.

## Verification and release gates

[VERIFICATION-SPEC.json](<C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/F22-Audit/Deep-Audit-2026-10-28-1351/VERIFICATION-SPEC.json>) retains the243-artifact deletion/remake map and adds new requirement cases plus six deep event campaigns. Use independent requirements and actual host contracts, not copied old expected answers. Preserve original research/recordings as evidence rather than a parallel legacy acceptance suite.

New sequences include source/mixed-packet field-boundary interleavings, producer 10/copy 10.49/query 10.8 leases, pending ground state100â†’10 rollback, independent identity 10/unknown with geometry 200, validzero/nonfinite camera/clock fields, shared-pressure versus ADC-only fault, and old keyboard histories across fresh generations. Existing rejecting consumers, bool-checked readers, finite scheduler/resource behavior and source 2 gun policy remain regression obligations.

Flags/IDs/protocol state are exact. Numeric transport tolerances are software tolerances; declare conditions and scale-aware conservation/convergence tolerances before execution. Use the physical six-family provenance matrix for sensitivity and held-out aircraft validation, matched mass/CG/stores/atmosphere. Do not turn a passing analytic/header/property test into F119/FCS/thermal authenticity. Actual callback budgets require measured hardware/load/cadence, not source caps alone.

Qualify normal startup/taxi/takeoff/navigation/manual recovery, radar/fusion/store/gun/CM effects, then separately controlled failure/recovery sorties under exact source/build/package/default-input and loaded identity. Optical/audio/2D/VR and two-participant MP authority/clock/rejoin require actual observation. Installation/runtime follows the later execution request's authorization and one exclusive Chat 2 runtime slot. Never take over or terminate the user's simulator incidentally.
