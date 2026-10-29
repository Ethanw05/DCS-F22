# Optional voice CNI: selected off

P-NAV-004 / R-NAV-005 decision for `public_f22_manual_recovery@1`:
`clear_voice_backend=false` remains deliberate. The selected player profile
requires received TACAN/ILS/manual recovery; this decision does not disable them.

There is no qualified owned dual-radio device, accepted/achieved frequency and
preset chain, RX/TX/audio observation, monitor/guard path, or bounded PTT owner.
Native receiver getters, exported functions and the simulator communications
menu do not establish such a backend. No optional voice capability is selected
until these effects and lifecycle/teardown are demonstrated on the supported host.
This is the explicit no-go disposition allowed by the package, rather than a
claim that a second voice radio or secure/hopping equipment exists.

Retained cockpit behavior is COM1's `COMMS MENU`, dispatching host command179 on
option selection, and COM2's `RADIO 2 UNAVAILABLE`. Opening COM1 does not transmit
or tune an owned radio. The mod creates no PTT request, lease or replay queue in
these pages. Host-menu radio actions belong to DCS and are not qualified here.
Lost power closes the UFC page; restart clears the draft/page state. Page changes
and power restoration do not replay a prior menu selection. Mouse press/release
ownership and existing down-only keyboard aliases remain distinct and unchanged.

The actual ICP transport now rejects nonfinite, wrong-type, fractional/unknown
command events before touching button latches. Its existing57-command range is
fixed, and six bounded interval checks prevent arbitrary latch-table growth.
Parameter handles are cached per device instead of looked up repeatedly at6ms.
No saved command ID, binding, native radio registration or recorded audio changes.

Seven independent tests execute actual ICP_System/UFC_Controller/Equipment_Profile
modules. They cover selected-off policy, COM1 menu dispatch, COM2 feedback, encoded
mouse edges, keyboard impulses, power/restart/page changes and malformed events.
They do not establish actual DCS menu operation, RF reception, transmission or
audio. Native ident and receiver callback drain remain P-NAV-003 work.

No legacy artifact is solely an optional voice implementation test. The legacy
common-UFC/display tests remain quarantined pending their broader P-NAV-002/008
remake; the native navigation-audio artifact remains assigned to the still-open
ident/lifetime work. Neither is used as an acceptance oracle for this decision.
