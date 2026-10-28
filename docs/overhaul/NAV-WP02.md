# NAV-WP02 — independent simulated GINS references

The official indexed AFMAN11-2F-22AV3 (20 September2018), p36 §7.9.1.1 was reread on27 October2026. It distinguishes the HUD and alternate SFG GINS sources, including use of the right upfront display. The direct official PDF still returned403. Brower (2001), §32.3.6 establishes historical ring-laser IRS function. Neither source supplies the production alignment schedule, wiring, drift law or selection menus. The installed ED Hornet guide (24 March2024), pp115–118 supplies the stationary/stored-heading alignment and degraded-navigation analogue.

The selected simulation has two independently failed references sharing healthy host observations. Each owns power/alignment and independent attitude, heading and position health. Two INS_Model estimates retain separate coasting/error/positive-fix state. HUD/NAV/right-SFG selection is explicit; defaults are1/1/2. Failed primary attitude cannot silently select the other channel, and position loss does not erase healthy attitude/heading or native radio observations. Healthy declared DC-powered estimates continue without main display power; actual battery-only screen/receiver wiring remains a separate qualification gap.

Active path: NAV rocker → NAV SETUP → GINS REFERENCES → ALIGN SELECTED NAV GINS. Normal480s, retained-heading90s and explicit TRAINING30s are project estimates, not quoted F-22 or Hornet specifications. Retained heading requires prior healthy memory, unchanged position/heading and a bounded outage. Movement resets incomplete alignment. The5m/5degree/900s memory criteria, first30s attitude stage, five-second short power hold and uncertainty/coast rates are estimates. Long airborne outages require ground alignment in this core profile; the former automatic30s airborne convenience is removed. No classified recovery law is inferred.

Gins_References publishes schema/sequence/time/valid with fixed prebound fields. The current schema is mandatory from startup. Readers compare the commit before/after and reject nonfinite/stale/unknown frames and contradictory powered-off health. NAV position, HUD projection and right-SFG attitude use their selected valid reference. Primary and standby native moving-horizon graphs have separate validity gates; missing attitude shows a data flag. Wind numbers remain true-reference, with the arrow separately requiring heading. Existing fonts/colors/projection, repeated input suppression and saved command IDs remain.

Actual guidance/NAV/HUD/UFC/display owners and write-only native element graphs cover independent component/source failures, standby survival, accepted selections, no AP engagement, GPS coast without hidden truth, failed/stale/mixed publications, movement/retained/training timing, power-source separation and rewind. The pinned focused Lizard gate enforces CCN≤15/NLOC≤60 for the new helpers; retained large HUD/UFC callbacks remain documented migration exceptions. Actual source-switch optics, right-UFD placement and in-DCS alignment/failure scenarios remain unqualified.

Current-contract cleanup: reference power/stationary state requires the current coherent physical frame from startup. The MAIN_POWER/HUD-ground-speed startup substitute is removed. Missing ownership cannot permit source selection or make a channel healthy. All NAV/HUD/ADI consumers now require current selected references; optional-schema/raw-pose routes and the INS model-disable perfect-position bypass are removed. A missing channel invalidates its estimate before recovery, and GPS loss still permits healthy measured-velocity coast. NAV computes ground speed from the declared velocity observation without substituting the HUD display output. Exogenous test publishers advance actual frame metadata; reference-feed failure is separate from main display power. Absent-schema and disabled-model regressions reproduced both old bypasses before the fix. Independent standby, coasting, radio reception and alignment/rewind regressions remain.

Selected-pose cadence: the prior 50ms reference publication was consumed by a
20ms HUD, producing a repeated hold/jump pattern. The actual GINS/HUD callback
regression reproduces 1degree peak-to-peak FPM motion during a smooth 25deg/s,
constant-AoA maneuver. Requested 10ms publication removes that numerical alias
across three callback phases without filtering or advancing observation times.
Status text retains its 50ms budget; control validity/course state and selected
reference failures remain immediate. The 19:22 player trace contains pitch rates
up to25.6deg/s, consistent with this alias being visible. This establishes a
timing defect, not that it explains every reported gun/FPM movement. 100Hz is a
mod scheduling choice; actual host cadence still needs playtest confirmation.
Bounded 1Hz F22_FPM_STATE diagnostics record original reference time, age range,
pose/velocity and computed/visible gates for that check.
