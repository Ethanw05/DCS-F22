# Gun pipper completion handoff — 25 October 2026

Scope: gun solution/display issue only. Crash investigation is handled separately. General cleanup remains staged in the main source tree; this installation did not deploy the MFD cleanup or unrelated cockpit scripts.

## Evidence from the flight

The captured dcs.log contains 3,542 telemetry samples, including 945 samples in GUN mode with STT. The native motion cache is valid in 944 of those and the gun request is valid in 874. Native result times and positive flight times advance throughout the close pursuit, with solver reason zero, while the director is selected in zero samples. Example: model time 137.65 s, range 494.8 m, native result time 137.64 s and TOF 0.598 s.

The prior Lua code cleared native solution validity, dispatched a request, and immediately required the returned sequence to equal the new request sequence. It assumed synchronous completion. A native result delivered after update returned could never pass that check, because the next update invalidated it and advanced the requested sequence again.

A regression test that delivers the native result between Lua updates reproduces the original failure before the fix.

## Correction

- One outstanding request at a time; its input parameters remain unchanged until completion or timeout.
- Native code publishes a separate completion sequence **last**, on both success and failure. Lua consumes the acknowledged generation before issuing the next request.
- Successful results must match target identity and solution sequence and be no more than 0.1 s old. Failure, target changes, stale inputs, rewind and timeout hide the pipper. No gyro/manual alternate aiming code was added.
- Native calculation now uses the native model clock and includes dispatch queue delay in target measurement age. Requests delayed more than 0.15 s, or with excessive total measurement age, are rejected.
- The sampled world gun bore is converted to a body-fixed mounting direction using timestamped attitude history. It is transformed into the current world frame for presentation, so aircraft turns while awaiting a result do not freeze the gun direction in world space. Basis interpolation is continuous through heading/bank wrapping.
- Added request/completion/solution sequences, pending state, display reason, response age and queue delay to the existing logger.

Display reason: 0 = valid; 1 = disabled/missing basic input; 2 = track warmup/range; 3 = geometry/ownship consistency gate; 4 = awaiting or missing accepted response; 6 = outside pipper angular limits. Native solver reason 8 now means invalid/excessive request age. The other native reason values retain their prior meanings.

## Verification

Passed delayed-response regression, synchronous-host regression, one-request invariant, rejected-result invalidation, target switch, response expiry, no-fallback invariant, body/world frame and wrap checks, native queue-delay/acknowledgement tests, telemetry bounds and Lua syntax checks.

A 60-sample, three-second recording from the actual close pursuit is replayed by `tests/test_gun_flight_replay.py`. The corrected handoff produces a visible pipper on 57 of 60 samples; the first three are acquisition warmup. This checks transport and projection using captured native outputs, not live firing accuracy or a newly reproduced DCS session.

Built and installed the new DLL plus Gun_Director.lua and new Gun_Frames.lua; appended diagnostics without replacing other agents' telemetry additions. The installed DLL SHA-256 matches the build. Backup: `fi/work/gun-handoff-install-backup/20261025-031658`.

Next acceptance: launch DCS with the new binary and repeat the close pursuit. Confirm that pending/completion sequences advance, the pipper appears after warmup, and target switching/lock loss clears it. Actual burst accuracy remains unverified.
