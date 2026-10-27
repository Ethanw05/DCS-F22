# Landing presentation and selected-weapon HUD corrections

26 October 2026. This implements follow-up corrections to the user-flight audit. It is not a claim of complete F-22 or Hornet avionics parity.

**Final user scope:** landing E-bracket and Hornet NAV HUD cues only. The HUD RWR indications remain intact in every master mode. The experimental HUD ILS cross was removed; expanded landing-horizon geometry was backed out.

## Installed Hornet references actually examined

Under `D:/DCS/Mods/aircraft/FA-18C/Cockpit/`:

- `Scripts/Multipurpose_Display_Group/HUD_AVQ32/indicator/Pages/HUD_common.lua`: velocity-vector parent, continuous E-bracket at line 124, long horizon with landing gear down, and independent ILS needles at lines 395–399.
- `Scripts/Multipurpose_Display_Group/HUD_AVQ32/indicator/Pages/HUD_NAV.lua`: navigation/landing bank and vertical-velocity presentation.
- `Scripts/Multipurpose_Display_Group/HUD_AVQ32/indicator/AVQ32_specifics.lua` and `Common/indicator/MDG_units.lua`: display increments and angular conversion, **0.34 mrad per DI**. The ILS source's 202/51 values are DIs, not milliradians.
- `IndicationResources/MDG/stroke_symbols_HUD.svg`, symbol `146-E-bracket`: 100-unit spine, 15-unit outer prongs and 8-unit middle prong. The page scales the symbol by 1.2.
- Read-only IDA: Hornet ILS controller `0x1804D9720`; E-bracket controller `0x1804E0220` and aperture limiter `0x1804E0360`. These were located through the actual indicator controller registration map, not inferred from screenshots.

Evidence, before-files, compiled-test results, native traces and render previews are in `D:/Codex-F22-Overhaul-2026-10-25/hud-weapon-completion-20261026`.

## Landing changes

The first needle-only change did not implement the requested E-bracket. The old incomplete approach fragments disappeared at the aircraft's on-speed AOA. The final implementation adds the persistent E-bracket and continuous AOA-error displacement around the FPM. The legacy lower bank arc overlapped this aircraft's approach FPM and is hidden with gear extended.

The E-bracket uses the aircraft's existing **12-degree approach AOA target**. Copying the Hornet's display does not make its airframe's approach AOA appropriate to an F-22 mod. The HUD ILS needles were removed after the user clarified the requested scope. Receiver/MFD ILS behavior remains separate. The E-bracket remains available without an ILS signal; it is an AOA cue, not radio glidepath guidance.

The NAV steering arrow and four/eight-degree reference circles use the installed Hornet's 19-DI-per-degree mapping and eight-degree cage. The arrow geometry comes from `124-arrow-up`; reference circles use five-DI radius and hide within 1.25 degrees, matching the source controller threshold. Normal waypoint and TACAN steering no longer require OBS to show a HUD cue. Lost source/FPM validity hides the cue. No RWR receiver, HUD emitter-label/bearing-line code, or HUD-RWR enable setting was changed. The user screenshot's `29` and line were the independent HUD RWR repeater, not NAV-menu content.

Native testing also exposed an actual visibility defect inherited from the old fragments: `getWOW_NoseLandingGear()` reported ground contact in an airborne test. `RAPTOR.cpp` already documents this common-sensor limitation and publishes suspension-derived `EFM_GROUND_VALID`/`EFM_WEIGHT_ON_WHEELS`. The landing cue now uses those authoritative values when available. It retains the base-sensor fallback when that EFM bus is unavailable. `F22_LANDING` logs base WOW, chosen contact source, AOA, bracket validity/displacement, FPM and both receiver-channel validities.

The real Lua page and producers are rendered by `render_landing.py` for fast/on-speed/slow fixtures. These are layout checks, not photographs or native optical qualification. Tests exercise persistent on-speed visibility, AOA motion, conflicting common/native contact states, invalid AOA, gear and ground gates, unit conversion, channel independence and attitude-frame regressions.

## Weapon HUD changes

- Selected model names replace fixed AIM-120/AIM-9 labels. Coverage includes stock B/C, C7/C8/D3, AIM-260A, MAKO A/A, AIM-9M/X/X II, supported bombs and gun context.
- HUD quantity counts the selected model, including single/paired racks of that model. A separate category count preserves release reconciliation across station changes.
- A/G HUD identifies the selected ground munition. Unavailable/training/nonweapon capabilities remain separate from firing eligibility.
- An actual uncaged native IR lock supplies IR seeker eligibility; the generic radar-missile 30-degree gate no longer suppresses an AIM-9X HOBS SHOOT cue. Range/track/friendly/arm criteria remain required.
- IR flyouts can retain their own frozen time estimate without creating radar-support obligations. Launch mode, model and lifetime remain attached to the launched weapon after selection changes.
- Longer-life custom missiles no longer inherit a fixed 300-second tracking cutoff or a subsequently selected weapon's lifetime.

## Timing backend and its limits

Stock AIM-120B/C keep the existing `WeaponsBase::TOFEstimator` tables. Custom radar missiles and IR missiles use the **selected native `Rocket_Const::getDFlight` descriptor estimator**, exported by shared `Weapons.dll`, rather than substituting the stock AMRAAM-C enum. Read-only IDA verified the ABI at `0x180121DC0` and its range/velocity dependency at `0x180122A70`: altitude, slant range, target-aspect cosine and target speed, with average-velocity and time outputs. Identity, time freshness, finite outputs, velocity and the selected weapon's lifetime gate acceptance.

Source 1 identifies the stock estimator; source 2 identifies the generic selected-descriptor estimator. Airborne countdown source 3 preserves the latter distinctly from the current-velocity fallback. HUD timing is marked **E** for estimate. The generic descriptor calculation is not a full integration of a custom missile's loft/drag trajectory and has not been qualified for every launch geometry. Sensitivity range is not treated as seeker activation range: missing custom ACT predictions remain unknown until actual native seeker state is available.

The native mixed-load run produced distinct, valid source-2 estimates for C7, C8, D3, MAKO A/A, AIM-260A, AIM-9X II and AIM-9M; the stock C retained source 1. Counts were one of each selected model, rather than the six-radar-missile category total. Paired-rack aggregation and empty/unknown identity behavior are covered by controller tests.

This completes the selected-weapon HUD/timing work described above. It does **not** add MAKO A/G coordinate/anti-radiation guidance, repair the separate legacy missile-class GBU32 asset, program native fuzes, establish real classified missile performance, or prove weapon impact accuracy. Those backend limitations must not be described as fixed because a HUD label is correct.

## Validation and installation

The C++ build and all 17 native CTest cases pass. Relevant Lua checks pass for weapon identity/inventory, station stepping, launch snapshots, IR eligibility/timers, E-bracket geometry/visibility, NAV cue scaling and source loss, HUD binding and attitude, stores/keypad integration and DLZ scaling. The earlier native mixed-load run confirms descriptor timing without cockpit Lua errors. The intermediate native landing test exposed the common-WOW defect; failed/interrupted evidence is retained rather than presented as a final pass. The final E-bracket/NAV-only revision passes the Lua/controller checks and is installed with matching SHA256 identities. A new native visual check of that final revision was not completed after the user resumed DCS. The five Lua files apply on the next mission/cockpit load; the live process and DLL were left untouched.

Only this task's exact PID/executable/mission/creation-time identities were controlled. Interrupted test logs were archived separately; user flight evidence was preserved. No agents or other chats were used.
