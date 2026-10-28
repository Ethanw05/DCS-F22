# Oct27 reported EW indication and duplicate contact

The normal `dcs.log` closed at 03:11:29 UTC Oct28 contains five cockpit
sessions. The receiver logged only source16777472, label29, never more than
one emitter. The common radar picture sometimes displayed a new radar track
beside an old coasted track. No own ECM command/effect telemetry or dedicated
EW-trial markers exist in this flight: it cannot establish successful jamming,
enemy receiver degradation or the planned trial phases. It supplies no ground
MAP acceptance evidence. The local archive is ignored build output, not source.

## Corrections

- The range-then-angle EKF correction could collapse a tentative long-gap
  prediction around an inaccurate Cartesian position. Position correction now
  transforms the measured range/angles and their full first-order correlated
  noise covariance into Cartesian coordinates, whitens that covariance, and
  uses linear position updates followed by measured scalar Doppler. State,
  covariance, observation time, association gate36 and private host binding
  policy remain measured-only. This is a converted-position Kalman / Doppler
  EKF, not authenticated APG-77 processing. The existing CV process intensity
  and sensor calibration are unchanged.
- The recorded 1.09/4.41/4.45s packets reproduce the rejection with the old
  filter and remain one accepted track with the correction. Sparse archived
  telemetry does not reproduce every native dwell or qualify the entire flight.
- Radar/RF correlation compares the radar history at the measured RF epoch and
  ownship reception origin. Bounded128-sample histories per radar track preserve
  turns; a six-second uncertain CV estimate is used only when suitable measured
  history is absent. Broad uncertainty and reciprocal ambiguity keep contacts
  separate. Host identifiers never establish correlation. Aged direction-only
  inputs still cannot be asserted as fresh matches.
- The shared native callback samples own common ECM flag8 with the existing
  qualified ECM adapter even when radar is OFF. Snapshot epoch, publication
  sequence, timestamp and instance guards cover the readback. It never commands
  an ECM object or uses own ECM as incoming receiver interference.
- EW remains the sole command owner. `ECM ON` indicates host acknowledgement;
  `JAM` and green outward arrows indicate the qualified common game effect.
  Native effect expiry/unknown status removes the arrows. Each arrow requires
  a current RF emitter; it represents broadcast coverage, not selective attack
  or proof of a particular receiver's degradation. No RF watts are inferred.

New endpoints: `F22_NATIVE_ECM_VALID/ACTIVE/TIME/GENERATION` inside
`F22_AESA_SEQUENCE`; `F22_ECM_EFFECT_TIME/DISPLAY_STATE`; per-DEF `RF_CURRENT`.
Own ECM request, acknowledgement, native activity, validity and time are added
to ordinary flight telemetry. The previous quiet trial heartbeat was stopped
when its preflight/build assumptions became obsolete during this investigation.

## Verification

Native tests include actual provider ECM sampling with radar OFF, stale data,
wrong owner and teardown, plus the recorded tentative revisit and existing
crossing/ambiguity tests. Lua tests exercise the actual EW owner, request/effect
divergence, stale/torn/future packets, coverage gates, reception-origin retention,
delayed RF with a later maneuver, ambiguous candidates and bounded histories.
In-game cue alignment and the complete EW trial remain to be flown after install.
