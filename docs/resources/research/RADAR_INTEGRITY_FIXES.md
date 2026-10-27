# Radar integrity and control corrections — 25 October 2026

This record supersedes the control/data-validity findings in the separate radar accuracy audit. It describes mod policies and software verification, not recovered production F-22 software. The pre-standalone radar/EW audits remain historical records.

## Implemented corrections

- **Fresh STT contract:** the radar owner publishes source ID, original measurement time, geometry, friendly evidence and closure. Scope, HUD and gun-target validity require a fresh native world observation. The HUD also checks timestamp, availability and identity independently, so a stopped Lua producer cannot renew its own data. Raw `F22N_RADAR_STT_*` caches never restore target validity. The 0.5-second limit is an explicit integration policy.
- **Closure:** fresh target velocity and EFM ownship velocity produce relative radial closure. Missing velocity/ownship validity leaves closure unavailable; repeated cached range is not a new velocity measurement.
- **IFF:** automatic interrogation remains enabled by default and has a new unassigned `Identification - Automatic IFF On/Off` binding. Normal manual interrogation accepts new positive replies across the current native search; LOS interrogation accepts new replies within +/-3 degrees of the selected target, or the cursor/elevation reference when no target is selected. Requests last eight seconds to accommodate the generic radar revisit. These are simulation choices. The common native interrogator has one on/off flag; the LOS gate is local reply acceptance, not a claim of a physically narrow native IFF beam. Automatic acceptance resumes after the request if the automatic setting remains on. Existing friendly evidence retains its bounded 30-second memory.
- **Identification:** native enemy/neutral coalition labels no longer create pilot hostile/neutral identification. RF correlation still uses internal host IDs for bookkeeping, but matching an emitter does not prove hostile identity. No NCTR or authenticated hostile-declaration workflow is claimed.
- **Focus:** DMS Down selects radar; DMS Up/Left/Right select their corresponding focus/page. Radar TDC, TMS, range, expand/coverage and slew respect focus. Delayed input actions are cancelled when focus changes. Unsupported focus actions do not silently operate the radar. Dedicated radar/bezel commands remain explicit radar controls.
- **Emission preference:** an explicit radar-off command latches an inhibit. BVR/search/ACM/operate requests cannot silently clear it; deliberate radar-on clears it. Sidewinder/gun selection configures the acquisition pattern without automatically powering the radar. Initial BVR selection may start an uninhibited radar. Electrical supply loss gates operation without changing the pilot's request.

## Evidence and limits

The current native integration already exports `F22_STT_TIME`, `F22_STT_ID`, world position/velocity and `F22_STT_MOTION_VALID`. The corrections use that existing interface and add no proprietary binary dependency or new native patch. They do not change RF detection, native acquisition confirmation or missile-support freshness.

Public descriptions support integrated sensor management, agile AESA operation and passive sensing that can reduce own emissions. They do not specify our IFF timing, gate dimensions, HOTAS mapping or freshness values. Sources reopened for this pass: [Northrop Grumman APG-77](https://www.northropgrumman.com/what-we-do/mission-solutions/radars/an-apg-77-aesa), [BAE ALR-94](https://www.baesystems.com/en-us/product/an-alr-94).

`tests/test_radar_integrity.py` exercises real Lua producer/consumer failures, live stationary observations, ID changes, invalidation, time rewind, power loss, wide/LOS reply acceptance, focus and emission preference. Control-only fixtures now explicitly simulate fresh timestamped native observations. Failure tests deliberately avoid those auto-refresh helpers. Existing tests expecting simulator coalition hostility were changed to require unknown affiliation instead.

The isolated checkout passed all 48 Python/Lua/asset checks. Native DCS flight acceptance of these corrections remains pending. A/G mapping and delivery are being developed separately in the shared checkout; their functionality is outside this record's qualification. Complete APG-77 scheduling, waveform/ECCM behavior, uncertain passive geolocation, combat identification and exact production F-22 controls remain broader work.

## Shared-checkout integration

The combined source also passed all 51 Python/Lua/asset checks, including `test_radar_ag_handoff.py`. A/G HUD focus retains the separate delivery owner's mark/clear actions; radar focus retains ground-map designation. Explicit emission preference survives both A/A and A/G power paths. Entering A/G no longer forces the radar on. Ground-map sensing and bomb-delivery physics themselves are outside this correction's native acceptance. No DCS flight was started for this pass.
