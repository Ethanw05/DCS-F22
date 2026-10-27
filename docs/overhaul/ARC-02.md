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
