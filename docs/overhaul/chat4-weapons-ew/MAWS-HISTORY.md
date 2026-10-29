# MAWS temporal classification

The warning owner now retains approach history instead of treating every
opening measurement as an immediate dismissal. This supersedes the simple
receding rule in MAWS-REACTION.md. It remains independent of aircraft-specific
DLLs and the RWR launch indication.

## Public research and its limits

[Saab's IDAS/CIDAS brochure](https://www.saab.com/globalassets/sites/defexpo/electronic-warfare/idas.pdf),
MAW-300 section, describes spatial/temporal processing, compensation for platform
motion, multiple tracks and suppression of diverging missiles. These support
history-based classification as a general design principle. Its UV sensor
specifications do not establish F-22 IR performance or our numerical thresholds.

[Hensoldt's MILDS F description](https://www.hensoldt.net/products/anaar-60-v-2-milds-f-missile-warner-for-fighter-aircraft)
emphasizes rapid declaration with low false alarms and passive imaging.
[Hensoldt patent US10801816B2](https://patents.google.com/patent/US10801816B2/en)
describes verification using stored earlier sensor data. This motivates retaining
evidence, but we do not implement its multispectral algorithm: DCS's admitted
contacts provide no calibrated image radiometry or multispectral measurements.

These are analogues. The research did not establish an authenticated AN/AAR-56
clearance algorithm, hold time, sensitivity curve or exact target-intent test.

## Implemented rules

Every number below is mod tuning, not a documented F-22 specification.

| Situation | Behavior |
| --- | --- |
| First detection | Preserve native optical visibility and more than 3 confirmation hits. Require a 0.1 s motion baseline. |
| Measured approach | Closing above 25 m/s and linear closest-approach time within 60 s declares a warning. Projected miss distance is diagnostic. |
| Temporary opening, loft or turn | Keep the existing warning for at most 5 s after its last measured approach. Fresh receipt or repeated opening measurements cannot renew that evidence time. |
| Observed close pass | Clear after at least 0.6 s of opening above 25 m/s, closest observed range at most 2 km, subsequent growth at least 300 m and at least 90 degrees of line-of-sight rotation from the approach bearing. |
| Sustained wider separation | Clear after at least 2 s of opening above 25 m/s, growth at least the larger of 500 m or 10% of closest range, and at least 30 degrees of line-of-sight rotation. |
| Continued opening without enough clearance evidence | After the 5 s evidence lease, report uncertain internally and stop warning. This does not assert safety or seeker unlock. |
| Renewed approach | Declare again immediately from the measured motion, including after an earlier pass/divergence clearance. |
| Friendly/outgoing missile | An initially departing missile stays quiet. Coalition identity cannot blanket-mute a later approach. No hidden target/seeker state is read. |

The approach reference uses the native relative position in world axes rather
than body angles, avoiding apparent bearing rotation caused solely by rolling
or turning the aircraft. Ownship translation remains part of relative motion.
A missile first detected while opening cannot be proven to target ownship
from these measurements; it stays unconfirmed until approaching. A closing
missile aimed elsewhere can still warn. This conservative limitation is explicit.

## Ownership, transport and capacity

`MawsThreat.h` owns a fixed 512-track pool matching native admission. Overflow
rejects an additional track without evicting a live one and publishes a diagnostic.
Native source-ID/incarnation changes, invalid data, clock reversal and observation
gaps over 1 s retire motion history. The incarnation is an existing opaque native
object link, never target identity or seeker intent. No recurring core allocation.

Native reports carry schema 1, World-time sample stamps, epoch, per-contact
decision/evidence time and an odd/even commit marker. The Lua reader captures
the marker before all used payload fields and rechecks it and the header after
capture. Reports older than 0.35 s, incomplete commits, wrong schemas and invalid
epochs withdraw readiness. Source epoch changes also retire Lua warning/bearing
memory. Native source timestamps remain unchanged through transport.

The Lua warning memory retains its existing 0.5 s fresh/3 s lost-contact coast
behavior, bounded by the original evidence lease for maneuver-held contacts.
Current approaches rank ahead of held warnings. The RWR/critical-voice audio
arbitration and countermeasure command ownership remain as previously implemented.
The new reader prebinds handles and reuses 16 row buffers. Native collection and
publication still have the legacy bounded container/string allocations described
in MAWS-REACTION.md; this change does not claim their full lifecycle replacement.

The focused coding-standard exception for `NativeMWS::update` is reviewed here:
lizard 1.17.31 measures the existing adapter at 94 nonblank lines/CCN 37 before
and 111/41 after. Its legacy native lifecycle remains intact; adding coherent
publication and per-row state increases orchestration rather than introducing
another native scan. This bounded exception avoids combining an ABI/lifetime
rewrite with the warning fix. Admission remains at most 512 native contacts and
16 published rows. All new policy helpers have CCN at most 10 and at most 34
nonblank lines; publication begin/end helpers are at most 4. The actual owner
probes exercise the changed classification and failed-commit behavior. The full
native lifecycle/branch coverage work remains open, including actual DCS pointer
lifetime and host memory ordering.

## Verification and installation

Actual C++ owner probes cover direct/lofting approach, initially outgoing/stationary
contacts, horizon, temporary opening and evidence expiry, close pass, sustained
divergence, turnback, stale/reversed clocks, ID incarnation, duplicate samples,
invalid inputs, pool exhaustion and failed publication commit. Seven Lua-owner
cases cover evidence expiry, explicit pass clearance, epoch retirement, incomplete
or changing packets and the existing RWR/voice audio behavior.

Build and installation identities and exact check results are recorded in
MAWS-HISTORY-INSTALLATION.json. The build replaces only NativeMWS and identity
objects, preserving the other 16 objects from the installed aircraft lineage,
including the existing IRST and ground-radar fixes. Installation replaces the DLL
and three MAWS Lua files; protected cockpit assets, audio and saved inputs are
hash checked. Actual flight timing, optics and loaded identity still need a user
flight. Offline motion probes do not authenticate aircraft performance.
