# Electrical availability versus switch state

`Engine_System.lua` formerly wrote `L_GEN_POWER` / `R_GEN_POWER` from generator switch requests, even when engine RPM was insufficient. It also published `MAIN_POWER` one update before the generator model computed its next value.

The device now publishes actual *modeled* generator supply availability (with the separately documented RPM hysteresis) and calculates/publishes `MAIN_POWER` after evaluating operating generators and ground power. This separates requested switch positions from available bus power in the cockpit interface.

[Primary historical integration evidence](https://boeing.mediaroom.com/1998-01-29-Boeing-Begins-Integrating-F-22-Fighters-Advanced-Avionics) confirms an integrated vehicle-management/power-control role, **not** the real electrical bus topology, actual RPM trip settings or complete generator protection.

Remaining: physical battery state-of-charge, true hydraulic/ECS supply, EFM–Lua multiwriter race (C++ initializes `MAIN_POWER`/battery), and in-DCS multi-device scheduling test. See [vehicle audit](../../audit/README.md#retired-report-a08).
