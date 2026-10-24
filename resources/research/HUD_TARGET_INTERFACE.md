# Cockpit HUD target interface contract

## Currently working

`HUD_MODE` (weapon-mode request) and `HUD_RADAR_REQUEST` (radar-mode request) are set in `Weapon_System.lua`. `HUD_POWER`, attitude and speed/altitude pointers are published by `Avionics.lua`.

## Reserved, not yet connected

All numeric `HUD_*_VALID` parameters default to **zero**. Do not set a target marker valid until the radar/seeker/navigation adapter supplies actual current information and appropriate failure/age checks.

| Domain | Valid param | Required data if valid |
|---|---|---|
| NAV waypoint | `HUD_WP_VALID` | `HUD_WP_AZ_RAD`, `HUD_WP_EL_RAD`, `HUD_WP_RANGE_NM` |
| A/A radar | `HUD_AA_TARGET_VALID` | `HUD_AA_TGT_AZ_RAD`, `HUD_AA_TGT_EL_RAD`, `HUD_AA_TGT_RANGE_NM` |
| IR seeker | `HUD_IR_SEEKER_VALID` | seeker line of sight, tone and uncage state remain unsupported |
| A/A gun | `HUD_GUN_TARGET_VALID` | current target angular/range data; no lead/prediction yet |
| A/G target | `HUD_AG_TARGET_VALID` | `HUD_AG_TGT_AZ_RAD`, `HUD_AG_TGT_EL_RAD`; no terrain/weapon range solver yet |

`HUD_AG_SUBMODE` selects **display requests**, but CCIP and CCRP explicitly show `N/A`. No calculated impact point, release consent, weapon envelope or real F-22 tactical symbology has been established.

All LOS angles use radians relative to aircraft boresight, x azimuth right positive, y elevation up positive; conversion to DCS optic coordinate scale presently uses provisional 1.18 units/radian and must be calibrated in-game. Bounding/clamping is not implemented; producers must flag targets outside the display as invalid until that is added.

Unpowered and invalid-data states must not continue to show a target. DCS `get_param_handle()` initializes zero (verify current build); if a future device owns these, it must clear them on cold starts, track loss and power loss.

Review [tactical evidence](TACTICAL_HUD_RADAR_EVIDENCE.md) before inventing new tactical cues. The historic USAF 2002 F-22 HUD is the source for the common flight display, not for this entire layer.


### Valid-data updates

The current read-only radar device publishes target/flight independent parameters:

- `HUD_RADAR_TRACK_SOURCE`: 1 only for a fresh, finite, powered native STT return.
- `HUD_AA_CUE_VALID`: 1 only if the detected target is on the approximate HUD FOV; `HUD_AA_TARGET_VALID` may remain 1 when offscreen.
- `HUD_AA_CLOSURE_VALID`, `HUD_AA_TGT_CLOSURE_KTS`: finite time-separated STT range derivative.
- `HUD_GUN_LEAD_VALID`, `HUD_GUN_LEAD_AZ_RAD`, `HUD_GUN_LEAD_EL_RAD`: manufacturer-muzzle-speed-based **simulation cue**, never authentic launch clearance.
- `HUD_RADAR_SEARCH_RETURNS` and `HUD_RWS_nn_[X/Y/VALID]`: displayed read-only native radar echoes, zero without compatible data.
- `HUD_AG_CCIP_EST_VALID`, `HUD_AG_CCIP_CUE_VALID`, `HUD_AG_CCIP_TOF_SEC`: simulated gravity-only impact prediction.
- `HUD_AG_CCRP_EST_VALID`, `HUD_AG_CCRP_TIME_SEC`: simulated release-timing estimate relative to visual terrain MARK.

For A/A the sensor bridge does **not** hand off IR seeker tracks or guide AIM-120; for A/G it does **not** push a JDAM target coordinate or override DCS stores logic. Maintaining two independent meanings (HUD available versus verified missile solution) is essential.
