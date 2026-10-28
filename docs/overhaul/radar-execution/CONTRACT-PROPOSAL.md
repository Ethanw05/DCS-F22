# Radar execution: proposed seams and shared-region requests

Owner: Chat 3. Baseline and exact package/test inventory: `BASELINE.json`.
This is a proposal pending Chat 2 adoption, HARNESS_READY and applicable leases.
The initial proposal preceded source edits. Current applied changes, independent
test remakes and unresolved shared regions are recorded in `STATUS.json`.
No installed file or simulator state has changed.

## P-RAD-001

The owned AESA source-2 report is the measurement authority. Lua retains its
coherence, generation, observation-age, finite geometry, physical field-of-view,
quality and association checks. A later pilot search slice must not reject an
already sensed report. Passive donor/RF cues remain search requests only.

Replace the legacy enclosing scan with a pilot search description and independent
support obligations. Search geometry stays identical to AESA_Control's actual
request between priority dwells. Support eligibility/degradation derives from
the owned measured target, its age/deadline and actual achieved task reports;
geometrical enclosure alone grants or withdraws no support. Retire the old
RF-window admission workaround after authoritative report admission is proved.

Shared regions requested for serialized integration:

- Chat 2: PMFD_CENTER/radar_format.lua AUTO/search indication; preserve styling.
- Chat 4: Engagement_System.lua obsolete SCAN_UNCOVERED degradation; preserve
  its own target-specific support/lost checks.
- Chat 2: commit slot for the complete radar slice and rebuilt assigned tests.

NativeGroundReturns and legacy F22G/map overlay/telemetry readers require a
complete producer/load/caller proof before retirement. Native callbacks, saved
IDs, original research records and source-2 gun analogue remain intact.

## P-RAD-002

Closure: N/U/E world position in metres; velocity in m/s; closing-positive
dot product divided by range, converted to knots. Every contributing scalar,
range and final result must be finite before VALID=1. Genuine zero is valid.
An unavailable ownship component withdraws closure without falling back to
successive-range closure and without deleting the measured track.

Cursor proposal: integrate model-clock elapsed time once per update, including
updates separated by commands (command clock synchronization must not consume
cursor elapsed time). Equal model time means zero motion. A negative delta,
missing/invalid clock, or gap over 0.25 s cancels held axes and requires new
input; this is a proposed game input policy, not an aircraft parameter. Focus,
role, page and power loss cancel A/A and A/G axes. Test 30/60/240 Hz and jitter.

## D-P-RAD-001 and P-RAD-003

Proposed protected control interval: epoch and finite/even sequence first;
REQUEST/TIME, all controls and all priority fields inside; identical sequence
and epoch last. Preserve original producer World-time stamp and 0.5 s lease.
Copy receipt never renews sensing or support authority. Checked read status and
valid zero remain independent. Preserve the existing correct Lua publisher.

Ground generation retires pending measurements, selected/acquisition/range and
filter state together on source-clock discontinuity. Fresh current consent and
observation restore authority. Existing Lua rollback cancellation/future rejection
remain. Source token association must use measured geometry/uncertainty rather
than scene object identity; private host binding remains separate.

Shared Chat 4 review requested before the Radar_Tactical/native transmitter seam:
odd/even complete-packet admission protecting every transmitted field and epoch.
Chat 4 alone owns identity wire schema and IFF_PROVIDER_READY. A radar request,
automatic setting or no reply never becomes achieved friendly/hostile evidence.

Camera admission includes every used finite view/aircraft term, raw enum validation
before casts, and finite derived camera/projection tuples before host copy.
An invalid candidate must preserve the declared retained/frozen image policy.

## Remaining gates

P-RAD-004 requires actual qualified native lifetime/callback/effect/render/budget
evidence and an exclusive runtime slot. P-RAD-005 must resolve coherent SAR
host/GPU feasibility before P-RAD-006; existing DBS coordination remains active.
P-RAD-007 consumes Chat 4's achieved provider or tested unavailable/no-go.
P-RAD-008 separates documented aircraft behavior, analogues and game estimates;
offline numerical verification cannot authenticate aircraft calibration.
