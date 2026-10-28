# SEN-04 — GMT acquisition and ground resolving detail

28 October 2026. Ground sensing stays with the owned AESA scheduler, scene
queries, measurement/filter pipeline and track owner. Shared DCS terrain,
visibility and image rendering are environmental services. No mechanical
radar device or aircraft-module radar is installed or used as the sensor owner.

## Evidence and corrected behavior

The retained flight log contains 1,925 F22_AG_SCAN records across mission
clock resets: 676 GMT and 1,249 MAP. GMT reports as many as seven contacts, but
every sampled acquisition-request flag, native acquisition and selected track
is zero. These are sampled snapshots, not proof of every input edge; the code
confirms the ordinary TDC path committed a fixed coordinate and canceled
tracking instead of requesting it. Log revision is not established uniformly
across these flights, so these counts do not qualify the latest installation.

Ordinary GMT/SEA TDC release now requests coordinate acquisition through the
same native AESA path as SCS. A visible measured return can center that cue;
its hidden scene ID is never sent as an acquisition command. Pending EXP
corral selection still selects the view first. Acquisition retains an existing
expanded view, withdraws an unrelated old designation, and allows a bounded
one-second acknowledgement interval. Only a matching, valid native result
creates track authority. Native measurement/coast/expiry times are unchanged.

The ground adapter now dispatches the scene object's virtual velocity getter,
slot38, rather than calling the exported MovingObject base implementation.
Reference: retained FA18C 0x1804A0210 GMT predicate calls virtual+304.
Missing or invalid motion is unavailable. New flight counters distinguish
unavailable motion, below-band speed and above-band speed rejection.
GMT's adopted 8–55kt search filter
is still a Hornet simulation analogue; acquired vehicles may stop.

Search marks use their measured world coordinates registered to the displayed
image pose. Observation age remains unchanged. Marks and selection gates are
larger; six-second search history fades instead of being treated as a fresh
measurement. Initial detections become eligible for a finite routine AESA
confirmation request after0.75s; the existing scheduler still bounds these
requests to one in four surface jobs, leaving discovery service.

MAP now uses the same completed-beam/LOS-gated vehicle returns without GMT's
moving-speed filter. This supplies larger discrete measured marks alongside
the terrain image. Search history/pending search reports are separated on
MAP/GMT/SEA changes, while acquired track measurements remain continuous.
No global-unit enumeration or unilluminated target overlays are introduced.
The top row is directly MAP / GMT / EXP1 / EXP2 / EXP3 in the main, DATA
and additional-mode views. MAP/GMT changes take one press and retain target
authority. INTL uses bezel19 when available; expanded views put FAST there,
with its selected box. FAN/PEN moves to8 and extra modes to12.

## DCS reference and EXP3

The installed CockpitBase.dll exports avA2GRadar, but its exported search()
at0x1801E2420 is an empty return. This does not establish a usable general GMT
service. It also does not prove no other internal service exists. The aircraft
reference remains useful for scene-query, visibility and motion contracts;
its mechanical sensor is not a production dependency.

The actual renderer contract was checked in installed enlight.dll:
AGRadar::blurPass at0x180003360 loads preset resolution from+152,
multiplies it by dynamic Param2 at+56, then scales resolution and blur angle
by min(19/effective_resolution,1) for DBS. The matched shader is
D:/DCS/Bazar/shaders/enlight/radar.fx, blurRadialDBS.
Thus Param2 is a resolving-detail multiplier, not a texture-size setting.
All EXP views now supply2 in detail mode and1 in FAST, versus the prior1/0.5.
Their distinct preset resolving levels remain19/67/120 before that multiplier.
Ordinary MAP retains the shared preset's one-degree real-beam blur: Param2
does not change that branch. The sharper expanded-view setting is an
explicit mod estimate using DCS Doppler image formation, not authenticated
APG-77 resolution or a new full SAR signal processor. Texture size is unchanged.
FAST still shortens the accepted renderer pipeline and reduces sharpening;
it does not bypass AESA work or confer extra RF priority.

## Validation boundary

Actual production-owner fixtures cover ordinary GMT HOTAS TDC release,
coordinate-only acquisition, delayed/mismatched/missing acknowledgement,
native measurement-only track authority, EXP corral/acquisition continuity,
MAP/GMT view continuity, coast/loss, stationary MAP returns versus GMT speed
rejection, virtual motion, and initial-hit confirmation requests. Native
fixtures run with MSVC warnings/static analysis; Lua is checked with the DCS
interpreter and pinned Lua5.1/Luacheck. Detailed results are retained under
out/gmt-exp-review.

The 35 native tests and 9 ground workflow checks pass. DCS Lua parses the four
modified cockpit scripts; pinned Lua5.1/Luacheck reports zero new findings
against their HEAD baseline. The broad script run passed 181/185 checks;
the four remaining HUD/focus/trim failures are retained in its log, not
reported as an all-pass. Additional top-row dispatch and physical-layout
checks pass after the requested direct-button change.

These are substituted-host and renderer-contract checks. The new installation
still needs a flight to qualify moving-target continuity and EXP3 appearance.
