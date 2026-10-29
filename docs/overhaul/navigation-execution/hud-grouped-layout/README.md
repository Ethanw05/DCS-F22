# Approved grouped HUD layout and AP annunciation

Implements the user's full-HUD preview revisions and subsequent AP behavior
correction. Altitude values, radar readouts and weapon metadata have separate
aligned groups. The HUD omits source/pressure captions, repeated A/A labels and
the pre-release missile TOF estimate. Selected weapon and ammunition/count share
the raised right column. Radar range, closing speed and mode use compact rows;
the tracking label remains STT. A/G metadata uses the same weapon-column anchors.
Native target, seeker, release, flight-control and aircraft authority are unchanged.

The weapon envelope starts at the altitude dial centre (layout y=.02), retains
the approved .55-unit length and ends at -.53. Its tick/pointer presentation maps
the existing owner's .46-unit range coordinates by .55/.46. No launch-zone values
or weapon decisions are recomputed. Font, stroke assets, optical geometry, colors,
saved controls and recordings are preserved.

Latest AP instruction supersedes the earlier quiet-engagement proposal: normal
OFF is blank, normal engagement is AP ON, and current limiting is AP LIMIT.
New native reason transitions show AP INHIBIT, AP LIMIT, AP OVERRIDE, AP NAV LOST,
AP ALT LOST or AP HDG LOST for five seconds. A latched reason does not renew that
deadline. Native acknowledgement/reengagement clears feedback. Invalid/stopped
source, generation change, reset and clock rewind retire pending annunciations.

An observed engaged AP dropping an axis or all control for native reasons 2/4/5/6
offers the existing flight_controls recording to the pilot-warning scheduler.
Explicit disconnects, mode deselection, pilot override and inhibited engagements
remain quiet. A schema/sequence/epoch/generation/time guarded notification carries
the original five-second event lease. Higher-priority terrain/missile warnings,
mute and audio availability remain with the existing scheduler. Confirmed playback
or acknowledgement consumes the original event once. No damaged-FCS indication
is fabricated, and no sound asset or additional playback owner is introduced.

89 focused cases passed before installation, including the actual guidance owner
and actual pilot-warning sound calls, warning priority, quiet manual disconnect,
expiry, new events, invalid/retired sources, packet tearing, HUD grouping, envelope
endpoints and full-scale pointer mapping. Lua 5.1/Luacheck 1.2.0 reports zero new
findings and 18 retained findings. At the user's request, no further test runs
are performed; installation verification checks hashes and protected files.

Coding review: new state is bounded to one feedback and one pending audio event;
the source field set has seven entries and no queue grows per update. Transport
publishes a fixed set of fields. Lua-managed allocation remains a tailored case.
New routines have complexity <=15; the publisher/validator and event classifier
exceed the preferred 10 because they check a fixed set of optional fields and
transition predicates. Existing large HUD/warning callbacks remain focused
legacy exceptions; no callback/native lifetime or aircraft certification is claimed.

RESULTS.json identifies source hashes and external artifacts. INSTALLATION.json
records the normal mod copy and protected DLL/font/control/hook/audio identities.
Actual DCS rendering, audible playback, native scheduling and VR/MP behavior still
require an in-simulator observation. The simulator is not operated by this work.
