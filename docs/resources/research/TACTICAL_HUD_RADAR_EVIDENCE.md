# Tactical HUD and radar requests — system-by-system evidence

**Target**: `Cockpit/Scripts/Systems/Weapon_System.lua`, `HUD/page.lua`, and a new presentation device. F-22A public primary references govern known flight symbology; generic tactical display conventions are explicitly secondary.

| Source | Claims supported | Limits |
|---|---|---|
| [USAF *Flying Safety*, June 2002, F-22 Figure 1](https://www.safety.af.mil/Portals/71/documents/Magazines/FSM/fsmjun02.pdf?ver=2017-03-28-101049-403) | NAV flight-data indicator geometry, circular speed/altitude counter-pointers, pitch symbols | No legible complete missile/gun/attack HUD |
| [MIL-STD-1787, Aircraft Display Symbology (DoD ASSIST)](https://quicksearch.dla.mil/qsDocDetails.aspx?ident_number=37143) | Public standard's declared scope includes flight, navigation, takeoff, weapon delivery, landing | Controlled standard; no claim of access to complete/current text, or F-22 application details |
| [USAF HUD symbology studies, 1994](https://pubmed.ncbi.nlm.nih.gov/8018075/) | Counter-pointers, ghost horizon, pitch-ladder asymmetry, energy cues | Human factors, not an F-22 software specification |
| [T-45C Navy flight-training weapon/HUD manual](https://navyflightmanuals.tpub.com/P-1219/Hud-Air-To-Ground-Symbology-25.htm) | Illustrates actual military A/G MAN/CCIP/reticle convention | Different aircraft; cannot supply JDAM ballistic/cue algorithms |
| [USAF F-22 fact sheet](https://www.af.mil/News/Article-Display/Article/104506/f-22-raptor/) | Baseline M61A2/AIM-9/AIM-120 and JDAM classes | No classified/weapons parameters, radar track semantics or tactical HUD screenshots |
| [Forecast International APG-77 overview, Oct 2012](https://www.forecastinternational.com/archive/disp_pdf.cfm?DACH_RECNO=941) | Discusses RWS, VSR, TWS and STT as historical public *mode names* | Secondary analysis, not a released APG-77 mode implementation or performance calibration |
| [DCS modding device docs: simple radar](https://modding.caffeinesimulations.com/Aircraft/Lua/Devices/avSimpleRadar/) | DCS `avSimpleRadar` can deliver RWS and STT but **not TWS**; parameter names documented | Unverified version compatibility; current F-22 depends on native FC3 radar and has no independent avSimpleRadar |
| [DCS modding: simple weapon system](https://modding.caffeinesimulations.com/Aircraft/Lua/Devices/avSimpleWeaponSystem/) | Actual station info requires `avSimpleWeaponSystem`, not existing `avLuaDevice` | Replacing the device is an integration change, not assumed safe here |

## Mode ownership and current guarantees

`Weapon_System.lua` owns **requested** presentation modes: 1 NAV, 2 BVR/AIM-120, 3 VS/AIM-9, 4 BORE/AIM-9, 5 GUN, 6 FLOOD/AIM-9, 7 A/G. The `Keys.PlaneMode*` command matches the currently inherited FC3 UI modes; changing HUD graphics doesn't magically add missile handoff. For the F-22 there is no authenticated public full layout for all seven modes.

`HUD_RADAR_REQUEST` = 0 none, 1 RWS request, 2 TWS request, 3 VS request, 4 ACM request, 5 FLOOD request. **These values are not observed actual radar operating modes.** `PlaneRadarChangeMode` in BVR toggles the displayed request. TWS is not implemented by simply toggling this value. Exact availability and lock/target data remain dependent on a later instrumented sensor adapter.

`HUD_AG_SUBMODE` = 1 MAN, 2 CCIP requested, 3 CCRP requested. Until a validated ballistics/target solution exists, UI must display `CCIP N/A` or `CCRP N/A`, no false pipper/launch authorization.

`HUD_WEAPON` is a **mode-derived request**, not a physically queried store/station; avoid false ammo counts, seeker lock or guidance cues.

## Rules for next sections

- Render mode-specific boresight/funnel/seeker/WEZ/attack graphics as documented **generic** approximations; bind target line-of-sight and shoot data ONLY behind an explicit validity flag.
- The gun trigger must release on loss of power/arm/WOW and cannot continue firing because a momentary command stuck.
- Verify syntax in CI; visual mode transitions, inherited radar/weapon behavior, bomb delivery, VR calibration and cockpit markers need DCS tests.
- Actual radar scan and track is a separate subsystem; do not hardcode a real APG-77 range or target model using forum guesses.
