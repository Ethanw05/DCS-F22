# Ground target handoff â€” source and shared review patch

Chat 3 owns the new `AG_Target_Snapshot.lua` reader and new independent
`tests/cases/test_radar_target_handoff.py`. `SHARED.patch` is **unapplied** and
requires Chat2/Chat4 region review. `EXPECTED-SOURCES.json` pins each actual
shared source's bytes and the proposed normalized text. No shared source was
overwritten, staged, committed, installed or executed in DCS by this slice.

The patch covers `AG_Mark_System`, `AG_Stores`, `Weapon_System`,
`Navigation_System` and `AG_Ballistic_Computer`. Tests apply its exact hunks in
memory to the current actual files. They fail on unreviewed source drift; after
the exact proposed source is integrated they execute it directly. This is a
review patch over actual owners, not a retained second codebase or legacy oracle.

## Packet schema 1

Mark owns `F22_AG_TARGET_PACKET_{SCHEMA,SEQUENCE,TIME,EPOCH}`. Weapon owns the
parallel `F22_AG_DELIVERY_TARGET_PACKET_*` group. Each writer publishes odd
sequence before the protected body and even sequence last. Counters are bounded
even integers2..16777214; epochs are positive integers1..16777215. Packet time is
World seconds, separate from observation time. The current declared producer
lease is0.5s, with future/negative/nonfinite time rejected; zero time is valid.

Mark's protected payload includes `HUD_AG_TARGET_VALID`,
`HUD_AG_MARK_NORTH/ALT/EAST`, `F22_AG_TARGET_SOURCE/SEQUENCE`, the provenance
fields below, and `F22_NAV_TARGET_ACK_SEQUENCE/ACK_TARGET_SEQUENCE/RESULT`.
The latter three must be read inside the same before/after interval: an old ACK
cannot authenticate a newer same-coordinate target. A coherent invalid target
may still carry a rejected/terrain-unavailable/power/cancelled NAV result.

Delivery's protected payload includes its `VALID/SOURCE/SEQUENCE/N/U/E`,
`ORIGIN_SOURCE`, and identical provenance suffixes. Delivery `SOURCE` retains
existing routing semantics1live,2station-assigned,3guided-CCIP; `ORIGIN_SOURCE`
independently preserves the original Mark source1HUDLOS,2radar,3NAV. Routing
source2 must not be misread as a measured-radar source.

| Suffix after `F22_AG_TARGET_` or `F22_AG_DELIVERY_TARGET_` | Meaning |
| --- | --- |
| `OBSERVATION_KNOWN` | Exact numeric0/1; radar source2 requires1. HUDLOS/NAV/CCIP coordinate sources remain0. |
| `OBSERVATION_TIME` | Original radar sample in World seconds, never copy/receipt/program time. Unknown/unmeasured is explicitly-100. |
| `OBSERVATION_SEQUENCE` | Original radar designation sequence, distinct from Mark's logical target sequence and station's internal sequence. |
| `SOURCE_EPOCH` | Original radar source epoch. Unmeasured sources explicitly0. |
| `SOURCE_REQUEST` | Original radar request ID; no renewal or implicit replacement. Unmeasured sources0. |
| `SOURCE_TYPE` |1/2live acquired object,3explicit fixed coordinate. Unmeasured sources0. |
| `SOURCE_LIVE` | Exact0/1. Kinds1/2 require current live association; fixed kind3 requires0. |

All positions are world north/up/east metres. Reader limits are abs north/east
<=30,000,000m and altitude[-500,100000]m, finite and correctly typed. The existing
Mark/Stores owners retain their narrower established coordinate limits. The
packet does not create an aircraft-calibrated accuracy or terrain measurement.

## Public reader and copied point

`AG_Target_Snapshot.read(get,world_now)` returns a valid checked Mark point or
nil. `read_delivery` checks the delivery tuple. `read_packet` returns a complete
Mark packet, including a typed NAV error ACK when `.valid=false`; consumers must
never treat an invalid packet as a point. Each reader checks schema/producer
lease, reads all used payload and rereads identical commit/epoch after payload.
Failed getter calls withdraw and set the bounded module diagnostic
`read_failure`; fresh successful reads recover it. No exception is forwarded
from a failed parameter adapter.

Returned `.n/.u/.e` and `.source/.sequence` identify the coordinate and logical
target. `.time/.epoch/.request/.kind/.live/.observation_known` and
`.observation_sequence` preserve original source evidence. `.packet_time` and
`.packet_epoch` independently identify the current publisher; they cannot renew
the original sample. `read_packet` additionally carries `.nav_request`,
`.nav_target_sequence` and `.nav_result` inside the same transaction.

`current(point,get,now)` validates immutable stored/program copies against the
original evidence. Radar kinds1/2 withdraw after5.25s from the original sample,
source epoch change, or loss/change of current association/request/type. Kind3
is explicitly a retained fixed coordinate; its old time is preserved, not
renamed a live object. Source reset withdraws it. Mark cancellation retires the
active mark; an explicitly captured station mission remains its own immutable
fixed-coordinate record until station clear/rearm/source-epoch reset under the
existing Stores ownership. Chat4 must review that distinction in the shared
handoff before integration.

`copy` carries evidence into the immutable program copy.
`publish_metadata` writes only the typed original/unknown evidence fields; it
does not own a packet, clock, target, source lifecycle or physical authority.
Mark and Weapon remain the sole respective packet owners.

## Exact changed chains

- Mark calls the actual `AG_Target_Provenance.read` under the source control
  commit. A torn source returns no logical sequence, so it cannot consume a
  designation that later commits with the same logical ID. Current object
  freshness/association is rechecked even if its logical designation is unchanged.
- Mark brackets the entire update, quenches render validity before writing,
  publishes original evidence and commits one packet. HUDLOS/source1 and
  NAV/source3 keep coordinate behavior and explicitly unknown observation time.
- Weapon target capture, manual consent, immutable program target, assigned
  target validation, delivery publication and guidance-cache target comparison
  use checked points. Capture no longer rewrites radar sample time to receipt.
  Stores copies every original evidence field into station/program records.
- Ballistic prediction consumes the checked delivery point for source, sequence,
  target plane and asynchronous-context identity. Raw HUD coordinates cannot
  bypass an unavailable/torn delivery packet. A final read precedes AUTO
  presentation/release computation.
- Navigation target-mark capture uses the checked point. Its waypoint ACK
  compares request/result/target sequence from the complete packet, retaining
  explicit terrain/power failure feedback when target validity is0.

## Checks and actual limits

Seventeen independent new tests pass on Lua5.1 via the new common Host. They
execute actual proposed Mark/Stores/Weapon/Ballistic/Navigation owners, actual
source readers, explicit native weapon host ports, every protected-field read
boundary and every Mark writer boundary. They verify original time, typed
zero, lease edge, stale/association/epoch withdrawal, fixed retention/cancel,
NAV success/error ACK, immutable copied metadata, program withdrawal and
prediction rejection/recovery. Synthetic schedules are not observed DCS races.

`PRE-FIX-RESULTS.json` records the actual unchanged Mark dropping completed
logical1 after an activity during odd control3. It is historical failure
evidence, not a final expected-answer test. `RESULTS.json` records exact source,
patch, helper and test identities. All five proposed shared sources and the new
helper compile as Lua5.1. `git apply --check --ignore-space-change` succeeds;
it was not applied. New Snapshot functions have maximum CC10; new packet writer
helpers are below10. `COMPLEXITY.json` separates inherited contended bodies.

The MAP consumer is migrated in current primary source; the native release consumer
requires the separately reviewed patch before a full-chain claim:

1. Root-owned `AG_Radar_System` now reads the checked Mark snapshot after its own
   control transaction commits and projects through the current image pose. Invalid
   mark evidence withdraws the cue. `test_ground_radar_workflow.py` covers the
   actual checked cue path; no raw coordinate fallback remains.
2. Chat4/Chat2-owned `NativeSidewinder.cpp` `ground_live_names`,
   `ground_identity_current` and `update_ground_release` read delivery
   coordinates, validity and solution-match fields around lines336â€“380. They must
   bracket the new delivery marker/epoch with checked reads and preserve/compare
   original observation known/time/epoch/request/type before achieved native
   cache/use. The Lua comparison alone does not prove native achieved target
   identity or a weapon effect. Native schema/registration/build changes remain
   serialized owner work.

Saved controls, HUD styling and audio are preserved. Actual host callback order,
target-specific weapon effects, loaded identity, installation and DCS/2D/VR/MP
remain separate qualification gates; none is passed here.
