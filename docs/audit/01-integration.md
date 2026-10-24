# 01 — Integration, API, build and input routing

Status: source review complete; DCS integration validation remains open. Baseline and evidence labels are in the [index](README.md).

## Applicable resources

| Reference | Application | Limit |
| --- | --- | --- |
| [R86](../RESOURCES.md#r86), checked-in EFM API headers | Flight-model callback and parameter bridge contracts. | A public template is not a complete supported avionics SDK. |
| [R87](../RESOURCES.md#r87), [R152](../RESOURCES.md#r152) | Independent aircraft registration/device precedents. | Compiled components and reuse restrictions must be accounted for. |
| [R148–R151](../RESOURCES.md#r148) | Candidate radar/weapon devices and historical FC preload/IC issues. | Reproduce capabilities on the chosen DCS build. |
| [R154–R155](../RESOURCES.md#r154) | Separation of mission computation and vehicle management. | Architectural background; not an instruction to emulate physical computer buses in real time. |

## Code scope and findings

Reviewed `entry.lua`, `device_init.lua`, `devices.lua`, `command_defs.lua`, `clickabledata.lua`, keyboard/joystick profiles, both CMake files/presets, EFM headers, `dllmain.cpp` and callback dispatch.

- **INT01 — C:** [entry.lua:64–76](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/entry.lua#L64) supplies our EFM but registers through `MAC_flyable`. Seven custom Lua devices are created; no independent HUD/radar/weapon-core/radio stack is declared. The mod's own `WEAPON_SYSTEM` is an `avLuaDevice` wrapper, not an independent `avSimpleWeaponSystem`. Removing registration is insufficient to retain combat functions.
- **INT02 — C/U:** [ccParametersAPI.h:36–46](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/EFM/include/Cockpit/ccParametersAPI.h#L36) resolves `CockpitBase.dll` exports without checking them. [EDPARAM](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/EFM/include/Cockpit/CockpitAPI_Declare.h#L7) calls those pointers directly, including during static `CockpitManager` initialization. Add an explicit host-interface availability/lifecycle contract later. A missing-export crash was not reproduced.
- **INT03 — C/U:** [RAPTOR.cpp:1276](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/EFM/source/RAPTOR.cpp#L1276) writes draw arguments beyond a caller-provided `size` without consistent bounds checks. The separate cockpit draw helper does check bounds. Unify the policy; current host buffer sizes are unmeasured.
- **INT04 — C:** [Inputs.h:92–95](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/EFM/source/Inputs.h#L92) declares custom autopilot commands, but `ed_fm_set_command` has no cases for them. The corresponding input entries are commented out. This is unfinished functionality, not an active C++ autopilot.
- **INT05 — C/I:** Command numbers are duplicated across C++, `command_defs.lua`, profiles and device-local constants. Clickable and keyboard switches commonly ignore `value` and toggle local state. Distinguish explicit SET, press/release and TOGGLE semantics so synchronization and physical two-position switches work predictably. Confirm DCS delivery/reentrancy before replacing handlers.
- **INT06 — C/I:** The build presets name Ninja but inherited workflows override the generator with Visual Studio; [`CMAKE_BUILD_TYPE`](https://cmake.org/cmake/help/latest/variable/CMAKE_BUILD_TYPE.html) does not select configuration for a multi-configuration generator. `MSVC_RUNTIME_LIBRARY` contains no Debug selection. Record the actual Release/Debug outputs and CRT choices before treating preset labels as proof of release configuration. No Windows build was run in this pass.

## Proposed rewrite and future checks

Keep a narrow adapter for DCS callbacks/devices; define units and ownership on every exchanged field. Maintain explicit command maps and per-aircraft state. Preserve a legacy integration variant while proving standalone registration, radios, native weapon launches and guided engagements. Check every input binding against the intended receiver, including stops/releases and unsupported custom commands. Keep API declarations compatible with the host rather than replacing simulator services.

Future acceptance: clean Windows build with explicit configuration; cold/hot/air start; missing-interface failure logging; bounded draw buffers; all input edges; standalone boot with FC disabled/uninstalled and no base-install edits. The [standalone experiment](../STANDALONE_DESIGN.md#the-decisive-standalone-experiment) remains the decisive dependency test.
