# ALR-02 — bounded audio authority

Seeker audio now consumes expiring pilot and MWS leases instead of raw priority.
Both use model-time seconds, reject stale/future leases longer than four seconds,
and normalize boolean/numeric 0/1 playback status. The weapons owner supplies the
MWS lease only while playback is confirmed. A stopped warning owner cannot
indefinitely suppress the seeker.

An accepted playback call with unavailable status retains only a bounded,
known-duration slot. It does not mark the real event delivered or publish confirmed
voice authority. `F22_PILOT_AUDIO_STATUS_VALID/INFERRED` distinguishes that path.
A test sequence can advance through requested clips with unknown status without
claiming successful audible BIT. Real events retry under the bounded retry policy;
confirmed playback alone commits delivery/repetition accounting.

The chosen policy completes the current recording before speaking the latest
still-relevant directive; a real event cancels the test sequence. Maximum shipped
clip length plus the retained 0.15 s margin and 0.05 s owner interval bounds an
occupied slot. A provisional 2.5 s urgent-event budget includes debounce; it is a
game policy, not F-22 timing. Current cues update independently of voice completion.
Global voice inhibit and volume remain deliberate pilot settings.

Original WAV samples, gain and measured durations remain unchanged. Existing
recording-length/replay/sticky-status tests pass. Additional tests cover unknown
status without false delivery, confirmed restoration and lease expiry; actual
native perceived mix and radio/intercom arbitration remain unqualified.
