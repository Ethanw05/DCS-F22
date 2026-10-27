# User-recorded warning voice checkpoint

The user recorded and processed four original warning phrases in FL Studio.
The NAV/audio owner mapped Playlist Tracks 1–4 to TERRAIN, PULL UP, ROLL RIGHT
and ROLL LEFT and supplied frozen canonical mono 16-bit PCM 44,100 Hz files.
Only extraneous RIFF chunks were removed; samples, processing and levels are
preserved. Existing sound definitions retain gain 1.0. Other warning voices
are unchanged.

| Runtime name | Measured duration, seconds |
| --- | ---: |
| terrain | 1.149047619 |
| pull_up | 1.850952381 |
| roll_right | 1.418276644 |
| roll_left | 1.418276644 |

Source integration replaces these four WAVs under
Sounds/Effects/Aircrafts/F-22A/Warnings and changes only their four entries in
Cockpit/Scripts/Systems/Pilot_Warning_System.lua's duration table. The 0.15 s
playback margin, warning detection, recovery logic, priorities and gain policy
are unchanged. Accurate timing matters: the new PULL UP is longer than the
old 1.48 s duration and must not be cut by the old deadline.

All 92 current source checks pass. test_warning_voice_timing.py uses the actual
warning owner and the actual clip duration to verify playback persists through
the final sample and then clears after its completion margin. It also checks
the four WAV formats.

Five-file source hashes and read-only installed comparisons are recorded in
fi/work/hornet-warning-research/user-voice-manifest.json. Frozen deployment
copies are in fi/work/hornet-warning-research/user-voice-release. At handoff,
0/5 installed files match this voice checkpoint: the installed game retains
the preceding native-tested warning package. The stores owner has the next
runtime slot; no mid-session copy or eval is authorized for this voice lane.

**Installation update — 26 October:** The user explicitly requested installing
their recordings. A fresh zero-DCS-process check preceded a five-file copy;
all five installed hashes now match the frozen package. Previous files are
backed up under fi/work/hornet-warning-research/voice-install-20261026T063107Z.
The receipt is user-voice-installed.json in that research work directory.
The full-clip timing regression and actual warning-owner checks pass after
installation. No DCS session was launched and no native audition is claimed.

Install all five files coherently at a closed-game checkpoint. Verify hashes,
then use the pilot-warning test sequence to check all four new clips and their
timing. Their perceived cockpit mix remains an audio acceptance item; file
format and owner timing tests do not establish perceived loudness. The prior
warning-run01 native results used the previous generated voices and must not
be presented as native playback acceptance of these user recordings.
