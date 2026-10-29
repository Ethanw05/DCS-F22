# Radar execution in the primary main checkout

All implementation is in `C:/Users/Ethans Desktop 2.0/Desktop/DCS MODDING/DCS-F22` on `main`. No alternate aircraft checkout is used. The earlier `radar-preparation` artifacts were preliminary review/probe material and are superseded by the current owning sources and evidence here. Build outputs live outside the aircraft checkout in `F22-Build`.

Current priority is recovery after the user's DCS update to **2.9.31.29434**. The failed flight log shows native radar profile rejection (`AESA_REASON=2`), no ready driver and no tracks. At that time the installed DLL and radar Lua predated the recent source work. [host-update/DIAGNOSIS.json](host-update/DIAGNOSIS.json) separates that failure from current source and candidate evidence. Current native compatibility work takes precedence over SAR feature development; IFF backend work remains with Weapons/EW. The offline tests do not demonstrate a recovered in-flight lock.

The native publication repair (`bead9bc`), current air-host adapter (`55224a2`) and ground callback ownership fix (`20374a8`) are now committed on `main`. The Navigation installer subsequently installed a DLL whose embedded source identity matches current native code, including those repairs; [INSTALLATION-OBSERVATION.json](host-update/INSTALLATION-OBSERVATION.json) records the independent file check. Newer radar Lua, other adapter qualification and an actual in-game scan/lock remain open. SAR remains held during this recovery.

The first source-admission/finite-closure/cadence slice is integrated at `d7c614d`. The current continuation is applied to the same primary source, with shared consumer changes supplied as focused review patches for the single integrator. No concurrent staging/commit, installation or simulator operation was performed by Chat3.

## Current software

- Native source2 reports are admitted independently of the obsolete enclosing Lua search window. Original time, finite geometry, age, physical field of view and source generations remain checked. Retired F22G/F22O/F22N readers and the native noise decoder are removed.
- Closing-positive closure rejects malformed inputs and preserves valid zero. Elapsed model time governs cursor motion; loss/reset/focus/page/power cancels held axes. Nonfinite discrete commands are rejected before decoding.
- Ground measurement association uses owned tokens and measured innovation/ambiguity, rather than private host identity. Pending samples, selected/acquisition/range/filter state retire together on source discontinuity. MAP/GMT/SEA provenance prevents old-family search plots crossing modes.
- Native camera capture validates all used geometry and derived tuples. Native controls and report readers bracket complete groups, retain original producer leases and reject failed conversions instead of treating them as valid zero.
- Own tactical publication has an odd/even schema and source epoch. The native reader and Lua checked reader accept a complete snapshot or unavailable. The actual Lua write order is replayed at every protected native reader/writer boundary.
- Ground designation carries original observation time, source epoch/request/type and live/fixed qualification. The checked mark reader and MAP cue use that evidence. The paired mark/stores/weapon/navigation/ballistic consumer patch and native release consumer patch remain explicit shared integration work.
- Expanded terrain projection rejects nonfinite heights and recenter resets expanded cursor axes. SIL/ACTIVE/FRZ collection and source reset are covered by independent workflow cases.

## Evidence and integration

`software/RESULTS.json` records the current independent Lua cases and source stability; `software/LUA-LINT.log` records the pinned Lua5.1 lint delta. Full syntax-tree complexity is in `software/COMPLEXITY.json`, with named retained legacy-controller exceptions in `CODING-EXCEPTIONS.json`; new packet modules stay within CC14. These are numerical/software results, not observed DCS scheduling or aircraft validation.

Native evidence is under `native/`, `ground/`, `model/` and `build/`. The full DLL build succeeded with no radar warnings, but common source changed during compilation; its manifest explicitly records drift and is provisional. A final coherent stable build after shared cutover is required before installation. The independent native targets use `/W4 /WX /analyze`.

`integration-request.json` is the current paired-consumer/registration/commit/runtime handoff. Shared patches are not production application evidence. Chat4's reviewed tactical corrections preserve friendly protection with unknown identity age and permit a fresh source epoch after a small timestamp rollback while retaining independent RF evidence. Original recordings and research bytes are retained. `feasibility/TEST-DISPOSITIONS.json` accounts for all60 assigned artifacts; remaining legacy helper callers are explicitly assigned in `cleanup/integration-request.json`.

## Open delivery gates

| Package | Remaining gate |
| --- | --- |
| P-RAD-001/002 | Final caller retirement and current stable integrated package/host evidence; first slice already committed. |
| P-RAD-003 | Paired shared mark/delivery/native consumer application and current target chain qualification. |
| D-P-RAD-001 | Shared transmit/fusion/release cutover and exact supported-host lifecycle/scheduling evidence. |
| P-RAD-004 | Exact loaded DLL/assets/hooks/input identity, native velocity ABI, real effects/AA-AG contention, image registration and measured CPU/GPU/allocation budgets; exclusive runtime slot. |
| P-RAD-005/006 | Coherent SAR is requested and remains open; actual environment/output/texture contracts and bounded collection/formation/VR budgets are prerequisites. Current MAP/DBS remains active. |
| P-RAD-007 | Chat4 IFF_PROVIDER_READY: qualified backend or independently tested explicit unavailable decision; no coalition substitute and no reverse prerequisite. |
| P-RAD-008 | Versioned estimates/evidence ledger and declared-model checks exist; independent aircraft calibration and integrated host-cost evidence remain open. |

[R-RAD-021 and R-RAD-022](REQUESTED-ADDITIONS.md) record the user's added A/A-in-A/G and coherent SAR requirements. Existing source already schedules background airborne work and ingests its reports in A/G; installed new-target continuity and pilot/tactical presentation still require end-to-end qualification. SAR has no permanent selected-off closure. None of these documents claims DCS/2D/VR/multiplayer qualification or coherent SAR completion.
