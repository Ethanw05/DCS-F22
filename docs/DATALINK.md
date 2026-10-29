# Datalink and RWR proximity

The F-22 has an independent native datalink terminal built over the shared DCS
`wRadio.dll` service. It does not require the Hornet or F-15 avionics DLLs, a
mission-script sensor feed, or an Export.lua modification.

## Pilot controls and display

Two assignable controls are under **F-22 Datalink** in keyboard/joystick settings:

- **Datalink - Receive On / Off** controls the complete receiver.
- **IFDL - Transmit / Receive On / Off** controls Raptor peer exchange while
  retaining reception of Link 16 donor reports.

Both start enabled and require main electrical power. Own radar operation is
independent. No physical key combination is assigned automatically.

Offboard symbols on the tactical display are marked **IFDL** or **L16**. The common
picture associates qualified participant identity and compatible sensor geometry;
radar track numbers and donor-local track numbers are separate namespaces. A fresh
associated radar symbol suppresses its duplicate offboard symbol. Known friendly PPLI is green;
direct same-flight Raptor PPLI is cyan. A target report without qualified identity
remains unknown. Peer reports do not establish STT, a radar detection, a launch
solution, or missile support.

Reports retain their sender, original geometry time when known, receipt time and
velocity. Source-timestamped reports predict from their observation time. Native
AI reports have an unknown observation clock: their displayed motion estimates
from the original receipt time, retaining the unknown-time/coast qualifier. Both
estimates stop after thirteen seconds. **C** also marks known reports older than
thirteen seconds. PPLI expires after 26 seconds; target reports retain up to 75
seconds of visibly coasting situational-awareness memory. These are mod policy
limits for sparse reports, not measurements of an AI sender's current cadence or
weapon-quality information. Display updates renew neither clock. PPLI and
surveillance reports retain separate membership/lifetime records, so a target
report cannot erase or renew flight membership. Radar/RF/optical ages remain
independent. Range changes rescale contacts and retain offscale direction cues.

The defensive overview now uses the native RWR `POWER` value for relative RF
proximity. Stronger/closer indications move inward rather than remaining on the
rim. Warning/launch severity remains a separate visual state. **REL RF** identifies
relative proximity; it does not claim a nautical-mile measurement. Available radar,
datalink and qualified RF geolocation positions retain their own range and source.
The scale for positioned contacts is labeled **NM**. Raptor flight-member contacts
are supported in the defensive overview as well as the tactical display.

## Native implementation

`NativeDatalink.cpp` owns a standard `wDatalinkCommunicator`, a transceiver and its
bounded receive queue. It registers the terminal on the F-22's own interface,
uses the stock MIDS carrier configuration, and consumes actual received messages.
Only a received sender ID is resolved to establish network membership. Target
positions are decoded from reports; target objects are never queried for position.

The adapter decodes DCS TADIL-J J2.2 PPLI, J3.2 surveillance and native
fighter-to-fighter donations (free-text kind 91, extension 0) using the shared
native decoders. Link 16 reception remains receive-only at the application
level. Our player-to-player IFDL uses a separate `F22IFDL1` message body over the
shared radio transport. It shares own position and genuine onboard radar
observations only; received reports are never relayed recursively.

Own peer transmission is limited to five packets per second, each containing own
PPLI and at most 32 measured radar reports, with a 16 KiB payload limit. A delayed
callback sends at most one packet, without catch-up bursts. Five hertz is a mod
responsiveness policy, not a real IFDL specification. The receiver drains its
bounded queue on the 50 Hz combat callback; fusion consumes it at 20 Hz. Actual
host scheduling and radio delivery can add latency. The mod does not control the
common AI terminal's transmission schedule, so smoother motion and faster own
peer exchange do not claim faster AI observations.

Receipt-age diagnostics publish newest/oldest retained report ages separately
from receive-message totals and own transmit totals/age. Empty receive memory
reports age 999. These counters expose arrival gaps without fabricating updates.

AI Raptors do not run the player cockpit. Their native common-terminal peer
reports are adapted to the mod's IFDL channel. This is a simulator compatibility
choice, not an implementation of the real IFDL waveform, encryption or gateways.
No automatic F-35/MADL interoperability is implied.

The aircraft definition advertises native `Datalink`/`Link16` participation;
`EPLRS=true` alone was insufficient metadata. Donor availability and native mission
network configuration still govern what is actually transmitted.

All private ABI access is gated to the inspected DCS module profiles. A different
build disables the adapter instead of using guessed offsets. Multiplayer network,
re-slot and two-client IFDL acceptance require separate qualification.

## Validation status

Source tests cover native message decoding, queue ownership, peer filtering,
rejected malformed/expired reports, source-local ages, power/rewind clearing,
world-frame reprojection, symbol deduplication, flight identity and exclusion from
fire control. The actual RWR owner-to-picture-to-defensive-display test verifies
that native POWER changes move an RF-only contact inward without inventing NM.

Native DCS flights received F-22, AWACS, Viper and Hornet participant positions
with own radar off. Actual F-22 fighter donations and AWACS surveillance reports
were decoded and displayed. Viper/Hornet radar donations still need an isolated
producer qualification; their PPLI alone does not prove target sharing. Receiver
controls, RF/datalink source association and native POWER placement passed.
Range reduction from 80 NM to 5 NM retained five received contacts, with offscale
direction cues. Mixed-client IFDL and re-slot remain unqualified. Datalink-only
weapon employment is not implemented. The timed validation hook was removed
after testing so its receiver-off/IFDL-off phases cannot interfere with normal use.

## MAWS approach qualification

The native optical detector can accept outgoing friendly shots on low bearing
rate. The mod now checks successive native optical world bearings/ranges for
closure and closest approach before issuing a warning, and explicitly withdraws
rejected tracks from warning memory. Approaching threats remain eligible
regardless of coalition. Policy limits are over 25 m/s closure, closest approach
within 60 seconds and miss distance under max(300 m, 3% of observed range).
These are mod policy limits, not claims of real F-22 performance.

Controlled flights reproduced the old friendly-shot alarm, then showed native
optical detections with no warning after the fix. A separate hostile incoming
missile flight produced an audible warning with the new classifier.
