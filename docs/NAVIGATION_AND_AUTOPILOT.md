# F-22 Standalone Mod - User Manual

Edition 2 | Navigation/cockpit integration | 27 October 2026

This describes the selected simulation profile. Owner tests and actual DCS observations qualify different things; the new reference, altitude and recovery interfaces still require cockpit/flight qualification.


## 3  Understand the navigation HUD

A waypoint is a route point until you deliberately designate it as a target. Normal WYPT navigation supplies a command-heading stroke on the compass, distance and W-number, plus time-to-go when ground speed is usable. It does not put an enemy-like box or target diamond over every route point.

*Ordinary waypoint: compass steering and W2 distance; no ground target diamond.*

WPDSG changes the selected waypoint into a terrain-backed ground designation. The compass steering symbol becomes a small diamond and the HUD shows a conformal ground diamond when the target is inside the glass. An edge locator indicates an offscreen designated target. The readout changes to TGT.

*After WPDSG: the separate ground diamond appears and the range reads TGT.*

This distinction follows the DCS Hornet reference. The selected-heading bracket is an AFCS heading reference, separate from waypoint steering. Off-scale navigation steering is clamped at the compass edge. A course-steering arrow and 4/8-degree references appear with selected OBS/course steering around the velocity vector.

## 4  NAV format and route control

| Bezel control | Result |
| --- | --- |
| NEXT / PREV | Select the next or previous route point. |
| RNG+ / RNG- | Increase or decrease map range. |
| MAN / AUTO | Toggle optional waypoint sequencing. |
| WYPT / TGT | Select waypoint steering; return from target designation to ordinary WYPT. |
| TCN / ILS | Choose radio-navigation source. |
| WPDSG / UNDES | Explicitly designate the selected waypoint as a ground target, or clear the target. |
| D-TO | Create a direct course from current position to the selected point. |
| DATA | Open ICP steerpoint data entry. |
| CRS | Open ICP CNI course entry. |
| MENU / ADI | Return to the menu or select the attitude format. |

The heading-up compass shows bearing, course and selected-heading cues. Route legs are blue; the active leg and selected point are green. The data block gives bearing, distance, altitude reference, time-to-go and cross-track error. The CDI moves toward the desired course. Route/OBS full-scale displacement is 2 NM.

Steerpoint altitude is flight-plan data. It is not an automatic climb/descent command. NAV coupling controls the lateral track; your selected AFCS pitch mode controls height or vertical speed. WPDSG uses terrain height for the ground target, rather than the route point's planned flight altitude.

AUTO advances through the route according to the navigation computer's arrival logic and stops at the final point. NEXT/PREV, point selection and route edits preserve your AUTO/MAN preference. A target designation suspends automatic sequencing; UNDESG resumes it when AUTO remains selected. Manual selection or route edits cancel that navigation designation. The capture policy is fly-over: within 0.3 NM, or passed along-track within the bounded nearby corridor; it does not anticipate a turn. Markpoints and edits persist within the current mission, not across a DCS restart.

## 5  CNI: tune a radio or select a course

Press ICP NAV to open the CNI page. Press it again to close. Each row shares one left edge; the separate right-side chevron marks the field selected for entry. Select a numeric row, enter digits, then press that same option again. ENTERED means its actual owner accepted the transaction; NO RESPONSE or OWNER REJECTED leaves an error. Entry alone never engages a flight mode.

*CNI labels have no selection padding. The marker does not move the label.*

| Option | Operation |
| --- | --- |
| OP1: TACAN | Enter channel 1-126. Example: select OP1, enter 1, 6, then OP1 again requests channel16. |
| OP2: ILS | Select OP2, enter 1, 1, 0, 3, 0, then OP2 again requests110.30. Six-digit kHz is also accepted. |
| OP3: CRS | Enter000–359 degrees and confirm the same row. This enables OBS course steering. |
| OP4: BAND | Toggle TACAN X/Y. |
| OP5: MODE | With no numeric entry, cycle TACAN mode. |
| Rocker UP/DOWN | Toggle NAV and NAV SETUP while no entry is pending. |
| CLR / UNDO | Backspace; clear the entry or close when empty. |

TACAN modes are OFF, REC, T/R, A/A REC and A/A T/R. REC provides bearing when available; T/R adds range. Ground T/R has been tested. Air-to-air modes are native receiver requests and have not been flight qualified.

Switch reference with Navigation Reference - True / Magnetic. T and M suffixes identify the active reference. The world magnetic model supplies variation. Radio bearing is converted consistently before AFCS coupling. Resume Route Leg exits manual OBS/course steering. After retuning or changing source, wait for valid guidance before selecting NAV coupling; signal loss disengages it.

## 6  Edit a steerpoint or store a mark

Press ICP STPT, or NAV format DATA. OP1 selects ID, OP2 latitude, OP3 longitude and OP4 altitude. The entry is held as a transaction until STORE, so a partial coordinate does not move the live waypoint.

| Field | Entry convention |
| --- | --- |
| ID | An existing selectable point, or a new positive ID. |
| Latitude | DD MM.mmm without punctuation: 4136840 means 41 degrees 36.840 minutes. Seven digits. |
| Longitude | DDD MM.mmm without punctuation: 04135484 means 041 degrees 35.484 minutes. Eight digits. |
| Altitude | Feet MSL. This field is route data, not a ground-target elevation. |
| Hemisphere | Rocker DOWN toggles N/S or E/W for the selected coordinate. |
| Next field | Rocker UP advances to the next field. |
| STORE | OP5 commits a complete valid transaction. |
| CLR / UNDO | Backspace or cancel the edit. The separate Undo Last Coordinate Edit or Markpoint binding reverses one committed change. |
| MRK | Capture a valid ownship position in the independent nine-slot mark bank. |

Select a field to commit its current buffer before moving on. Latitude must remain within 90 degrees and longitude within 180 degrees, with valid minutes. Invalid or incomplete input remains an error rather than silently creating a target at zero coordinates.

The public DCS terrain conversion connects geographic entry to map coordinates. Mark storage does not change the route, steer to the mark or designate a weapon target. NAV SETUP → MARK/TIME exposes capture, selection and explicit mark direct-to. Direct-to uses a frozen mark snapshot; overwriting that bank slot does not move the active destination. UTC timing needs an explicit pilot time reference and remains separate from A/T.

NAV SETUP → GINS REFERENCES selects independent NAV/HUD/right-SFG sources. The simulated references share healthy host observations and have independent declared failures and estimates. Normal480s, retained-heading90s and explicit TRAINING30s alignment are estimates. Movement rejects incomplete alignment; retained heading needs prior valid memory and unchanged position/heading. Hot/air starts begin aligned. GPS loss coasts with an illustrative uncertainty budget; restoration corrects with a bounded slew. Production drift rates, satellite geometry, jamming and spoofing are not recovered.

## 7  Autopilot modes and selected targets

The AFCS is an independent conventional relief controller in this mod's flight model. Read the displayed AP roll and pitch modes after every selection. These are mod controller policies and gains, with the source and runtime limits recorded in docs/overhaul/NAV-WP07.md.

| Mode | What it holds |
| --- | --- |
| ATT | Captures pitch and bank. It does not guarantee level flight or constant altitude. |
| ALT | Captures current indicated pressure altitude from the accepted QNH/STD source. Selected-altitude bindings adjust the target in 100 ft steps. |
| HDG | Steers toward selected heading, with up to 30 degrees commanded bank; retains the existing pitch mode. |
| NAV | Steers the selected waypoint/OBS or TACAN track. Requires fresh valid guidance and retains the pitch mode. |
| RALT | Captures current height above the surface; available from about 200 to 5,000 ft AGL with bank within 45 degrees. |
| V/S | Captures vertical speed; adjust in 100 ft/min steps. |
| CAS A/T | Captures calibrated airspeed; adjust in 5 kt steps. |
| Mach A/T | Captures Mach; adjust in 0.01 Mach steps. |

ALT, RALT and V/S are pitch choices; ATT, HDG and NAV are lateral choices. They are not a menu of automatic route descents. HDG or NAV selected with AP off leaves pitch manual. A healthy existing vertical mode is retained. Use Sync Current Heading before selecting HDG if you want to prevent an unexpected turn toward an old heading target.

Autothrottle operates independently of the pitch/roll autopilot. CAS and Mach targets have distinct readback and independent stepping. Monitor the selected A/T state after changing a mode. A/T has bounded throttle authority and finite engine response; monitor speed during climbs, descents and transients.

## 8  Engage, take over, and diagnose AFCS

- Stabilize the aircraft. Require gear up, airborne, healthy flight controls and modeled main power. Minimum engagement speed is 160 KCAS; pitch must be under 45 degrees, bank under 70 degrees and angle of attack under 20 degrees.
- Choose a valid navigation source first. A TACAN retune needs acquisition time; cold receiver warmup is five seconds. Engage NAV only after guidance is valid.
- Select the pitch/lateral hold you want, then verify AP status. Adjust the selected heading, altitude, V/S or speed through the named bindings.
- The ordinary paddle disconnects AP and A/T under the selected mod takeover policy. The separately named held override/recapture binding remains an explicit mod option; it does not redefine the ordinary paddle.
- Pitch input releases the vertical mode. In CPL, roll input above about18 percent temporarily overrides lateral control and resumes below about12 percent. Trim commands disengage flight AP. Move either throttle by about eight percent to cancel A/T. These are normalized game-input thresholds, not physical forces.
- Combined Disengage turns off AP and A/T. Electrical loss, gear/ground/envelope violations or flight-control damage inhibit/disconnect the applicable functions. NAV loss disconnects lateral flight AP; restoration does not silently reengage it.

| Status | Meaning / action |
| --- | --- |
| ENGAGE INHIBIT | Check speed, gear, attitude, health and selected-source validity. |
| ENVELOPE / POWER | Take over; restore appropriate aircraft condition before reengaging. |
| PILOT OVERRIDE | Manual stick or trim disconnected AP. |
| NAV LOST | Guidance failed or became stale. Retune/restore the source, then explicitly reengage. |
| VERTICAL SOURCE LOST / HEADING LOST | The selected measurement/reference failed. Restore it, acknowledge the loss and deliberately reengage. |
| LIMIT | The controller reached its modeled output bound. |

RALT follows sensed height beneath the aircraft and has no terrain look-ahead. It is not a terrain-following or obstacle-avoidance system. ILS is advisory: the AP does not capture the localizer/glideslope, fly an automatic approach or autoland. Pitch and throttle relief modes also do not substitute for managing energy.

## 9  Radio approach practice

Use F-22A - Batumi ILS and TACAN. It begins approximately 10 NM northwest of runway 13, aligned with the 125.6-degree true inbound direction at about 3,280 ft MSL. Batumi ILS is 110.30 MHz (ILU); TACAN is 16X (BTM). Verify the facility in the current DCS map before descent.

- On ICP CNI, enter TACAN 16, set X and T/R. Select TCN on NAV and confirm bearing/range.
- Set ILS 11030 through OP2. Enter about 126 degrees in true reference, or the corresponding magnetic course using the displayed variation/reference. The selected course is a steering aid; it does not tune the ILS beam.
- Select ILS on NAV to acquire approach indications before lowering the gear. With gear fully down, received ILS guidance is also displayed with TCN or WYPT steering, including if A/G master mode remains selected. Confirm independent localizer and glideslope indications. An absent channel is hidden separately. TACAN supplies bearing/range; its channel does not tune an ILS frequency.
- Fly toward the bars. They are referenced to the HUD velocity vector, with corresponding NAV-format deviations. Positive native GS error means high, so its displayed bar moves down.
- Maintain appropriate approach speed/configuration and hand fly capture/descent. Disengage relief modes as required. A localizer signal alone does not establish glideslope availability.
- If indications vanish, identify the loss and use an appropriate missed approach in the simulator. No automatic go-around or automatic landing is implemented.

The common DCS receiver uses facility radio signals, not a fabricated waypoint-to-runway line. Conventional display sensitivities are +/-2.5 degrees localizer and +/-0.7 degrees glideslope, with saturation at full scale. Installation beam widths may vary. This display calibration is a mod convention, not a certified instrument specification.

`F22_NAV_STATE` in `dcs.log` records AUTO preference, sequencing hold reason, active point, sequence count, ground speed, distance/along-track/cross-track, native receiver status, ILS frequency/validity/raw deviations and HUD approach/gear state once per second and at each automatic advance. Hold codes: 0 ready, 1 MAN, 2 target designation, 3 missing velocity, 4 low speed, 5 no route, 6 unavailable ownship, 7 final point reached. See the [NAV/landing fix evidence](resources/research/NAV_LANDING_FIXES_2026-10-26.md).

For a cold start, use battery/APU and engine/generator controls, establish main power, and remain stationary for IRS alignment. This edition gives navigation start requirements rather than a full engine-start checklist. A healthy declared DC-powered reference can retain its estimate when main display power is lost. Longer reference power loss requires ground alignment in the core profile; no automatic airborne realignment is provided.

## 10  Altitude and manual recovery selection

The ALT rocker opens ALT DISPLAY: select BARO, RDR or STBY. RDR falls back to barometric height with BARO FB; STBY is explicit and shows unavailable rather than silently switching sources. Primary ADC, generic standby pressure and radar height have separate validity. The standby shares atmospheric truth and the selected pressure setting, with an independent declared failure. Five-second pressure confirmation and the high/fast-to-low/slow redisplay are Hornet-derived presentation choices.

ALT DISPLAY also sets separate landing minima and disables a currently active radar-low warning through its actual owner. Radar-low repeats; master ACK does not disable it. A valid climb above the low index resets it. Minima and barometric floor crossings use separate event identities. RECOVERY selects NONE/ILS/VISUAL manual intent independently of steering. It reports localizer-only, approach, go-around, touchdown or unavailable; it commands no automatic maneuver. Terrain/obstruction protection remains advisory and is not autoland or automatic GCAS.

The contextual cage binding routes NAV presses only to the flight-path marker and weapon-mode presses only to the seeker. A caged FPM retains a compact uncaged ghost when visible. FPM LIMIT means the computed vector is off-glass; missing reference data is a separate indication. Existing font, green, projection and recordings are retained; new cue placement still requires cockpit/VR qualification.
