# Offboard cueing into owned AESA search

The TSD DONOR view now offers CUE when the current receiver, mission supply and
selected report qualify it. NEXT/PREV/FOLLOW/REJECT keep their existing meanings
and command IDs; CUE uses the already reserved11143. All four displays use the
same bezel contract. Queued and searching indications describe RF task state,
not acquisition, identity or permission to fire.

`Radar_Donor_Link` publishes a schema1, odd/even coherent request with a separate
pilot-request nonce, start time, source, receiver epoch, original sample/receive
times and reported world state. The donor source never writes a local radar
observation or target ID. Current physical mission/electrical data and a250ms
receiver lease are required at the input event. Invalid presses cannot replay
after recovery. Requests last four seconds; selection/reject, receiver loss,
mode/power changes, rewind and physical generation changes retire consent.

Known sample epochs retain their original times and use bounded velocity
prediction. Recent native reports with unknown sample epochs remain explicitly
held: no velocity extrapolation, OBS_TIME=-100/KNOWN0, and a wider20deg search
area. Both require receipt age<=13s; known reports additionally require sample
age<=13s. These limits and the known-report200m+25m/s age growth margin are game
policies, not recovered datalink accuracy or F-22 procedures.

The request becomes a bounded, centre-first RF search grid. One in four
discovery jobs can search the cue area; the pilot's ordinary scan continues,
and the existing priority deadlines/discovery RF-time reservation remain.
Only the cue job's range expands to the reported area, within160nm. A completed
native RF look acknowledges its request cookie; a source position alone cannot
produce SEARCH, a hit, STT, IFF identification or weapon-support authority.
SEARCH does not claim that every uncertainty cell has been covered.

Verification uses the actual donor selection/tactical/radar owners and native
model. Cases include known/unknown epochs, no manufactured local contact,
explicit consent, moving ownship, nonce/epoch/sequence failures, stopped/torn/
malformed publications, expiry/reject, input-time physical failure and recovery,
OFF/ON without an intervening update, and a real cued detection outside the
ordinary scan's elevation/range. Native work/storage limits are unchanged.

The architecture follows Brower (2001), chapter32 §§32.2–32.3: source fusion and
sensor tasking precede fire-control decisions. The installed ED Hornet guide
(24March2024), pp176/179/200/210–212 distinguishes offboard awareness, local
returns, correlated tracks and conflicting identification. Those are design
references; the CUE control, timing and margins above are explicit mod choices.
Broader automatic fusion, ambiguous-target association and in-game network/
missile-support qualification remain separate work. DLL and matching new Lua
modules must be packaged together; offline tests do not establish DCS acceptance.

Current verification: 163/163 script checks, 29/29 native tests, DCS Lua syntax
and scoped Lua lint pass. These exercise source behavior; live DCS donor/network
acceptance remains to be flown. Task telemetry identifies donor search separately
(code4); a superseded passive RF cue is not advertised as the active cue.
