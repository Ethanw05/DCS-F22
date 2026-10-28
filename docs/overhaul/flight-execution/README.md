# Flight execution — 28 October 2026

Accountable owner: Chat 1. Review baseline: `Deep-Audit-2026-10-28-1351`,
HEAD `7513f931a8bf1016a72e8eb184a9c98074786e81`, primary checkout on `main`.
`baseline.json` records the initial working state and 39 affected/context hashes;
all available package hashes match. Unrelated tool edits and ZIP files are retained.

## Integration requests

Chat 2 has published ADOPTED / HARNESS_READY / safe-build readiness and granted
the `flight-early` lease. The early changes are applied under that lease; the
focused commit and shared-region release are requested in `commit-request.json`.
No common harness, shared CMake, shared parameter wrapper or other owner's
production region has been changed by Chat 1.

Requested early regions (expected RAPTOR SHA-256
`71d7660ce9b178295f033a1efbd0652d3b964ba501298545b4112888b0cc37a1`):

- `reset_fm_state`: reset the existing yaw smoother beside pitch/roll.
- `ed_fm_set_atmosphere`: preserve callback validity independently of finite
  computational fallbacks; no aircraft coefficient changes.
- `CockpitManager::initialize`, `update`, `invalidatePhysical`, `updateCombat`:
  bind/publish/invalidate field-group gates and qualify shared standby pressure.
- `CockpitManager::updateGearLights`: later consume achieved per-leg locks.
- `Cockpit/Scripts/Systems/HUD_Flight_Data.lua`: serialized consumer gate change,
  preserving geometry, styling and independently valid velocity/FPM.
- `Cockpit/Scripts/mainpanel_init.lua`: later correct right/left lamp bindings.

Proposed field contract for P-FLT-001 (requires integrator agreement before
provider/consumer cutover):

- Retain existing `EFM_HUD_VALID` as the conservative full legacy flight/wind
  group: atmospheric, body-motion and world-motion validity are all required.
  This withdraws legacy atmospheric consumers safely.
- Add `EFM_HUD_KINEMATICS_VALID` for world velocity only, sourced from the finite
  world-motion callback. HUD GS/FPM use this independent gate; wind keeps the
  full legacy gate. Numeric 0/1; SI north/up/east; same physical generation and
  spawn clock as `I-FLT-001`. Invalid atmosphere must not erase independent GS/FPM.
- Each validity is cleared on release/new generation. Finite fallback values may
  remain computational payloads but carry no measurement authority.
- Environment input carries explicit atmospheric provenance. Invalid shared
  atmosphere withdraws cabin/thermal/conditioned-air/OBOGS validity, while the
  existing finite stored oxygen owner remains active. ADC-only failure does not
  remove genuinely healthy standby pressure or independent oxygen.
- Standby pressure admission uses shared atmosphere validity independently of
  primary ADC health. A failed read remains P-INT-008's separate shared contract.
- Wind-using native gun/AG paths need their domain owner's explicit legacy gate
  check before this provider contract is qualified as complete. NativeGunSight
  has three raw wind-read paths; NativeAGWeapons has one. Their current finite
  tuple checks alone cannot authenticate finite atmospheric fallback data.

## Current early package status

P-FLT-001's physical provider/HUD and D-P-FLT-001's reset fix pass independently
rebuilt actual-DLL and Lua tests. Three assigned legacy artifacts were deleted
and remade. `early-evidence.json` records hashes and actual results; the original
atmosphere defect and new yaw test failure were observed before the fix.
P-FLT-001 still needs Chat 4's native wind/TAS consumers to check the full group.
NativeSidewinder's missile time estimate also reads EFM_HUD_TAS and must be
included in that caller migration. No broad qualification is inferred.

P-FLT-005's per-leg contract is prepared in `gear-contract.md`. Dependent
physical changes/tests await their actual DAG prerequisites. Native effects,
aircraft calibration, installation, DCS, 2D/VR and multiplayer are unqualified;
offline numerical results cannot close those gates.

No simulator has been launched, stopped or taken over. No installation performed.
