# ARC-01 — shared capability selection

`Systems/Equipment_Profile.lua` is the shared selected profile
`public_f22_manual_recovery`, revision 1. Navigation/receiver families and manual
field recovery are selected. The AFCS substitute is explicitly Hornet-derived;
its controller gains, input thresholds and source envelopes remain mod estimates.
The historical 12-degree approach centre is retained; production scheduling and
11.5/12.5-degree cue edges are not authenticated by tests.

Targeting pod, HMD, IRDS, carrier ACLS, autoland, automatic GCAS, additional weapons
and diagnostic weapon-truth fallbacks are not selected. The weapons owner retains
CLSID registrations for compatibility while inhibiting unsupported employment;
registration presence alone is not an enabled capability. Radar now uses the
owned AESA sensor and guarded scene/weapon adapters described in
[SEN-02](SEN-02-owned-aesa.md); its numerical policies and runtime limits remain
explicit.

Clear-voice backend support remains false. COMMS MENU remains a menu action,
not PTT or proof of tune/RX/TX. Common DLL radio symbols and reference Lua are
research leads; constructor/factory, lifecycle, achieved tuning, audible reception
and deliberate transmission need their own complete proof before controls are
enabled. No secure waveform, real keying procedure or universal modern fleet fit
is claimed. Brower (2001), §32.4 establishes historical UHF/TACAN/ILS/identification
recovery roles; software reconfiguration does not generate physical power.
