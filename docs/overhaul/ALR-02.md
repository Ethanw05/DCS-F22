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

ALTITUDE playback confirmation carries its original altitude occurrence ticket, independently of the next selected warning. Invalid/inferred playback cannot mark delivery. The selected repeating radar-low, minima and baro policies are described in NAV-WP09.

Warning power, ACK/test/mute controls and terrain flight inputs now require the
current coherent physical frame from startup. Measured CAS, achieved gear/contact
and one coherent velocity/wind sample replace the pre-provider raw/animation
route. The master caution lamp consumes registry attention directly; missing or
withdrawn registry readiness cannot revive aggregate display flags or animation.
Actual owner regressions reproduce the previous startup bypasses and cover ACK
occurrences, power loss/recovery, unchanged full recordings, live terrain cues,
sticky/unknown playback, and expiry when the warning owner stops. Declared
exogenous physical fixtures qualify the adapter chain separately from DCS audio.

Policy event requests never imply playback. The optional auto-confirm flag is
removed; the sound owner confirms the actual start explicitly. ALTITUDE
confirmation requires its original finite occurrence ticket. Missing tickets
cannot substitute the current event, and a delayed confirmation for an older
crossing cannot consume or rate-limit a newly selected crossing. Before/after
policy tests cover unconfirmed retries, old/missing tickets and confirmed
delivery; actual owner replay/priority/full-recording regressions remain intact.
