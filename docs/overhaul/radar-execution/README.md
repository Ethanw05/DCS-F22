# Radar execution — partial source slice, full assignment open

Accountable owner: Chat 3. Work remains in the primary checkout on `main`.
Shared coordination and leases are in `../integration/STATUS.json`. The initial
42 affected-file hashes matched the supplied audit, as did all 60 assigned test
artifacts. Unrelated research tools, archives and other owners' edits are preserved.

## Applied and checked

P-RAD-001 core removes the obsolete Lua scan enclosure and RF-window admission
workaround. Native-owned reports retain original observation time, coherent
generation and finite/age/physical-volume admission, with the explicit retained
source exception. Search requests describe the pilot volume; support age and
association remain separate. The old F22G noise-map reader, 256-slot overlay work,
F22O/F22N telemetry readers and test-only native noise decoder are removed.
Ground rollback cancellation keeps its clock in the active ground owner.

P-RAD-002 core validates every closure component and result, preserves true zero,
and withdraws invalid STT without falling back to a selected track. Cursor motion
uses bounded model-clock elapsed time rather than callback count. Pause creates
no motion; clock/focus/page/power/gap loss cancels held input and requires new
consent. The 0.25 s input-gap limit is a declared game policy.

Six assigned old tests were deleted after an immediate unchanged-hash check and
independently remade against the new shared host ports. Thirteen replacement
tests pass, including routed controls and tactical output, scan boundaries,
finite/zero/invalid recovery, torn/generation failure, STT withdrawal, rollback
and 30/60/240 Hz/jitter/pause/loss cases. Original recordings remain intact.
See `TEST-REMAKE.json`, `SOFTWARE-RESULTS.json` and `SOFTWARE-TEST-RESULTS.txt`.
An independent source review found no remaining actionable new regression.

## Remaining work and gates

| Package | Current disposition |
| --- | --- |
| P-RAD-001 | Core fixed; PMFD SEARCH and Engagement support consumer patch awaits serialized Chat 2/4 review. |
| P-RAD-002 | Core software cases pass; integration, commit, installation and host qualification remain. |
| P-RAD-003 | Native measured-association/request draft prepared; paired Lua packet/epoch and mark/weapon/navigation schemas require agreement. |
| D-P-RAD-001 | Native finite-camera/control-lease and ground-history drafts prepared. Checked-read port is tested, but full cutover and shared tactical packet consumer migration remain open. |
| P-RAD-004 | Depends on the preceding software chains, native lifetime/effect/render/budget evidence and an exclusive runtime slot. |
| P-RAD-005 | Coherent SAR enablement proposed NO-GO until terrain/render/owned-texture/VR budget contracts are qualified; P-RAD-004 prerequisite remains. |
| P-RAD-006 | Dependent/unselected coherent SAR; preserve the active MAP/DBS imagery owner. |
| P-RAD-007 | Wait for Chat 4's P-WPN-004 IFF_PROVIDER_READY; no reverse prerequisite or coalition identity substitute. |
| P-RAD-008 | 37-parameter evidence ledger and independent validation design prepared; host evidence and calibration remain unqualified. |

Native drafts and independent candidate-only probes are under the task workspace
`radar-preparation/native-admission/` and `radar-preparation/surface-association/`.
They are not applied production code or package acceptance. Geometry has 21
candidate checks; the actual candidate control reader has 107; measured ground
probes exercise host-ID permutation, ambiguous crossing/coast, queue rollback,
current-request recovery and bounded work. Candidate native syntax passes MSVC
`/W4 /WX`; that does not establish supported DCS ABI/thread/render/effect behavior.

`integration-request.json` records exact shared consumer patches, excluded donor
field cleanup and a focused commit request. Per the integrator lease Chat 3 has
not staged or committed concurrently. No DLL was built for this applied Lua slice,
installed file changed, hook run or simulator operated. No package is marked
complete, and no 2D/VR/multiplayer/aircraft calibration result is inferred.
