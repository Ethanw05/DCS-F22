# Removing the F-15C dependency: implementation follow-up

Research/code inspection: 24 October 2026. **The dependency is still present.** The experimental replacement physics is independent C++, but `entry.lua` still registers the normal aircraft through `MAC_flyable`. Changing that one call would remove services the present cockpit uses; it would not create a complete standalone fighter.

This extends [STANDALONE_DESIGN.md](STANDALONE_DESIGN.md) with additional first-person combat-mod precedents and a concrete migration inventory. No other mod's code, DLL or assets were copied.

## Additional precedents

| Project / inspected evidence | What it establishes | What it does not establish |
| --- | --- | --- |
| Community A-4E-C, commit `34c1ef439581234ee24d4bde2e13a54999ebaa5a`: `A-4E-C/entry.lua`, `Cockpit/Scripts/device_init.lua`, `RADAR/apg53a.lua` | Independent `make_flyable` registration; explicit simple electrical/weapon/RWR devices; custom indicators/radio links. Radar script includes terrain sampling and a C++-radar option. [R87](RESOURCES.md#r87). | Its APG-53A terrain/ground radar is not evidence for an airborne AESA or concurrent AIM-120 support. Not all compiled components are thereby available as reusable source. |
| A-29B, commit `1f632f004e28ef13a5f3404528de4c3fc982a0e2`: `Cockpit/Scripts/device_init.lua` | Explicit custom HUD/MFD/systems, simple electrical device and `avSimplest*` weapon/radio/FLIR interfaces. [R152](RESOURCES.md#r152). | Custom DLL-backed classes are not interchangeable with stock classes or automatic permission to copy their binaries. |
| VSN F-4B/C: author repository README, blob `75bd46e10db35744043038b1b31d13a8781e919c`; PeeJott developer interview | Author states no other DCS modules are required and describes replacing its earlier FC3/F-15 cockpit arrangement. Identifies Nero's basic radar/RWR example; reports STT-only capability rather than TWS. [R180](RESOURCES.md#r180). | We have not inspected the installed radar/weapon source or run its guided engagements. Does not establish modern multi-target support. README's EFM source link and package permissions are separate. |
| VSN F-104C: author README, blob `f56d02d8c8ff96672e23b83cf568679c932c8b77`; author's June 2025 announcement | Standalone early-access C version explicitly distinguished from older FC3-dependent G packages; radar credited to Nero's simple example, with custom RWR/radio integration. [R181](RESOURCES.md#r181). | Download variants/old README history can give contradictory impressions. No installed package/runtime validation completed here. |

The important additional finding is a **standalone fighter-radar precedent**, not just standalone transport/trainer cockpits. It supports an independent basic radar/weapon prototype. It still leaves a gap between single-target host support and the F-22's intended multi-target avionics behavior.

## Current code dependency inventory

| Current location | What currently happens | Replacement owner / required proof |
| --- | --- | --- |
| `entry.lua` | `MAC_flyable('F-22A', ...)`, with legacy `old = 6` FM registration field | Independent `make_flyable`, our own explicit devices and a tested EFM registration. Verify `old` compatibility rather than carrying an unexplained legacy selector. |
| `Cockpit/Scripts/device_init.lua` | Seven active custom Lua devices; custom head-down indicators. No explicit replacement radar, core weapon, core electric, RWR, radio/intercom or HUD indicator declaration. | Declare the complete device graph and links, then prove cold/hot/air starts without any paid aircraft preloaded. |
| `Systems/ICP_System.lua` | NAV/BVR/VS/boresight modes dispatch inherited aircraft commands | Our mission-mode state, radar scan/lock command adapter and HUD/display pages must consume the same state. |
| `Systems/Weapon_System.lua` | Custom arm/door presentation wraps inherited fire/pickle commands and gear-based checks | Explicit `avSimpleWeaponSystem` or another proven compatible host adapter. Actual inventory, station selection, WOW inhibition, door sequencing and release confirmation owned by our stores logic. |
| `Systems/MFD_System.lua`, display pages and main-panel arguments | Several values are read from inherited cockpit draw arguments | Replace these with typed/units-documented observations and our own display state. Existing numeric argument reads must be traced individually. |
| `Systems/Electrical_System.lua`, `Engine_System.lua` | Lua power/APU logic and start/cutoff dispatch | Keep one bus owner; link actual core electric device generators/battery to that state. The new EFM now reads power parameters rather than overwriting them. |
| EFM FC3 parameter exports | Host still consumes stick, engine, gear and brake values | Preserve the common engine/fuel/flight callbacks; keep legacy FC3 presentation exports only where needed. Their existence does not mean physics depends on F-15 code. |
| `comm.lua`, input bindings, warnings, navigation | Existing behavior assumes inherited command/device context in places | Explicit radio/intercom/menu behavior, nav/beacon interfaces, own warnings and input routing; inspect each binding before retirement. |

`dispatch_action` itself is not an F-15 dependency: generic ejection and EFM commands can remain. Replacing every dispatch indiscriminately would break valid host integration. The distinction is whether the receiving behavior belongs to core DCS, our EFM/device, or the inherited avionics.

## Implementation order and decisive tests

1. Preserve the existing combat registration as a comparison while developing a separate standalone test configuration. Reuse our flight-model source and assets under their existing terms; no base-install edits or FC3 preload workaround for the standalone test.
2. Implement core electrical, weapons and a minimal radar device **before** redesigning all displays. Connect actual power; obtain actual host radar returns; exercise lock/loss, station launch and host missile guidance.
3. Test an IR shot, a radar-supported shot and radar support termination against maneuvering targets. Separate a supported engagement from a missile launched toward a target that later finds it autonomously. Record exact DCS build, installed modules, logs and mission conditions.
4. Test two separated targets with overlapping engagement timelines. If native concurrent support cannot be demonstrated, state STT-only capability. Drawing several predicted symbols is not host-supported TWS. Do not substitute mission-global truth or external export feeds for inaccessible aircraft observations.
5. Once the host path is proven, build our own radar/track/weapon state, HUD, head-down presentation, navigation, warnings and autopilot around that interface. Publish confidence/age/validity rather than pretending an unsupported sensor output exists.
6. Remove the legacy dependency only after boot, core-device, weapon, radio, network, repair/rearm/respawn and server-policy tests pass with F-15C/FC disabled or absent. Review all binary loads and package assets as well as registration text.

The [full acceptance matrix](STANDALONE_DESIGN.md#the-decisive-standalone-experiment) remains applicable. Runtime access is the present validation gap; no claim is made that a source-only change here has passed it. A fully standalone approximation appears feasible from these precedents; exact modern radar/weapon fidelity remains conditional on available, demonstrated host interfaces.
