# NAV-WP01/02/05 — quantities and independent references

| Quantity | Owner / contract |
| --- | --- |
| Physics truth, achieved configuration, air data | Aircraft EFM; physical snapshots require validity/generation/stamp checks. `EFM_PHYSICAL_CLOCK_KIND=1` is spawn-relative EFM seconds, equal to `F22_AP_CLOCK`, not World model time. |
| Navigation position | Navigation_System / INS_Model; world x=north, y=east and altitude MSL metres. A position-invalid estimate never publishes host coordinates as a valid fix. |
| Attitude / heading reference | Checked independent host observations; `F22_NAV_ATTITUDE_VALID` and `F22_NAV_HEADING_VALID` are separate from estimated position. They are simulator approximations, not recovered F-22 channel redundancy. |
| GPS observation vs selection | `F22_GPS_OBSERVATION_VALID/TIME` is distinct from `F22_GPS_AID`. The declared GPS failure fixture can remove observations while healthy velocity coasts. Enabling aiding alone is not an observation. |
| Navigation quality | Position/heading uncertainty are estimated budgets; last positive-position age is separate. GPS correction is bounded. No production drift or 90-minute automatic disconnect is claimed. |
| Course / heading | Native selected heading is true degrees. `F22_NAV_COURSE_TRUE` is canonical true degrees; display true/magnetic changes preserve its physical path. Missing variation rejects magnetic entry rather than assuming zero. |
| Radio bearings / height | TACAN native magnetic bearing radians / range metres; LOC/GS independently valid. ILS sensitivity and signs retain the checked native convention. Pressure, radar and geometric heights remain separate. |

The UFC NAV SETUP quality page displays validity, estimated uncertainty and last
fix age. Radio DATA and received ILS remain independent of missing GINS position.
Host observation calls are protected and checked; invalid attitude withdraws
position-dependent HUD projection without destroying a healthy position estimate.
The pose/estimate input buffers are reused at the owner rate.

Brower (2001), §§32.3.3/32.3.6/32.4 establishes the historical GPS/TACAN/ILS,
ring-laser IRS and recovery families. The installed ED Hornet guide supplies
display/entry analogues. Independent normal/retained/training GINS behavior is
recorded in [NAV-WP02](NAV-WP02.md); the former automatic 30-second airborne
convenience is removed. Angular TACAN CDI and received-component admission are
recorded in [NAV-WP05](NAV-WP05.md). Station-specific course datum/ident audio
remain open.
No missing native field is treated as proof that host receiver audio is absent.

Actual Lua tests cover GINS position loss with retained TACAN/ILS, GPS observation
loss/coast, independent heading/attitude failure, reference invariance, malformed
and signed elevation entry, and receiver/source restoration. Native receiver
requalification and the aircraft provider integration are separate exit gates.
