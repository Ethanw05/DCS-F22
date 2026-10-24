# 16 — Damage, lifecycle, effects, assets and distribution

## Applicable resources

| Reference | Application | Limit |
| --- | --- | --- |
| [R20](../RESOURCES.md#r20), [R121](../RESOURCES.md#r121), [R161](../RESOURCES.md#r161) | Failed-effectors/reconfiguration and fault-tolerant design goals. | No complete production vulnerability/failure model. |
| [R59](../RESOURCES.md#r59), [R86–R87](../RESOURCES.md#r86), [R152](../RESOURCES.md#r152) | Source provenance, template licensing and reuse boundaries. | Each component retains its own terms; a repository label is not proof that all assets have editable source. |
| [Official CMake documentation](https://cmake.org/cmake/help/latest/variable/CMAKE_BUILD_TYPE.html) | Build configuration semantics. | Does not replace an actual Windows build or DCS release check. |

## Code scope and findings

Reviewed damage callbacks/enums/aircraft table, repair/reset/start/release, mass/event queues, vortex/effect and sound declarations, livery/quickstart/payload configuration, model metadata, build/release scripts and source notices. Compiled assets are outside source-semantic review; see [coverage](COVERAGE.md).

- **LIFE01 — C/R:** [Repair](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/EFM/source/RAPTOR.cpp#L1677) resets the element array and damage queue without rebuilding derived wing/tail health or clearing destruction. An extracted-callback check damaged left outer wing to 0.1 then repaired: element returned to 1, derived wing remained **0.1**. All lifecycle entry points need one complete reset/recompute policy.
- **LIFE02 — C/R:** The local static destruction-event guard survives aircraft resets. The extracted experiment produced **7 events** on the first destruction and **0** after initializing/destroying again in the same process. The reset also leaves pending mass changes (see [06](06-fuel.md)). Persistent statics/queues are not per-aircraft state.
- **LIFE03 — C:** The destruction expression mixes `&&`/`||`; C++ groups it as `(left engine && right engine && left wing) || (right wing && tail)` at the threshold conditions. Document intended combinations and parenthesize them later; symmetry cannot be assumed. Damage also does not consistently reduce the forces of every affected control surface.
- **LIFE04 — U:** Damage received from DCS is queued back as structure-damage events. Determine whether this is necessary notification, redundant echo or a feedback risk on the actual host. The source alone does not prove an infinite loop. Invalid element values are not written into the fixed array, but may still enter the event queue.
- **LIFE05 — C/I:** Visual vortex strength uses density as a quantity named humidity; it is not actual relative humidity. Vortex output also uses shared static storage whose lifetime/host copying needs verification. Sound banks have declarations, while an explicit sound mount in entry is commented: check actual DCS loading before alleging silent audio.
- **LIFE06 — C/I:** Editable Lua/C++ and textures do not imply editable cockpit/airframe model projects. EDMs are compiled assets; no complete original 3D authoring project was located. Livery descriptors, texture names, views, payload station IDs and quickstart registrations need package/runtime checks rather than fabricated aerodynamic findings.
- **LIFE07 — C:** Release cleanup deletes the EFM directory, including its MIT template notice, while distributing the DLL; preserve required notices and provide corresponding source/build provenance for GPL-covered distributed code. Existing repository license files do not make removal of all component notices a safe packaging policy. This is a distribution-review action, not a legal opinion on unknown third-party assets.
- **LIFE08 — C/U:** Workflows configure a Visual Studio multi-configuration generator but build without explicit Release configuration; a preset's `CMAKE_BUILD_TYPE` does not select that configuration. Verify resulting binary/configuration and CRT. Release checkout includes LFS, but no Windows artifact/DCS run occurred here. Do not treat parser success as a shipping-quality gate.

## Proposed rewrite and future acceptance

Create coherent per-aircraft state/reset and derived-health recomputation; keep host event ownership explicit. Preserve source/asset provenance, licenses, intended aircraft era and reproducible release metadata. Keep experimental stores/configuration distinguishable from supported aircraft behavior.

Later validate repair and repeated respawn in one process, mission reload, aircraft switching, damage to each effector, invulnerability changes, event-loop behavior, effects/sounds, all referenced missions/loadouts, clean LFS checkout, explicit Windows Release build and installation on a clean DCS setup. Multiplayer synchronization, VR rendering and server integrity acceptance remain untested. This pass changes documentation only.
