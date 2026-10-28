# Playable two-way EW trial

`tools/build_ew_trial.py` creates `F22-EW-Duel.miz` in the normal Saved Games
Missions directory, from the existing playable F-22 A/A mission. It uses an
airborne F-22, an unarmed F-15C65km ahead, and a Buk search/track site near
Kobuleti. Aircraft damage is enabled. The SAM initially holds fire; live fire
is an explicit radio-menu option. No mod input bindings are changed.

Fly approximately103deg TRUE at33,000ft. The briefing and timed messages guide
the run:45s clean baseline,45s own-ECM ON,45s own-ECM OFF/recovery, enemy ECM
ON at135s, OFF at180s, ON at225s, OFF/freeplay at270s. The pilot controls their
own ECM through Radio menu -> F10 Other -> EW Trial -> Toggle YOUR ECM.
The same menu can override enemy ECM or enable SAM live fire.

`F22EWTrialMission.lua` logs mission-only truth, commanded enemy ECM, geometry,
enemy radar emission/lock/detection/range-known states, and shot/hit/end events
to dcs.log. AI options use runtime enum names; successful dispatch is not
called proof of radiation. Mission work is bounded to1200 one-second samples
and2000 selected events. Radar API errors are logged as errors.

The mission-scoped `F22EWTrialHook.lua` selects BVR/RWS and bridges explicit
pilot radio-menu toggle requests to the existing EW device. It observes native
host ECM enabled status and an export jamming flag if supplied. It never edits
native memory, changes sensing truth, auto-fires weapons, or treats enabled as
independent RF transmission proof. It is inert outside this exact mission and
limits observations to6000. Hooks need a DCS start to load; the normal session
started21:00 on Oct27 after the installed hook's20:59 modification.

The owned radar's existing telemetry records receiver J/N, qualification,
tracks, raw/filtered measurements, observation time and uncertainty. It remains
separate from the mission truth logger. The incoming noise model's documented
estimates/limits still apply. Native outgoing effects and radar reactions are
flight observations to qualify, not assumed successes.

`tools/analyze_ew_trial.py --watch` archives the relevant evidence and updates
JSON/Markdown results every10s, stops when the trial ends or its log rotates,
and has a four-hour waiting limit. It never controls DCS. The report retains raw
enemy-radar records and notes missing phases, geometry differences and lack of
independent outgoing RF proof. A command or a light alone cannot pass the test.

Mission generation/parsing and both Lua scripts pass local syntax checks. No
EW flight result exists yet. The ground MAP collection/cache regression was
fixed and installed separately; actual moving-video acceptance remains open.
