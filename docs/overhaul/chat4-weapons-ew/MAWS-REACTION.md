# MAWS reaction and launch-alert investigation

The RWR launch tone does not suppress MAWS. The actual MWS owner ignores the
RWR alert when deciding optical detection/audio; its active audio lease instead
suppresses the RWR tone. Only a current priority3 pilot voice holds MAWS audio.
It does not remove MAWS detections or visual warnings. Priority1 advisories do
not hold MAWS. Critical-voice expiry restores MAWS without requiring a new shot.

The user's latest log has74 samples with native optical contacts. All74 have
voice priority0, and some reach more than70 native confirmation hits, while
MAWS contact/alert count remains0. That excludes voice priority as the cause for
those recorded contacts. Existing logging does not identify their geometry or
intended target, so it cannot prove they were incoming rather than outgoing.

## Corrected policy

The mod previously required a straight-line projected miss distance below the
larger of300m or3% of current range, in addition to native confirmation and
closing-motion checks. That rejects an approaching missile which is still
lofting or turning toward an intercept. A supplied-native-observation port into
the actual C++ warning owner reproduces the rejection with a missile at20km
forward/3km above, closing700m/s while climbing200m/s. The direct case works;
the lofted case failed before this change and passes after it.

Straight-line miss distance is now diagnostic rather than an alert gate.
Native visibility, more than3 low-angular-rate observations, the additional
0.1s motion baseline, closing speed over25m/s and the existing60s closest-
approach horizon remain. Receding/outgoing and stationary contacts stay quiet.
Invalid observations now retire that source's cached motion history.

This is an estimated mod warning policy, not a validated AN/AAR-56 algorithm.
A confirmed closing missile can now warn even when its present path would
miss or it is aimed elsewhere; the optical detector does not establish intent.
It supplies no hostile identity or weapon-release authority.

## Native contract and diagnostics

Current-host MCP/IDA review confirms `get_spike_world` at424590 returns a
relative missile-to-ownship vector in world axes, encoded azimuth/elevation/
range. `update_existing_contacts` at425420 renews node timestamp96 on a valid
optical update and increments confirmation counter128 under the native angular
rate threshold. These are the existing adapter fields; no layout/profile or
native optical visibility bypass is introduced.

The native candidate publication adds candidate ID, decision, closing speed
(m/s), closest-approach time(s) and projected pass distance(m). The existing
5Hz MWS sample log now includes native admitted/incoming counts and those
values, independently of whether an alert reached the pilot.
Decisions:0 unavailable,1 collecting motion,2 receding/too little closing,
3 outside the existing warning horizon,4 incoming. These are debug fields,
not measured range shown to the pilot.

## Verification and deployment

Four actual Lua-owner cases exercise already-playing RWR launch audio, MAWS
preemption and RWR resumption, critical/advisory voice behavior and diagnostic
logging for a contact rejected before audio. The actual C++ approach owner
checks direct/lofting approach, outgoing and stationary cases, the retained
horizon, stale history, clock rewind and invalid-data retirement. MSVC19.51
`/W4 /WX /analyze`, Lua5.1 compilation and pinned luacheck1.2.0 pass with no new
diagnostics. New approach functions have complexity at most6.

NativeMWS retains its legacy container allocation and orchestration exception;
the policy helpers add no new recurring allocations. Collection remains
bounded by the existing512-contact map admission. The native callback/lifetime
architecture is unchanged; this is not completion of that broader audit.

The installed DLL is updated by compiling NativeMWS and the generated identity,
then linking the other16 exact object files from the previously installed IRST
build. No source is restored or copied into a separate checkout. This preserves
the existing aircraft implementations and excludes unrelated pending native
ground-radar edits. The composite source/old-object identities, exports,
compiler/configuration and matched normal-mod installation are recorded in
MAWS-REACTION-INSTALLATION.json and the external build composition manifest.

Actual incoming-shot timing and loaded identity still require a user flight.
The old log cannot retrospectively establish which classification rejected
each contact; the new log makes that distinction observable.
