# Working on DCS-F22

This repository starts from Grinnelli Designs' F-22A at commit
`8484b44cf8bc46540376435f0ba584f9f3e8bf44`. Original source history,
credits and licence notices are retained.

## Get a complete checkout

Install Git and Git LFS, then run:

```sh
git clone https://github.com/Ethanw05/DCS-F22.git
cd DCS-F22
git lfs install --local
git lfs pull
```

The models, textures, audio and manual use Git LFS. A normal GitHub ZIP
download may contain pointer files depending on the repository's archive
settings; cloning with Git LFS is the documented development path.

## Build the external flight model

Use Windows with Visual Studio 2022 or its Build Tools, the C++ desktop
workload, a Windows SDK, and CMake 3.21 or later. The physics core uses C++17.
From a Visual Studio x64 developer terminal in the repository root:

```sh
cmake --preset x64-release -G "Visual Studio 17 2022"
cmake --build --preset x64-release
ctest --preset x64-release
```

The CMake project writes `bin/F22.dll`. The PR workflow pins the Windows 2022
runner to match its Visual Studio 2022 preset; a successful run uploads an
experimental DLL artifact and a Lua/DLL install-overlay ZIP, with licence notices and model limitations. The repository contains source;
building the DLL is required before installing a fresh source checkout as
a flyable mod. The inherited release workflow also builds the DLL when a
version tag is published.

## Test the portable physics on Linux

```sh
cmake -S . -B out/physics -DCMAKE_BUILD_TYPE=Release
cmake --build out/physics --parallel
ctest --test-dir out/physics --output-on-failure
```

Install Lua 5.1 to include cockpit state, registration, indicator-construction and syntax tests. CMake discovers `lua5.1`/`lua51`/`lua`; set `F22_LUA_EXECUTABLE` explicitly if needed.

This builds the physics, callback tests with an absent-DLL stub, and a small
rigid-body scenario harness. It does not build a usable Linux DCS plugin.
For sanitizers use a separate Debug build with
`-DCMAKE_CXX_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer"`.
The tests validate numerical properties and selected response cases, not
production F-22 fidelity.

## Install a development build

Use a separate working copy under your DCS Saved Games aircraft-mod
directory, conventionally `Saved Games/DCS/Mods/aircraft/F-22A`, containing
the root `entry.lua`, compiled `bin/F22.dll`, and the aircraft's asset
directories. See the original README and included manual for installation
details and the inherited F-15C preload setting.

The module still depends on DCS's F-15C/Flaming Cliffs avionics. Those
proprietary binaries are supplied by the user's DCS installation, not this
repository. Public compiled aircraft models and textures are included;
their original Blender/other authoring projects should not be assumed
available unless separately present and licensed.

## Source map

| Location | Purpose |
|---|---|
| `EFM/source/` | Custom C++ flight model and cockpit bridge |
| `EFM/include/` | Flight-model and cockpit API declarations |
| `FM/config.lua` | External flight-model configuration |
| `Cockpit/Scripts/Systems/` | Lua aircraft/cockpit systems |
| `Cockpit/Scripts/` display directories | Display pages, materials and indicators |
| `Input/F-22A/` | Keyboard and joystick bindings |
| `F-22A.lua`, `entry.lua` | Aircraft and module registration |
| `Weapons/`, `UnitPayloads/` | Weapon definitions and loadouts |
| `Shapes/`, `Textures/`, `Liveries/` | Aircraft assets |
| `docs/RESOURCES.md` | Public study references and their evidence limits |

The current baseline dispatches inherited avionics/HUD commands; the
presence of Lua cockpit pages does not establish a fully independent HUD
or radar implementation. The experimental flight-model overhaul is documented in
[FLIGHT_MODEL.md](FLIGHT_MODEL.md), including its assumptions and validation limits.

## Contributing

Make focused branches and preserve existing attribution and licence
notices. Keep changes to aircraft behaviour distinct from additions to
the study catalogue. When implementing a reference-based feature, record
the reference, aircraft era/configuration and any necessary approximation.

## Build an install overlay

After building the Windows DLL, run `python tools/package_overlay.py`. It produces `dist/f22-overhaul-overlay-win64.zip` with Lua, DLL, licences, evidence and installation notes. It deliberately excludes large model/texture/audio assets and refuses LFS pointers. Use it over a complete existing installation, as described in [TEST_BUILD.md](TEST_BUILD.md). The package records the commit/hash; it is not a standalone mod.

The current source now includes an original custom NAV HUD, with native combat-HUD fallback. See [HUD.md](HUD.md) for controls and unverified optical assumptions. The seven active cockpit devices are replaced by the systems pass in [OVERNIGHT_OVERHAUL.md](OVERNIGHT_OVERHAUL.md). Unregistered legacy device files are retained for history/study, not activated.
