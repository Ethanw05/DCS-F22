# Avionics brightness and warning retention, 24 October 2026

## Source-by-source audit

1. Read `Cockpit/Scripts/Systems/Avionics.lua` opacity branches and brightness-induced warning reset.
2. Compare [MIL-HDBK-87213 Airborne Displays, 1996](https://www.cevians.com/app/uploads/2021/01/MIL-HDBK-87213.pdf) display legibility/adjustment requirements, [USAF F-22 cockpit study](https://doi.org/10.1117/12.397775) integrated warnings (abstract-only), and previous [09-avionics audit](../../docs/audit/09-avionics.md).
3. **Direct code defect:** night mode previously used `UFD_KNOB - 0.9`; at 0.5 it produced `-0.4` opacity. At zero brightness, the method wrote 0 into `CANOPY_LIGHT`, `CAUTION_LIGHT`, `L_FIRE_LIGHT`, `HYD_LIGHT`, `OIL_LIGHT`, etc., erasing failure state.
4. Replace four repetitive branches with bounded [0,1] brightness, a provisional night factor 0.18, one electrical availability check, and keep UFD warning/ADI visibility separate from fault state. The night factor is a visual tuning assumption, *not* an authenticated F-22 optical calibration.
5. Existing `MAIN_POWER`, `BATTERY_POWER`, fault flags remain produced by other devices. DCS screenshot and power/caution persistence still require in-game testing; CI Lua parser checks syntax, not event sequencing.

**Smoke scenarios:** UFD/MFD knob 0, 0.5, 1.0; day/night switching; cold/hot/air starts; battery loss; generator failure, canopy open and hydraulic fault while turning off the display, then restoring brightness. Expected: 0 ≤ opacity ≤ 1; original alert state remains until the source clears it.
