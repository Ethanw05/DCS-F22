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
directories. Follow the current installation instructions in the fork README. The standalone fork uses its own cockpit and
shared DCS core devices; installing F-15C/Flaming Cliffs or Hornet and changing
their preload settings is not required. The common native adapters are qualified
on DCS 2.9.30.28738 (Windows x64) and require validation after host changes.
Original aircraft assets and licences remain required.

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

## Run the regressions

Install the pinned Lua test dependencies and run from the repository root:

```sh
python -m pip install luaparser==4.2.0 lupa==2.8
python tests/run_all.py
ctest --test-dir out/build/x64-release -C Release --output-on-failure --no-tests=error
```

The Python runner includes every `test_*.py` plus modified-Lua syntax checks.
It requires a complete Git LFS checkout for model/font/audio asset tests. Native
flight acceptance is separate from these mocked/numerical tests; see the current
[standalone qualification](STANDALONE_DESIGN.md).

## Contributing

Make focused branches and preserve existing attribution and licence
notices. Keep changes to aircraft behaviour distinct from additions to
the study catalogue. When implementing a reference-based feature, record
the reference, aircraft era/configuration and any necessary approximation.
