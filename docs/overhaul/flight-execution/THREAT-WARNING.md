# Pilot threat warnings — Hornet reference and implementation

The user requested clearer lock/launch information and the Hornet's warning
behavior as the comparison. The actual flight log already contains native RF
signals 2 and 3, and separate optical missile warnings. The DEF overview discarded
RF severity after choosing a general warning color. Its contacts did not expose
distinct lock/launch labels or pulse with that state.

## Primary references

The installed DCS F/A-18C Early Access Guide EN, pages 53–54 and 411–414, describes
the threat annunciators, status-change tones, repeating launch alarm, emitter
bearings and threat bands. The public guide is available from
[Eagle Dynamics](https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf).
The local copy was read because the direct web download returned HTTP 403.

The current installed Hornet cockpit declarations provide additional evidence:

| Situation | Hornet indication/evidence | Adopted behavior |
| --- | --- | --- |
| New RF emitter | Coded emitter at its relative bearing; new-signal/status audio | Existing short new-contact recording once |
| Radar tracking/lock | Separate STT symbol controller and status-change audio | Explicit LOCK marker and existing lock recording once on acquisition/escalation |
| Detected launch/guidance condition | Threat-flash/azimuth-line controllers; repeating launch alarm; SAM lamp flashes during missile guidance | Faster pulsing source and distinct repeating launch recording while the RF warning is fresh |
| Active radar missile seeker | Shared AN_ALR symbol library maps AIM-120, R-77 and other active seekers to M | Preserve native M classification and RF launch warning; no invented optical detection |
| Optical missile detection | Separate capability from the Hornet RWR's RF indications | Retain our independent MWS and explicit MISSILE label |

`RWR_ALR67_Common_definitions.lua` declares separate STT and flash controllers;
`EW_MAIN_RWR.lua` places the symbols and azimuth lines under the flasher.
`HUD_EW.lua` declares a separate HUD repeater with tracking markers and
solid/dashed azimuth lines. The Lua declarations do not expose the native
controller's entire classification algorithm. The guide distinguishes tracking
from missile guidance; a lock is not confirmation that a missile has launched.

The requested slow lock pulse is a **mod presentation policy**: 1 Hz for a fresh
lock and 2 Hz for fresh launch/optical warning, with 60% visible time. These are
not recovered Hornet flash timings or documented ALR-94 behavior. The original
F-22 sound recordings are retained; no Hornet recordings were copied.

## Complete presentation/audio chain

The existing native receiver remains the RF authority. Its signal codes and
source-local ages reach the overview as explicit SIGNAL and MWS_CURRENT fields.
The contact's identifier/class and warning label pulse together. A steady
RADAR LOCK/RWR LAUNCH headline, including the highest-priority RF emitter ID,
repeats on DEF and both radar pages. The HUD also repeats RF warning state in its
existing font. Compact EW and HUD emitter repeaters share the selected pulse
policy. Position remains a bearing/proximity/range-qualified presentation.

Audio now uses bounded current-source state: a lock/status-change recording plays
once when a fresh source appears locked or escalates to lock. The launch recording
loops while a fresh native launch warning persists. Routine sweep and lost-source
tones are removed from the active policy. The one-shot is not stopped at the next
50 ms owner update. Muting updates history and does not replay old lock cues.
Existing MWS/voice priority gates and volume controls are retained. Historical
ping/lost-contact recordings remain on disk.

Old RF/optical evidence cannot be renewed by a fresh radar track. Coasting symbols
remain distinguishable from current warnings. The existing independent overview
freshness gate withdraws the new banners when its producer stops. No warning is
inferred from mission truth, mere weapon release, proximity, or target association.
Silent/IR shots require a supported detection source; this adds no omniscient
launch warning or passive RF range measurement.

## Verification and limits

`tests/cases/test_threat_warning_presentation.py` is a new requirement suite using
the replacement host. It calls the actual RWR owner and actual indicators with
explicit native states, and checks pulse rates, audio transitions, the active
missile M symbol, source freshness, invalidation, bearings, mute/recovery, distinct
MWS authority and numeric-safe formats. The focused source/syntax regression run
passes 23 cases. A proposed installed package run passes 20 cases through 54
actual script dependencies. No legacy acceptance suite was executed.

Luacheck 1.2.0 reports no new findings. New helpers and the rewritten audio policy
are bounded. Existing large RWR/overview update and declarative display factories
remain focused legacy exceptions; this change does not claim their wholesale
coding-standard compliance. The external quality receipt records before/after
complexity. Preview rendering uses actual declarations with explicit synthetic
states and an explicitly seeded currentness gate; it is not DCS/VR evidence.

`threat-warning-evidence.json` pins the references, source files, checks and
installation request. Actual audible discrimination, flight display legibility,
native warning classification, VR and multiplayer remain separate flight gates.
