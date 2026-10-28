# Chat 4 execution record

Baseline: main at 7513f931a8bf1016a72e8eb184a9c98074786e81. All 164 assigned source/test hashes match. The two pre-existing research-tool edits and Cockpit.zip/EFM.zip are unrelated and preserved. See baseline.json for exact paths/hashes and the 76 assigned test artifacts.

## Proposed release contract (R-WPN-001, F-WPN-001/005)

Native station ingress admits only a table with finite integral count 0..128, an absent or table weapon descriptor, finite integral optional level1..4, and string optional CLSID/name fields. Reject the affected station without discarding independent valid stations. Empty count zero remains valid. Native get/select/launch status is checked independently; a successful void call requests work and never acknowledges an effect.

A missing device, failed selection or failed station service cancels active consent, stops native gun/pickle where possible, invalidates selection/solution/exposure, and retains uncertain issued effects in bounded station quarantine. Restoration cannot restore a held press. A matching armed native station/type/sequence/time record acknowledges a current request; inventory alone only reconciles quarantine. Late matching records may update retired history without restoring program or consent. Rearm/jettison/SAFE/physical generation cancel first.

## Proposed CM disposition (R-WPN-003, F-WPN-003/006)

No qualified production warning-event bridge currently exists. SEMI/AUTO availability and authorization must remain unavailable; a neutral diagnostic command cannot authenticate a warning event. MAN and direct dispense retain saved immutable program/count transactions. Missing/throwing/nonfinite/negative/rewound World clocks revoke consent and report invalid; callback-count time must not authenticate host effects. Recovery requires fresh request.

## Native and donor gates

P-WPN-006 finite ground-gun clock admission must invalidate before trajectory solve, retain Lua rejection and preserve source 2. No threading, gun-burst accuracy, MP or aircraft calibration claim follows from offline checks. D-P-WPN-001 waits for P-INT-008 checked reads and D-P-RAD-001 completed tactical packet admission. Identity known/original time/clock/epoch must travel independently of geometry and receipt. No IFF/coalition truth substitute. P-WPN-004 provides a qualified achieved reply endpoint or an explicit tested no-go; radar integration consumes that decision later.

Shared gate status is owned by Chat2 in ../integration/STATUS.json. This note does not declare those gates satisfied or grant a shared-file/runtime lease. Package closure requires the actual native/effect/pilot results or precise unresolved dispositions.

## Verified source tranche

P-WPN-001 now retires nil/throwing native devices, all-station failures, rejected/throwing selection and rejected/throwing launch requests; it rejects malformed station records while preserving independent stations. Matching native launch records advance current requests; count-only evidence does not. Eleven bounded latest-request history slots admit late correlated outcomes as history/pilot feedback without restoring consent. Two old assigned tests were deleted and eight independent actual-owner requirement tests pass.

P-WPN-003 now reports SEMI/AUTO unavailable and a CM UNAV control label while no qualified production warning-event source exists. Missing/throwing/nonfinite/negative clocks no longer gain callback-count time authority; direct/normal commands are blocked until a qualified clock. Three old tests were deleted and six independent replacement cases pass (including MAN/direct observed count ports, no effect/no completion, draft separation and rollback/recovery). These are simulated host ports, not actual DCS cartridge effects.

All six changed source Lua modules compile with Lua5.1; pinned luacheck adds zero diagnostics (75 legacy diagnostics retained in these files). The legacy long/dense Weapon_System command/update/selection and AG_Stores helpers remain focused coding exceptions; new admission/retirement/history helpers are bounded. Quantitative branch/condition coverage, allocation/GC/callback latency and host scheduling are not measured. Native hooks, IR tones, source2 aim policy, saved commands and HUD geometry were not replaced.

P-WPN-007 capability changes withdraw unsupported legacy GBU32_JDAM bomb release authority while preserving its registration/mission alias. F22_IRST explicitly belongs to selected-off irds. UnitPayloads preset14 repair and optional display labels are a focused unapplied patch until the shared registration lease. The old registration test was deleted and its independent replacement currently exposes those two remaining preset failures.

Current commit integration is requested in commit-request.json. Neither source completion nor a tested parameter wrapper qualifies native/DCS behavior. No install/runtime slot has been acquired or used.
