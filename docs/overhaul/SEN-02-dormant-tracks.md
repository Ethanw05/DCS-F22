# Dormant objects, search-track service and duplicate coast retirement

The reported 27 October flight used BLACK GLASS with exactly two MiG-29A
late-activation groups and one 1L13 EWR. The saved mission, track and closed log
are preserved under ignored `build-radar/duplication-investigation`. Sampled
telemetry contains 142 native track numbers in 270 reported packets. Native
contact count reaches18; the Lua scope reaches27 plots. Raw RWR records only
one emitter,16779008, labeledS, and emits a search ping every three seconds.
Missing MiG RF detections are not manufactured to match radar detections.

Three defects combine:

- The shared scene query includes dormant spawn objects. The provider checked
  type/death but omitted the shared MovingObject presence flag32. Its measured
  returns cluster around the two inactive spawn positions while Doppler uses
  their configured nonzero velocity. The matched common detection entry at
  CockpitBase RVA340e10 explicitly requires flag32 before accepting the object.
  Air detection and incoming-jammer surveys now require it. No mechanical
  radar instance, scan state or observation cache is used.
- Only pilot-designated/acquired/support files had dedicated revisits. Ordinary
  detections waited for another search raster, often approximately six seconds.
  The native owner now confirms tentative files at the existing100ms request
  and maintains unselected confirmed files at an estimated500ms request. Pilot
  acquisition/support retain first claim; discovery retains its RF time floor.
  Weak returns may miss several looks; only actual detections refresh time.
- Native association had six-second memory, native publication12seconds, and
  Lua presentation another10/20seconds. Native expiry now respects the same
  six-second association bound. A complete coherent native snapshot retires
  missing owned IDs from Lua selection and tactical publication immediately.
  Native coasting remains represented by VALID1 and an aging observation;
  unavailable/torn snapshots are not interpreted as explicit retirement.

DCS type text was also dropped inside Radar_Computer's metadata copy. It now
survives that owner and reaches actual tactical publication. The stockS ground
search/EWR code is renderedEWR, with the existing ground-radar marker. Persistent
EWR search sweeps no longer retrigger the routine ping; lock/launch remain.
No same-DCS-ID association, display-only duplicate suppression, NIS gate change
or fabricated measurement is introduced.

## Radio noise

Hex-Rays against the matched CockpitBase database confirms TACAN post_initialize
RVA2ea490 explicitly enables receiver squelch, while base ILS post_initialize
RVA2e1360 leaves its audio setup to the aircraft. NativeNavigation previously
supplied neither ILS squelch control nor readback. It now uses the exported
avReceiver setSquelchOnOff/getSquelchIsOn functions on the qualified TACAN+2064
and ILS+2048 receiver subobjects. These offsets are verified in their native
initialize/post methods; existing owner/table/size and PE guards precede use.
F22_NAV_SQUELCH_VALID publishes current readback into service telemetry. Missing
audio capability does not fabricate or disable the navigation observations.
This repairs the open-squelch path; the flight log does not record audible
output, so attribution of all reported static still needs a listening check.

## Verification and limits

- Actual native provider: dormant/active/dormant transition, with the same
  nonzero configured velocity; dormant units produce neither detections nor
  incoming jammer contribution.
- Actual radar model:70seconds, two weak off-axis moving aircraft, changing
  ownship attitude, no pilot designation. Both240Hz and20ms callbacks retain
  exactly two stable IDs after acquisition. Maximum observed ages3.05/3.50s
  include real missed detections; subsequent blocked LOS expires both files.
- Negative control using13ab630: new scheduler test fails on inconsistent
  tracking; new provider test fails because the dormant unit is accepted.
- Actual Lua owners: coherent retirement clears the selected/acquisition file,
  retains independent source identity, carries DCS type metadata and withdraws
  the retired contact from the fused defensive picture. A separate unavailable
  snapshot retains coast, and a valid aging file preserves its own covariance.
- Actual native navigation owner: receiver squelch calls/readback, unavailable
  audio exports, wrong ILS instance/table, failed profile and stale supply;
  navigation measurements remain independent of audio readback success.

Offline tests do not establish new-DLL DCS flight acceptance. Aircraft activation,
two-target acquisition/selection, audible output and native receiver effectiveness
must still be checked in game. The100/500ms scheduler requests and six-second
memory are mod policies, not authenticated APG-77 parameters. Existing long/native
API-resolution and navigation-update complexity/allocation exceptions remain;
the new bounded maintenance, retirement and squelch helpers do not claim to
remediate unrelated legacy functions.
