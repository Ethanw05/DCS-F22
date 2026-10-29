# RWR red / radar yellow: last-flight diagnosis

Investigated 28 October 2026 from the normal installed mod and `Saved Games/DCS/Logs/dcs.log`.
The latest mission segment ran 21:04:45–21:14:34 MDT (29 October 03:04:45–03:14:34 UTC)
on DCS 2.9.31.29434. This is a classification-policy/integration mismatch, not evidence
that the radar failed to detect or correlate the emitter. No runtime files were changed.

## Flight evidence

| Log line | UTC time | Recorded state |
| --- | --- | --- |
| 35104 | 03:04:57.682 | RWR emitter 16777472, label 18, search signal 1, identity unknown (`class=-1`). |
| 35108 | 03:04:57.693 | Radar file 1 / radar source 9, identity unknown (`iff=-1`), correlated RF signal present (`ew=1`). |
| 35111 | 03:04:57.736 | Same RWR emitter becomes hostile (`class=0`), still search signal 1. |
| 35249 | 03:05:00.601 | Radar file 1 / source 9 is selected (`pri=1`), has RF correlation (`ew=1`), and remains unknown (`iff=-1`). |

The RWR metadata service reported READY=1 and REASON=0 in all 2,877 post-startup
avionics samples of this segment. The hostile transition occurred during a search
emission, not a signal-3 launch/illumination hostile-act event. The log contains one
RWR emitter during this encounter. `ew=1` is published through the existing tactical
correlation path; RWR source 16777472 and radar source 9 belong to separate namespaces.

## Installed code path

1. `RWR_Affiliation.lua:18–23` accepts fresh, coherent native RWR affiliation
   metadata. `RWR_System.lua:189–198` applies it to the received emitter. The native
   implementation in `NativeContactIdentity.cpp:130–134` compares DCS coalitions;
   this is simulator identification, not an achieved IFF interrogation/reply.
2. `AESA_Control.lua:74` initializes owned radar observations with `iff=-1`.
3. `Radar_Contact_Metadata.lua:14` returns only the correlated emitter's label and
   RF signal. It does not return affiliation, its provenance, or its observation time.
4. `Radar_System.lua:771–773` colors the scope from `t.iff`, explicitly keeping
   correlated simulator coalition separate from combat identification. Thus the
   correlated warning can reach the radar while the scope remains yellow/unknown.
5. `MFD_RIGHT/defensive_overview.lua:82–85` uses affiliation 0 for red. Its separate
   alert override can also draw red; this encounter already had explicit hostile
   RWR affiliation. `Defensive_Contact_Indicator.lua:12` uses a circle for kind 1
   (the airborne/default contact class). Shape does not certify an IFF reply.

Line numbers above refer to the installed Lua inspected for this flight. The relevant
RWR modules, contact-metadata reader and class-marker module match main after newline
normalization. Main's radar scope retains the same classification policy, so merely
copying current source would not resolve this discrepancy. Other source/install
differences exist but are not the cause established here.

## Required follow-up: R-RAD-023

Resolve the shared identity policy between the defensive and radar pictures. Weapons-EW
owns identity evidence/provider and fusion semantics; radar owns the scope consumer.
If approved common evidence is presented on both pages, transport its identity-known
flag, original observation time, provenance, clock/epoch and conflict/friendly protection
through a fresh, unique association. Preserve the distinction between passive/simulator
identification and achieved IFF. Do not join source numbers directly, infer hostile from
missing replies, or copy a red warning color into identity.

This investigation does not implement that policy change or qualify an IFF backend.
The existing contract remains in `chat4-weapons-ew/IFF-PROVIDER-CONTRACT.md`.
