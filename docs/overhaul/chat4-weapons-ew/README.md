# Weapons/EW execution status - 28 October 2026

Work is in the primary DCS-F22 checkout on main. The initial164 assigned source/test hashes matched the audit. Unrelated research edits, archives, saved controls, HUD styling and recorded audio were preserved. Initial release/CM/legacy-store source fixes are committed as98e626a. Current native admission, mode-transfer and preset follow-up is queued through the integrator; exact paths/hashes are in commit-request.json. The full assignment remains open.

## Implemented source behavior

- P-WPN-001: nil/throwing native device and rejected/throwing selection/launch retire consent and uncertain effects. Malformed stations do not kill independent stations. Matching native launch records alone acknowledge current release; count-only evidence reconciles quarantine. Bounded latest-request history admits late results without reviving consent. Mode changes consume a held press until UP.
- P-WPN-003: no qualified production warning-event source means SEMI/AUTO unavailable with CM UNAV feedback. Missing/invalid/rewound clocks revoke readiness. MAN/direct saved-program and observed-count behavior is retained; dispatch alone never proves effect.
- P-WPN-007: legacy GBU32_JDAM mission alias remains registered but has no supported bomb-release authority. Supplied ferry preset14 retains only the registered F22_IRST at station6. Optional presets are labelled without changing saved names/IDs.
- P-WPN-006 / I-FLT-001: finite ground-clock admission; checked full physical/wind/TAS group, original spawn-clock metadata and parameter epoch bracket input and result. Gun/funnel, bomb forecasts and TOF clear affected validity and retire histories/cache on loss/context change. The source2 gun algorithm and requested120Hz cadence are retained. This is a source-admission slice, not completion of the whole gun/lifetime package.

## Verification

19 independent Lua methods pass; seven changed Lua files compile with Lua5.1 and add0 pinned luacheck diagnostics.64 native software cases pass (31gun/clock/funnel/context,15bomb,18TOF). Actual pre-edit native bodies reproduce failures through the same independent ports; generated pre-edit compilation units were removed, with no backup source tree retained. Seven of76 assigned old test artifacts were deleted/remade;69 remain quarantined from the new common runner pending their packages.

See lua-results.json, native-flight-evidence.json, native-before-reproduction.json and test-remakes.json. MSVC19.51 /W4/analyze and lizard1.17.31 checks are recorded separately. New helpers have max lexical CCN9; coding-exceptions.json names the pre-existing large native bodies and bounded rationale for integrator review. These are software checks, not aircraft calibration.

## Shared contracts and remaining gates

Chat2 owns integration/commit/build/runtime scheduling. The weapons-flight-group-admission lease covers only the named native consumer regions. WeaponFlightFrame is read-only: full EFM_HUD_VALID versus independent HUD kinematics; finite SI N/U/E velocity/wind; physical generation/stamp, spawn-clock kind1 and parameter epoch. It never equates spawn time to World time or creates measurement provenance.

P-WPN-002/005 await qualified utility/achieved-bay provider evidence. D-P-WPN-001 awaits the completed local tactical packet and checked consumer cutover before independent identity wire migration. P-WPN-004 IFF_PROVIDER_READY is not declared: matched CockpitBase has IffTransceiver query exports, but owned instance/ABI/reply/time/epoch/lifetime are unqualified. No coalition or scripted reply substitutes for that backend.

radar-packet-review.json approves the proposed native tactical transmit region and supplies TACTICAL-CONSUMERS-REVIEWED.patch. The original Lua proposal lost friendly protection when identity time was unknown and rejected a fresh source epoch after a small original-time rollback. The corrected in-memory source admits the fresh epoch while retaining RF. Native wire identity remains a separate D-P-WPN-001 gate.

Remaining P-WPN-006/008/009 limits include unchecked legacy native readers/caches, original frozen-request physical epoch versus World time, whole tactical packet coherence, actual callback/thread/allocator retirement, timing/GC bounds, actual shell/burst/store/CM effects, legacy failure-ID applicability, source2 nominal native qualification and aircraft calibration. Actual DCS/2D/VR/MP, installation and loaded identity are unqualified. No simulator or installation has been operated by this owner. Per-package requirement/finding/cleanup IDs and dispositions are in package-status.json.

## Additional requested fixes

The user added four open items: missing AIM-120 launch modes from the selected F/A-18 reference; aircraft-to-weapon datalink/support symbology; complete LITENING functionality; complete IRST pod functionality. user-requested-fixes.json records full controls/native-effect/display/evidence chains and shared-owner seams. Exact launch-mode/symbol names require reference verification before implementation. Their current unavailable/selected-off state is not final completion of the requested functionality.
