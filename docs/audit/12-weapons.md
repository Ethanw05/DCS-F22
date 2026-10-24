# 12 — Stores, bays, gun and ordnance

## Applicable resources

| Reference | Application | Limit |
| --- | --- | --- |
| [R39–R42](../RESOURCES.md#r39), [R116](../RESOURCES.md#r116) | Public integration scope and supersonic JDAM demonstration context. | No complete seeker, motor, launch-zone or release-clearance tables. |
| [R172](../RESOURCES.md#r172) | Official JDAM identity as an INS/GPS guided-bomb kit. | Does not specify the DCS custom-weapon schema. |
| [R149–R150](../RESOURCES.md#r149) | Independent stores/launch interface and implementation experience. | Launching a missile alone does not prove targeting, midcourse support or native TWS. |

## Code scope and findings

Reviewed all eight `Weapons/*.lua` definitions, loader, station/payload declarations, bay/gun system and inactive `Missile_System.lua`. The latter is not registered and is not the active guidance implementation.

- **WPN01 — C/R:** [Trigger handling](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/Cockpit/Scripts/Systems/Weapon_System.lua#L209) accepts release only while main power equals 1. In isolated Lua execution: arm, press second detent with power, remove power, release, update — command **84 (gun fire) still dispatches**. The update checks arm/fire state without checking power. Release events must clear held commands regardless of availability. This proves persistent dispatch, not actual in-DCS ammunition discharge under those conditions.
- **WPN02 — C:** The pickle handler checks master arm but dispatches `PickleON` immediately, independently of main power and without waiting for bay clearance. Door animation opens later. Define an explicit pending request/door-clear/release/close sequence and ensure all cancellation paths release native commands.
- **WPN03 — C:** Bay/gun doors advance by increments with inclusive endpoint comparisons and no common clamp; gun second-detent animation can add 1 to an already partially open door. Logical door state, visual position and release authorization are separate and can diverge.
- **WPN04 — C:** Ground permissions often use gear-down instead of wheel contact. `ARM_STATUS` has no explicit gear-transit assignment and can retain an earlier indication. Use configuration, contact, arm and release-clearance states explicitly.
- **WPN05 — C:** The left-bay override condition contains `and sensor_data.getNoseLandingGearDown()` without a comparison. In Lua, numeric **0 is true**. This condition therefore does not implement the gear-up check used by the corresponding right/center paths. Correct semantics later alongside the common bay state machine.
- **WPN06 — C / fidelity mismatch:** [`GBU_32.lua`](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/Weapons/GBU_32.lua#L23) declares both weapon and loadout as air-to-air and uses missile/AA type identifiers, copied missile-style parameters and explosive mass equal to total mass. No independent coordinate-entry/INS-GPS release path is implemented. It needs a grounded guided-bomb integration redesign, not a display rename. Actual host handling of every legacy field remains to validate.
- **WPN07 — C/I:** Advanced missile definitions include unsupported performance constants. MAKO A/G's declared boost/march fuel values also require reconciliation with total mass and zero-duration stages. Mark experimental weapons as fictional/configurable; do not present them as calibrated fielded F-22 stores. The `ModelData` leading value 58 counts the following 58 values: 59 Lua entries is not itself a length error. `enhanced_a2a_warhead` is host-provided in these scripts; absence from an isolated stub is not proof of a DCS fault.
- **WPN08 — C/U:** Pylon selection uses a custom enumeration; the gun mounts the host `M_61` with 480 rounds. Validate native store identity, attachment, jettison, mass/drag and ammunition behavior for every station. Small missile/loadout mass discrepancies may include adapters; do not label them errors without a mass convention.

## Proposed rewrite and future acceptance

Separate pilot requests, authoritative inventory/selection, native launch support and physical bay clearance. Prefer supported existing DCS ordnance where reuse is permitted; custom definitions need documented provenance and host-schema validation. Keep optional speculative stores outside the historically supported configuration.

Later test press/release during power changes, emergency jettison, bay cancellation, jammed doors, every station/payload, gun door/round count, native missile target support and genuine coordinate-guided bomb behavior. Public evidence does not supply exact modern missile internals or a verified complete F-22 launch-zone model.
