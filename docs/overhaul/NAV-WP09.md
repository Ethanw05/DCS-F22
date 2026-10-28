# NAV-WP09 — independent altitude events and advisory protection

The installed ED Hornet guide (24 March2024), p70 was checked directly for the selected warning analogue. Gear-up radar low repeats until explicitly disabled or a valid height resets it. Gear-down minima is a separate one-shot crossing, selectable RADAR/BARO. The existing barometric floor is another occurrence. A100ft crossing rearm and5s unspoken-event expiry are declared mod policies. Existing recordings, duration and gain are preserved.

Altitude_Alerts owns three bounded records with unique finite tickets. Actual voice confirmation carries the original event ticket; playing an older ALTITUDE clip cannot acknowledge another crossing. Master ACK does not disable persistent low. The active UFC ALT DISPLAY disable action uses the WARN11800 transaction and actual warning owner11035: no-current/stale state is rejected, accepted ACK identifies the disabled event. Disable state survives power loss until a qualified height resets it; consumed actions are not replayed.

Manual recovery intent is separate from steering source. Valid received ILS can support the same stable landing exemption with TACAN or WPT steering. Visual intent is explicit. Achieved configuration, valid measured CAS, go-around and received component health qualify the context. The existing terrain solver still rejects the exemption for unstable flight, rising terrain or obstruction; this remains advisory and commands no maneuver. Thresholds are mod policies, not production Raptor protection values.

Actual module/UFC/alert/audio owner tests cover repeat/disable/reset, minima/baro separation, deferred-ticket identity, source loss, event expiry/capacity, gear transit, stale-owner rejection and power restoration. The real WAV replay/priority/expiry and terrain-query regressions pass. DCS approach, obstruction, audio mix and optical checks remain unperformed in this checkout.

Terrain recovery capability consumes qualified FCS health from the same physical
condition catalogue as warning speech. Declared degraded controls retain the
existing estimated 1.5G/30-degree-per-second recovery limits; unknown control
health withdraws terrain prediction (reason4) while independent altitude warnings
continue. The actual warning-owner regression covers healthy, degraded, unknown
and restored controls, including refresh inside the terrain cache interval.
