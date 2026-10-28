# Radar packet cutover, implementation continuation

All implementation is in the primary DCS-F22 checkout on main. The tested
I-INT-003 two-argument read port is used in radar's owning native adapters;
the shared wrapper, global initialization/cache migration and full P-INT-008
qualification remain with Chat 2. No one-argument getter is added.

## Ground packet (Chat 3 producer and consumers)

Native output schema 1: F22_AG_NATIVE_SEQUENCE is positive even 2..16777214
only when complete; odd means writing. F22_AG_NATIVE_SOURCE_EPOCH is integer
1..16777215. GMT_LAST_TIME is original World-clock producer time; current
output lease is 0.5 seconds. Copying it does not renew any observation time.
Native selected TIME and request sequence/type, original N/U/E metres and
VN/VU/VE m/s, validity/association/memory flags and up to 64 search slots are
protected by the same commit. Type 3/ID 0 remains a fixed terrain result with
no measured object velocity authority. Ambiguous object associations coast
without new designation or sample time. Every used field is finite/typed.

Lua schema 1 control publication uses F22_AG_NATIVE_CONTROL_SEQUENCE, TIME
and EPOCH (echo of the coherent native source epoch). Sequence is odd before
any command/update writes, even only after all fields. Mode, range, antenna,
FAN, SIL/ACTIVE/operating and request active/sequence/point are protected.
Nested press/release commands remain in one transaction. Invalid clocks or
operation/write exceptions complete an unavailable packet; designation/live/track
authority is withdrawn before the even commit. A native publication may not
commit a new heartbeat over a failed protected payload write. Native admission and later sensing both
enforce the original 0.5-second source lease. MAIN_POWER/HUD_MODE/RADAR_PWR
remain independently checked context gates.

Source-epoch changes cancel pending/selected requests, designation and mover
history, reset RF-credit baselines, and require new consent. Source rollback
or a greater-than-10-second source-clock discontinuity retires native pending,
selected, ranging and filter history together; this threshold retains the
existing game source-clock policy. Retained image pixels keep their own sample
reference and do not authenticate a new tracked object.

## Tactical packet (Chat 3 provider, Chat 4 consumer-region review)

Schema 1 adds F22_RADAR_TACTICAL_SCHEMA and SOURCE_EPOCH (native AESA source
generation). SEQUENCE becomes odd/even 2..16777214 around every used slot,
packet TIME, metadata and identity fields. TIME is World seconds with 0.25 s
consumer lease/0.05 s future tolerance. Original observation time is TIME-AGE;
identity-known and IDENTITY_TIME remain independent. No report, copy or geometry
update renews identity. Native transmission caps 32 rows from 64 slots.

Every reader captures sequence and source/context epochs before payload and
rechecks them last. It accepts complete old/new or unavailable, never a mixed
tuple. Fusion must retire only the radar batch and radar association history
on source-epoch change, retaining independent RF/datalink channels. Private
host IDs, coalition and diagnostic weapon truth are not radar identity evidence.
The versioned identity wire is Chat 4 D-P-WPN-001; an older wire that cannot
express independent identity age must retain explicit unknown identity.

## Radar-to-mark seam (Chat 2/4 shared review)

Designation schema 1 carries original TIME, EPOCH, REQUEST and TYPE beside the
existing N/U/E and logical designation sequence, inside the ground control
transaction. A measured object result keeps its original observation time;
receipt or repeated display cannot renew it. MAP/fixed terrain coordinates are
explicit type 3; retained fixed-coordinate policy is separate from a live object.
The mark owner must bracket the source read, retain these qualifiers through
its target publication and clear only affected radar targets on source reset,
invalid live association or stale object time. Weapon/navigation consumers
must preserve the coordinate source metadata and currentness rules. No radar
source edit grants a second mark/weapon/navigation owner.

## Qualification

The independent tests exercise actual readers/writers and modeled field-boundary
preemption. They do not establish observed DCS callback ordering, native lifetime,
actual RF/weapon effects, image/GPU budgets, 2D/VR/multiplayer or aircraft calibration.
Only the integrator may stage/commit shared slices and schedule installation/runtime.
