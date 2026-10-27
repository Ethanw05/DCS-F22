# Cooperative RF/radar search — 26 October 2026

Later integration: `PASSIVE_RF_GEOLOCATION.md` documents the additional
estimated-location display. Invented SCAN RF / SCAN SUPPORT labels were removed
on user review; task diagnostics remain in parameters and logs. The isolated
prototype and uninstalled-source statements below describe this original
checkpoint; use the later release manifest for the installation state.

Direct user request: radar and RWR should cooperate to find targets, automatically
adjusting search elevation and horizontal/vertical width to emulate an AESA
workflow. This continues audit RAD-02, FUS-01 and EW-01.

## Public evidence and implementation boundary

Ronald W. Brower's historical F-22 chapter describes integrated track files and
automated sensor tasking rather than requiring the pilot to manage each sensor:
https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf

BAE describes the ALR-94's passive RF awareness and integration with targeting:
https://www.baesystems.com/en-us/product/an-alr-94

These support cooperative tasking as a functional goal. They do not publish the
operational APG-77 scheduler, RF accuracy, dwell times or threat-library logic.
The policy below is an explicit community-mod implementation over one common
DCS radar volume. It does not create independent electronic beams, increase
native detection accuracy, replace the radar or instantiate a paid-aircraft
backend. Passive cueing cannot create a radar detection, STT, range or missile
support solution.

## Confirmed native bearing/elevation contract

Installed D:/DCS/bin-mt/CockpitBase.dll SHA256:
163d55167503da8dd0ea9eb459e17206fc3dc8d6b4805b5b13bbe58341beb794.
The read-only IDA database reports the same hash.

- Common avRWR::getEmitterPos at 0x1802FB640 computes body elevation with
  atan2(up, horizontal magnitude), including the assignment at 0x1802FB9CC.
  Native azimuth uses negative atan2(right, forward).
- The common exporter binds RWR_CONTACT_nn_ELEVATION at 0x180329111. Assembly
  at 0x180329250 loads the emitter's actual float at +0x18, 0x180329255 selects
  the elevation destination handle at +0x10, and 0x18032925C publishes it.
- avRWR::setEmitterTypes at 0x1802FD5B0 writes GENERAL_TYPE at emitter +0x8C:
  1 aircraft, 2 ground, 3 ship, 4 weapon. Exporter 0x1803292B7 reads this field.

Thus elevation on this supported common build is a receiver-produced angle, not
an assumed zero. An undeclared parameter silently reading zero would not prove
elevation support. No compatibility claim is made for an unverified exporter;
actual radar operation still requires the existing checked native coordinate
adapter. Zero measured elevation remains a valid horizon direction.

RWR_Bearings must first recover the reception-time attitude from its continuous
history using native reception age. Missing history, rewind, invalid attitude
or a history gap cannot produce a qualified world direction. Only its accepted,
compensated world unit vector is passed into tasking. A cached body angle is
never treated as a fresh unchanging aircraft-relative LOS during a maneuver.

## Task policy

Radar_Sensor_Tasking.lua adds an enabled-by-default RF search assistant.

- Eligible cues are fresh aircraft-type RF observations, not ground emitters,
  ships, optical missile observations or inferred hostile classifications.
  Positive friendly/explicit flight-member identities are excluded.
- The common publisher exports RF_GENERAL, RF_DIRECTION_VALID and RF_WORLD_N/U/E
  separately from the track's potentially newer radar/optical direction. They
  are unit-vector components, not emitter coordinates.
- A complete tactical publication must be at most 0.25 s old, with its sequence
  unchanged during reading. Publication latency adds to RF reception age.
  Search cues expire at 4 s; lock/launch RF cues at 3.5 s. These are mod limits.
- Every radar tick reprojects that world direction into the current body frame.
  Cues outside the native +/-60-degree azimuth/elevation bounds are not tasked.
- With no selected/designated/support obligation, RWS and TWS alternate a 2 s
  RF discovery dwell with 2 s of the normal search. Signal priority and time
  since service order the bounded 16-cue queue. Nearby cues share a volume;
  hysteresis avoids moving it for tiny bearing changes.
- RF dwells adjust azimuth, elevation and full horizontal/vertical width.
  Minimum full dimensions are 20 by 12 degrees; age expands search padding.
  Pilot-selected range is retained. RF power or bearing-ring radius never
  becomes range, and scan padding is not calibrated angular covariance.
- Selected/designated radar files and missile-support obligations take priority
  in both RWS and TWS. Their complete native volume remains covered. RF cues may
  enlarge it by at most 25% angular area only with spare support revisit budget;
  an overdue or uncovered obligation prevents that enlargement.
- Manual elevation, width, height or recenter commands suspend RF steering for
  8 s. Existing target/support management remains authoritative. Background dwell
  scheduling can add up to 2 s before RF discovery resumes.
- ACM, acquisition, STT, A/G, deliberate radar OFF, power loss or unavailable
  native geometry inhibit RF search. RF policy never commands lock or firing.

The existing display's SCAN AUTO and effective AZ/HT/EL readouts follow the
actual commanded volume. Left-bezel values retain the pilot's requested pattern.
New task-specific status endpoints are available for a concise RF reason label;
this pass does not rewrite parent-owned display layouts or menu mappings.

## Genuine radar detections and delivery latency

The receiver cue alone leaves radar track count zero. A genuine native world
observation received inside the RF-directed volume must pass the radar computer's
acceptance gate even if it lies outside the pilot's previous elevation slice.
The computer retains the actual effective scan separately from hard-plan
hysteresis. A bounded time window also accepts real, time-stamped native world
observations delivered after an RF dwell ends. It is cleared on reset/A/G and
does not authorize old observations predating the issued dwell. Range remains
limited by the actual issued search range. No measurement is generated by this
permission; all detections still originate from the checked native transport.

## Status, diagnostics and qualification

Construction initializes F22_RADAR_SENSOR_TASK (0 inactive/manual, 1 background,
2 RF discovery, 3 radar/support obligation), RF_CUE_ACTIVE/SOURCE/COUNT/PENDING/AGE
and RF_MANUAL_HOLD before any native indicator binds. F22_SENSOR_TASK log rows
record phase/source changes with effective azimuth/elevation/width/height and
hard/support counts. Existing native support freshness, hit counts and launch
eligibility remain unchanged.

test_cooperative_radar.py exercises scheduling/fairness, bounded volumes,
hard-obligation priority, manual authority, mode/power gates, coherent-publication
freshness and delayed native observations. test_cooperative_radar_transport.py
executes the actual RWR owner, common track store and radar owner: a nonzero
35-degree-right/25-degree-up RF reception steers the native scan, a 30-degree
ownship turn moves it to 5 degrees right, and a newer optical observation cannot
replace RF LOS. A supplied real-radar observation at the cued elevation creates
a track; RF alone cannot. ACM/A-G/manual/power transitions clear assistance.

These are actual-source tests with synthetic sensor inputs. Native discovery
time, intermittent-emitter behavior, simultaneous support outcomes and the
chosen dwell/padding values require controlled DCS flights against a matching
installed manifest. An unowned DCS session is currently held untouched; no live
copy or native acceptance is implied by source readiness.

The stationary-ground geolocation prototype remains isolated outside the source
tree and is not part of this feature or its deployment.

## Frozen source checkpoint

Final shared regression run: **95/95 scripts PASS**, including the concurrent
A/G asynchronous-response fixture repairs. Earlier intermediate failures are
superseded by that final result. New helper formatting and owned-file whitespace
checks pass. Exact log/result: fi/work/cooperative-radar/validation.log and
validation.json.

Seven runtime Lua files must be copied together: Radar_Sensor_Tasking,
Radar_Computer, Radar_System, Radar_Config, RWR_System, Tactical_Picture and
Tactical_Tracks. No native DLL or device-registration change is required.
Frozen deployment copies and SHA256/read-only installed comparisons are in
fi/work/cooperative-radar/release and release-manifest.json. At this checkpoint
0/7 installed files match; no files were copied into the active game. The
separate five-file user-voice package is independent and still requires its own
coordinated installation/audio acceptance.
