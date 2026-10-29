# Establish native detection before tuning RCS

Keep the production `RCS = 0.0001` unchanged until controlled observations isolate
the problem. Public F-22 accounts do not authenticate a replacement number.
The experimental PEC bake remains research; it has no native signature consumer.

First align the installed registration with committed source. The normal mod's
descriptor still has SHA `ccb122f14e28f17be47e8ef40e8f60ece45b2328d13293934fada3afc409e2f0`;
the committed descriptor is `8cec308d388fc1c8c04d232c0ca736c3634ad118e2cd30ae0709bb8db989ac8c`.
The complete difference is three `WSTYPE_PLACEHOLDER` registration fields from
commit `d6304f7`. Both use RCS 0.0001. Installation-only coordination is requested;
no installed file, hook, DLL or simulator was changed by preparation of this suite.
Actual AI consequences of the registration correction are still unobserved.

## Matched trials

`tools/build_signature_comparison.py --output <new external directory>` creates
four missions: `sp-hornet`, `sp-f22`, `mp-hornet` and `mp-f22`. Each contains the
same route and twenty Excellent threats: four each of Tor, Osa, Tunguska,
Strela-10M3 and optical ZU-23. Alarm is RED and ROE WEAPON_FREE. Aircraft start
at 1,500 m MSL, about 4,921 ft, at 200 m/s; actual terrain clearance/visibility
and flown geometry require observation. Only one player/client slot is present
per mission to avoid another aircraft cueing the defenders.

1. Verify installed files and restart DCS after descriptor changes. For MP,
   restart the dedicated server and participating clients with matching files.
2. Fly the clean Hornet control and clean F-22 on the same route, altitude and
   speed. Keep ECM off and record that state; the mission does not force pilot
   controls. Stores, ammunition, flares and chaff are absent in these missions.
3. Use a fresh mission for every pass, initially with F-22 bays closed. Do not
   respawn into a mission whose defenders already hold contact memory. Repeat
   before treating a single first-report distance as representative.
4. Repeat F-22 passes with the existing bay override, verifying actual argument
   movement in the log. A request or a successful read returning zero does not
   prove supported bay state or its radar effect. Hornet bay arguments do not
   represent F-22 doors. No dynamic signature connection is added by this trial.
5. If required to distinguish numeric RCS from other F-22 behavior, use a
   temporary **5 m² diagnostic control**, matching the Hornet baseline. A
   source-checked patch is prepared externally. It is not applied and is not a
   proposed realistic F-22 value. Restore the original declaration and restart
   after that comparison; do not retain the diagnostic value as a gameplay fix.
6. Repeat the relevant controls using the MP client slots and collect the
   **server's** log, with a remote client when available. Preparing client slots
   is not proof of multiplayer replication or effects.

## Evidence and interpretation

The schema-2 observer records native RADAR, VISUAL, OPTIC and IRST target-list
reports, current radar target, missile shots and available gun-burst start/end
events independently. It reads ownship native type, position and draw arguments
600/601/602, 0/3/5 and 22. Valid slant ranges are in metres; zero is a valid
distance and missing/failed/nonfinite readings have separate invalid flags.
The optional existing export observer supplies jammer-state evidence; it is not
installed by the builder. The mission-side script is sufficient for threat
observations and does not require a cockpit hook.

Run `tools/diagnostics/summarize_signature_trial.py <dcs.log> --output <new.json>`
to separate first positive reports, first current radar target, minimum recorded
slant distance, shots with known/unknown target attribution, and gun bursts.
Separate schema headers keep runs independent. Contact-list membership can
include remembered targets; the summary is not a calibrated detection boundary.
Sampling is once per second for at most 600 samples, 64 groups, 16 units per
group and 128 observed units per sample. Fire records cap at 1,024 with an explicit
overflow marker. Missing gun-event APIs cannot establish an absence of gunfire.

| Observed result | Next investigation |
| --- | --- |
| Both aircraft are ignored | Mission/AI readiness, actual visibility, geometry and logging support. |
| F-22 at 5 m² remains unlike the Hornet | Loaded registration, native target identity and other signature properties; RCS alone is not isolated as the cause. |
| F-22 radar behavior approaches the Hornet only at 5 m² | The RCS input materially affects detection. This does not authenticate a realistic F-22 baseline. |
| SP works but server/remote-client results differ | Server/client identities, state replication and native consumers. |

IR signature settings differ between the aircraft. A radar-RCS control does not
normalize IR detection. RWR silence alone is not a detection or engagement test.
Only after this baseline should numerical gameplay estimates be selected and a
qualified per-aircraft native RCS backend pursued. Dynamic MP RCS remains open.
