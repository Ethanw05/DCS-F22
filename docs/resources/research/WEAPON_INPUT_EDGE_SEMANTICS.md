# Weapons cockpit interface edge handling

The mod's `10026` clickable release button must honor value=1 press and value=0 release, even when it loses power or crosses WOW. The prior toggle-only handling could re-arm a held state if the host dispatched a release event as a second callback. A nil-value legacy event remains a toggle for backwards compatibility.

The bay actuator models accept explicit power availability per door. Ground crew power can move the left bay only, **not** an unpowered main or right bay. Non-released doors retain position without available main power, pending a model of hydraulic accumulators and failures.

No actual F-22 bay rates are claimed; see [weapon bay study](WEAPON_BAY_ACTUATOR_REWRITE.md). State-transition DCS tests remain required.
