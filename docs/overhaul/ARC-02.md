# ARC-02 — completed navigation frames

The NAV owner publishes schema 1 through two fixed slots, each containing valid,
true ground-track radians, EFM-clock sample seconds and terminal-arrival state.
`F22_NAV_SNAPSHOT_SEQUENCE` commits last; integers are bounded to 16777215 without
wrap. Publication fills the inactive slot while the previous completed slot stays
readable. Page rendering does not produce navigation data.

The native consumer prebinds ten borrowed parameter handles, checks both API
conversion status and finite values, and retries a changed sequence at most once.
After seeing the new schema it never revives legacy authority on a missing/unknown
schema. Ordinary old-Lua compatibility is possible only before that ownership
latch. Navigation freshness still uses the declared F22_AP_CLOCK epoch and 0.35 s
controller policy, separately from native World-clock receiver/audio leases.

This adds no native object allocation, private offset or recurring allocation.
The SDK-template parameter lookup now returns an initialized empty API when its
host module is absent, resolving MSVC C6387 in the new fixture. This is not a claim
that every legacy EDPARAM call site has been migrated to checked access.

Lua publication tests and the `/W4 /WX /analyze` native fixture cover valid zero,
completed/torn frames, bounded retry, failed conversion, schema withdrawal and
nonfinite sequences. Controller tests independently cover terminal heading hold
with retained BALT. Cross-thread DCS callback scheduling and native flight
qualification remain distinct from these deterministic API fixtures.

Physical cockpit consumers use Physical_Snapshot.lua: one fixed field list (at most64), before/after valid/generation/stamp/clock-kind checks and a permanent owner latch. Invalid new publications never restore legacy truth. References read achieved mass/fuel/trim/gear/supply through that envelope. All19 supported VehicleFaults IDs are registered as disabled mission-author choices in F-22A.lua. Native callback tests qualify their owner behavior; mission-editor UI delivery remains unobserved.

Focused complexity cleanup separates snapshot epoch/payload checks, route point validation and reference formatting. Reference strings are recomputed only after their bounded input cache changes. These extractions preserve existing owner APIs and fail-closed behavior; the actual consumer/mission/native fixtures remain the behavior checks. This does not declare the retained large HUD/UFC/legacy callback functions compliant.
