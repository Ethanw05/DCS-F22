# DCS-F22 — standalone development build

A standalone cockpit and avionics implementation for the Grinnelli Designs F-22A, retaining its custom external flight model. This fork uses shared DCS radar, payload, weapon and RWR services; the F-15C, Flaming Cliffs and Hornet modules are not prerequisites. It installs under Saved Games without editing another aircraft's files.

The native adapters were qualified locally on **DCS 2.9.30.28738, Windows x64**. Their private interfaces are version checked; compatibility with another DCS build requires validation. This is an actively developed community mod, not a claim to reproduce classified F-22 avionics.

## Current systems

- Own HUD and head-down displays, computed gun pipper, native ballistic funnel and maneuver cues.
- RWS, ACM acquisition, native STT and an own TWS track/scan controller with real native missile support.
- Native stores, bay-gated release, dynamic launch envelopes and estimated missile flyout/activation timing. Actual seeker state remains separate from predictions.
- Independent passive RWR, radar/RWR identity association and prioritized warning audio.
- Independent optical missile warnings with HUD clock sectors, EW bearings and distinct audio; actual R-73 attacks qualified without paid aircraft modules.
- Native chaff/flare dispensing and ECM controls; status and quantities follow the common simulator service.
- Mission-route navigation, waypoint/direct-to selection, optional automatic sequencing and HUD steering cues.

Local flight qualification includes operation with the F-15C and Hornet directories removed from DCS's module search path, plus loaded-module checks proving their aircraft avionics DLLs absent. See [standalone status and limits](docs/STANDALONE_DESIGN.md) for the tested scope. Multiplayer, complete rearm/respawn coverage, TACAN/ILS, advanced datalink and new AESA detection physics remain outside that acceptance.

## Build and install

1. Clone with Git LFS installed, then run `git lfs pull` to retrieve the models, textures and audio. A source ZIP containing LFS pointers is insufficient.
2. Build `bin/f22.dll` with Visual Studio 2022 C++ tools and CMake 3.30+. See [development setup](docs/DEVELOPMENT.md).
3. Place the aircraft root (including `entry.lua`, `bin/f22.dll`, `Cockpit`, `FM`, `Input` and the asset directories) in `Saved Games/DCS/Mods/aircraft/F-22A`. Restart DCS after installation. Remove older copies of this same mod from other aircraft-mod directories to avoid duplicate registration.

The repository contains our source and public aircraft assets. Proprietary DCS DLLs, IDA databases and test-control hooks are not distributed as aircraft prerequisites. CI builds the DLL and runs the C++ and Python/Lua regressions; the DLL artifact still needs the aircraft assets from a complete checkout.

## Development references

- [Standalone status and architecture](docs/STANDALONE_DESIGN.md)
- [Development setup and tests](docs/DEVELOPMENT.md)
- [HUD/system test plan](docs/HUD_AND_SYSTEMS_TEST_PLAN.md)
- [Research archive](docs/resources/research/README.md) and [public study catalogue](docs/RESOURCES.md)

Older audit and roadmap documents describe earlier development states. The current standalone status takes precedence over their historical dependency descriptions.

## Credits and original project

Based on [Grinnelli Designs' F-22A](https://github.com/grinnellidesigns/f-22a), upstream commit `8484b44cf8bc46540376435f0ba584f9f3e8bf44`. Original source history, model/assets attribution, copyright notices and GPL licence are retained. Original 3D authoring projects are not supplied by this fork. See [LICENSE](LICENSE), [contributors](Contributors.md) and [contributing](CONTRIBUTING.md).

The upstream release used F-15C avionics. Its aircraft-module preload workaround is superseded here by the own cockpit and common-device integration. The original aircraft overview follows.

## About the Raptor
The Lockheed Martin F-22 Raptor is an American single-seat, twin-engine, all-weather stealth tactical fighter aircraft developed for the United States Air Force. As the result of the USAF’s Advanced Tactical Fighter program, the aircraft was designed as an air superiority fighter, but also has ground attack, electronic warfare, and signals intelligence capabilities.

The prime contractor, Lockheed Martin, built most of the F-22’s airframe and weapons systems and conducted final assembly, while Boeing provided the wings, aft fuselage, avionics integration, and training systems. The aircraft first flew in 1997 and was variously designated F-22 and F/A-22 before it formally entered service in December 2005 as the F-22A.

## Features
* **NEW!** Full EFM, complete with thrust vectoring!
* Highly detailed, 6-dof cockpit
* Interactive (clickable) cockpit
* Detailed PBR textures
* Multiple MFD pages to explore
* Unique configuration MFD page
* Additional liveries
* Aerobatic smoke system
* Photoshop paint kit
