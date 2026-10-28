# P-FLT-001 remaining native consumer cutover

The integrator accepted `EFM_HUD_VALID` as the full atmospheric/body/world/wind
group and `EFM_HUD_KINEMATICS_VALID` for independent world velocity. Physical
and HUD tests pass. These remaining consumers are Chat 4 regions and have not
been edited by Chat 1:

- NativeGunSight `calculate_funnel`, `calculate`, `calculate_ground` read raw
  world wind and velocity. After clearing result gates, require a checked
  successful read of full-group VALID==1 before native work; invalid funnel
  source must also retire its pending trajectory history. Keep source 2.
- NativeAGWeapons `solve` reads raw world wind. After clearing result/trajectory
  gates, require the same checked group admission before native solve. A queued
  result from before source loss cannot remain a current solution.
- NativeSidewinder `publish_time_estimate` reads EFM_HUD_TAS. Include full-group
  admission in eligibility; source loss must retire cached `time_estimate`, so
  restoration cannot promote a cached pre-failure estimate with a new stamp.

Use the now-available two-argument checked EDPARAM port. Missing/false conversion
with retained payload 1 is unavailable. Do not add another one-argument getter
or substitute numeric zero. Tuple status/coherence/epoch handling remains part
of the complete P-INT-008/domain migration; do not call a flag-only patch proof
of the whole native source protocol.

Acceptance: valid zero velocity/wind survives; full-group 0, absent/malformed/
failed conversion and release/generation change withdraw results/history while
the independent HUD motion chain remains eligible. Restore with a fresh valid
source/request. Native actual effect/lifetime remains a separate qualification;
no fabricated host backend or diagnostic truth is acceptable as aircraft proof.
