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
workload, a Windows SDK, and CMake 3.30 or later. The source requests C++23.
From a Visual Studio x64 developer terminal in the repository root:

```sh
cmake --preset x64-release -G "Visual Studio 17 2022"
cmake --build --preset x64-release --config Release
```

The CMake project writes `bin/f22.dll`. The repository contains source;
building the DLL is required before installing a fresh source checkout as
a flyable mod. The inherited release workflow also builds the DLL when a
version tag is published.

## Install a development build

Use a separate working copy under your DCS Saved Games aircraft-mod
directory, conventionally `Saved Games/DCS/Mods/aircraft/F-22A`, containing
the root `entry.lua`, compiled `bin/f22.dll`, and the aircraft's asset
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
or radar implementation. Aircraft behaviour has not been changed as part
of this repository import.

## Contributing

Make focused branches and preserve existing attribution and licence
notices. Keep changes to aircraft behaviour distinct from additions to
the study catalogue. When implementing a reference-based feature, record
the reference, aircraft era/configuration and any necessary approximation.
