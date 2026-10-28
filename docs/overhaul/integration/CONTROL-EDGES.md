# Retained cockpit command semantics

Saved IDs and default binding identities stay unchanged. Command 10017 is the
maintained/held day/night selection: 1 selects night and 0 selects day. The
physical two-position Button_8 uses the same absolute position. Invalid values
do not alter the preference. Command 10018 is the existing down-only toggle
impulse: a positive press toggles once and a release value does nothing. It
cannot require an up callback that old saved bindings never supplied. Actual
host repeat delivery and saved-diff import remain DCS qualification gates.

SMFD swap buttons retain their existing command IDs and the owner's per-command
press latch. Both physical mouse declarations now request a matching release.
Repeated down while held is ignored; up permits a new cycle. Post-initialization
clears these transport latches, while ordinary power loss does not replay input
or rewrite the day/night preference. Native mouse/up callback and VR presentation
still require the applicable runtime evidence.
