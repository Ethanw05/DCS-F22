# 05 — Engines and FADEC approximation

## Applicable resources

| Reference | Application | Limit |
| --- | --- | --- |
| [R25](../RESOURCES.md#r25), [R81](../RESOURCES.md#r81), [R129](../RESOURCES.md#r129) | F119 architecture, propulsion development, installed inlet/nozzle integration. | No public complete installed thrust, fuel-flow or transient deck. |
| [R168](../RESOURCES.md#r168), [R169](../RESOURCES.md#r169) | Airframe/engine coupling and independently controlled nozzle quantities. | Reviews and another nozzle-control study; not production F119 schedules. |
| [R131](../RESOURCES.md#r131), [R153](../RESOURCES.md#r153) | Broad performance and demonstration cross-checks. | Demonstration conditions and headline specifications cannot calibrate an engine map alone. |

## Code scope and findings

Reviewed the two engine state machines, thrust/fuel tables, spool timers, temperature expressions, damage scaling, EFM exports and Lua throttle/start controls.

- **ENG01 — C:** [The bundled API contract](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/EFM/include/FM/wHumanCustomPhysicsAPI.h#L399) defines RPM as revolutions/minute and related RPM as a fraction of maximum. [Exports](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/EFM/source/RAPTOR.cpp#L1546) instead return throttle input for core RPM and approximately 0–1.1 for fan RPM. Related fan RPM is power readout multiplied by 0.35. Define actual shaft-speed states and explicit conversions; verify which DCS sounds, instruments and AI consumers use each export. Engine block 0 is correctly reserved for the APU; engines 1/2 are not an indexing error.
- **ENG02 — C:** Combustion exports return engine integrity. A healthy, stopped engine therefore reports 1 even when its combustion state is off. Separate hardware health from combustion, spool speed, thrust and exhaust effects. The downstream DCS consequence remains a runtime question.
- **ENG03 — C/I:** [Thrust selection](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/EFM/source/RAPTOR.cpp#L662) switches between ground static constants and Mach tables, then scales linearly with density. The ground flag is a gear/height/Mach heuristic, so crossing it can change the thrust model while still airborne. Use one continuous installed-engine approximation over Mach, atmospheric state and power; retain uncertainty where no deck is available.
- **ENG04 — C/I:** Temperature is a cubic of displayed power plus atmosphere temperature. Displayed power is also multiplied by integrity after engine-state evaluation. Neither gives an independent thermal state, hot-start behavior or a physically defined spool/health relationship. Document current proxies instead of interpreting their outputs as measured F119 values.
- **ENG05 — C:** [Lua start inhibition](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/Cockpit/Scripts/Systems/Engine_System.lua#L271) sends a stop command when APU conditions are unsuitable, whereas EFM start permission is based on its own conditions. Two listeners can disagree during a command. Use one authoritative start-permission/state transition and expose it to the cockpit.
- **ENG06 — C:** The common throttle animation handles both cutoffs open or both closed, but lacks the mixed-cutoff case; a common-axis input can leave the live engine's lever animation stale. Separate engine input, lever position, cutoff state and requested power for each side.
- **ENG07 — C/I:** EFM APU exports are all zero while Lua maintains an APU animation/timer. Engine shutdown at low internal fuel does not establish a modeled external-to-internal transfer system. Fuel and vehicle-system rewrites must share the same engine state and supply contract.

## Proposed rewrite and future acceptance

Retain a deliberately approximate two-engine model with explicit units, shaft states, combustion, thermal response, installed net thrust, fuel demand and nozzle states. Do not fill missing F119 data with Chinese studies of unnamed engines or headline thrust ratings presented as a full map.

Later checks should cover cold/hot/air starts, independent cutoffs, interrupted starts, asymmetric damage, flameout/relight, dry/afterburning transitions, ground-flag crossings, timestep changes and consistent cockpit/API/sound values. Validate steady performance at documented mass/altitude/configuration before adjusting transients. No engine parameters changed in this review.
