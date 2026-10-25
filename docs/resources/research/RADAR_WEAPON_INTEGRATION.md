# PMFD radar state and weapon interlock review

## Current source facts

- `PMFD_System.lua` already dispatched native FC3 `PlaneRadarChangeMode` on its radar OSB and tracked `RADAR_MODE = 0` RWS/`1` TWS, plus `RADAR_PWR`. This is native simulation mode selection, not a self-owned APG-77.
- `Weapon_System.lua` previously relied on gear-down instead of ground contact for several paths, toggled pickle state without guaranteed release on electrical loss, and repeatedly dispatched gun firing every update. The weapon interlock now releases a locally latched pickle command when power, master arm, or WOW is invalid. Gun fire was changed earlier to transition-based dispatch.
- The PMFD radar page previously had static `MODE`, `PRF`, and `POWER` artwork but no honest, source-specific RWS/TWS indication. It now labels **selected** FC3 radar modes and indicates track-data unavailability.

## Technical evidence

Read [DCS cockpit radar API overview](https://modding.caffeinesimulations.com/Aircraft/Lua/Devices/avSimpleRadar/) and its warning: standalone `avSimpleRadar` requires `avSimpleElectricSystem`; this mod's electrical system is still `avLuaDevice`. Adding radar alone will *not* work. That built-in radar has RWS/STT only, **no TWS**. The existing F-15C FC3 integration is preserved rather than replacing it speculatively.

For gunnery/weapon symbology conventions, compare [US Navy T-45 HUD A/G training text](https://navyflightmanuals.tpub.com/P-1219/Hud-Air-To-Ground-Symbology-25.htm); its reticles are **not** the F-22's actual operational attack computer.

## Remaining work

- Actual FC3 lock/track/weapon station readback needs a supported cockpit sensor adapter. Do not present `HUD_RADAR_REQUEST` or `RADAR_MODE` as measured APG-77 modes.
- All shot/WEZ/gun prediction and A/G CCIP/CCRP remain unimplemented and explicitly N/A.
- PMFD and cockpit mode-switch testing is required in DCS before stating these selections are synchronized; currently they share legacy command dispatch semantics.
