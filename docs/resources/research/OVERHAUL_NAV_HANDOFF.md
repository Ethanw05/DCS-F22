# NAV / CNI / ALT / AP / pilot warning handoff

2026-10-25, America/Denver. Shared source is `o/outputs/DCS-F22`. This is the NAV/AFCS lane's implementation and qualification record; it does not certify real F-22 behavior. No commits or publishing were performed.

## Delivered pilot workflow

AP and ALT have distinct jobs. AP opens a persistent flight-control page without engaging. ALT opens pressure and warning-floor settings and never issues an AP engagement command. Press the same key again to close. The ICP rocker changes pages inside the selected group. Select a field with its adjacent option key, type digits, press that same option again to accept. A changed field/page commits only valid pending input. CLR backspaces; on an empty V/S entry CLR supplies minus. UNDO cancels an entry, then closes. NAV/STPT and the other ICP contexts leave these pages normally. The existing A/G stores entry block is preserved and remains the stores owner's lane.

| Page | Five option-key rows, top to bottom |
| --- | --- |
| AP1 MODES | ALT hold; ATT hold; combined AP/A/T disengage; selected heading; NAV coupling |
| AP2 TARGETS | Heading; barometric altitude ft; vertical speed ft/min; CAS or Mach target; CAS/Mach edit selection |
| AP3 MORE | Radar-altitude hold; V/S hold; CAS A/T; Mach A/T; radar-height target ft |
| ALT1 SETTINGS | QNH; barometric floor ft; radar floor ft; INHG/HPA; STD / saved QNH restore |
| ALT2 STATUS | Actual indicated altitude; radar height; voice mute; voice test/cancel; caution acknowledge |

Targets can be set before engagement; entry does not engage. Initial engagement uses an entered target, otherwise captures the current value. Same active A/T mode toggles off; selecting the alternate CAS/Mach A/T mode switches directly. Paddle release recaptures the relevant current altitude/attitude while keeping NAV/HDG targets. Existing bounded authority, pilot takeover, gear/ground/envelope/power/health and fresh-radio guidance gates remain. NAV controls lateral track only. RALT is height hold with no terrain-following lookahead. ILS remains advisory; there is no coupled autoland.

Mach digits080 mean0.80. Heading entries follow the selected true/magnetic display reference and convert to true before the EFM receives them. Accepted limits: heading000Ã¢â‚¬â€œ359; ALT0Ã¢â‚¬â€œ65000ft; V/SÃ‚Â±6000ft/min; CAS160Ã¢â‚¬â€œ700kt; Mach0.20Ã¢â‚¬â€œ2.00; RALT200Ã¢â‚¬â€œ5000ft. Mouse wheel adjusts a selected field. Barometric floor0Ã¢â‚¬â€œ25000ft and radar floor0Ã¢â‚¬â€œ5000ft, with0=OFF.

## Altimetry: one measured-pressure datum

`NativeAltimetry` is a historical filename, not a private native altimeter dependency. The implementation uses the public `ed_fm_set_atmosphere` callback's actual static pressure in Pa, ICAO pressure-height conversion (troposphere, then the isothermal11Ã¢â‚¬â€œ20km layer) and the selected pressure datum. The only dynamic clock lookup is the existing common World model-time export. It does not depend on the Hornet/F-15 module, internal FM proxy, or a fabricated altitude readback.

Startup setting is29.92inHg. The pilot must enter local QNH; the model does not secretly derive an omniscient local setting. STD selects760mmHg/1013.25hPa and restores the previously selected QNH. The native altitude, cockpit `BAROALT`, ADI digits, HUD counter/needle, AP barometric hold and floor checks share indicated altitude. Changing QNH changes the displayed altitude and the flight path of an engaged barometric hold, as expected. Navigation waypoint elevations and geographic positions remain MSL geometric route data; they are not barometric sensor measurements.

Pressure650Ã¢â‚¬â€œ820mmHg, finite physical static pressure, valid flight-model sample and request freshnessÃ¢â€°Â¤200ms are required. A stale/invalid request does not silently change datum. Invalid indicated altitude hides affected HUD/ADI digits/needle and inhibits/disconnects AP's barometric reference; CAS validity remains independent. ALT status says NO DATA. Numeric parameter storage may retain the last reading but its validity flag is authoritative.

Read-only CockpitBase research established why the earlier adapter could not work: binding_context+16 is wHumanAircraft, and its+280 method returns an enum sensor interface (`get_base_data` height uses enum1). The separate common avFMProxyBase initializer looks up `cockpit::instance()->virtual+16("sensors_system")`; that service is null in this EFM. Transplanting pressure vtable slots from it to the enum sensor object is invalid. All such private altimetry calls were removed. The guarded failed attempts never called a pressure method through the wrong interface.

## Warning policy and audio

Original synthesized phrases: PULL UP twice; ROLL LEFT twice; ROLL RIGHT twice; ALTITUDE twice; FLIGHT CONTROLS; CAUTION. No audio/voice/font assets from paid aircraft were copied. `tools/generate_pilot_warning_audio.py` synthesizes the six WAVs with upstream eSpeak NG1.52.0's formant voice(en-us+f3); no recordings, trained voice/model or synthesizer DLL is shipped as a runtime dependency. Audio/sdef assets are in this project's Sounds tree and follow the project's GPL-3.0-or-later distribution. eSpeak source/tool: https://github.com/espeak-ng/espeak-ng ; generated-output principle: https://www.gnu.org/licenses/gpl-faq.html#GPLOutput .

Own terrain policy samples actual terrain along the current inertial path20times over10seconds. It includes a1second reaction allowance, bank recovery at90deg/s,30m clearance and an estimated1.5g net vertical recovery threshold. Warnings debounce200ms and hold1second. Above60deg bank the recovery instruction is toward wings level; otherwise PULL UP. This is a custom warning heuristic, not recovered F-22 TAWS, certified GPWS or automatic GCAS. It does not move the flight controls.

Floor voice occurs on a downward crossing after being above the selected floor+100ft. Setting a floor while already below shows ALTITUDE without inventing a crossing. Gear down inhibits floor warnings;0disables that floor. Terrain warnings use actual trajectory rather than a gear-inhibit shortcut. Warning visuals remain when voice is muted. Modeled wing/tail structural damageÃ¢â€°Â¤0.5 triggers FLIGHT CONTROLS after a debounce; this is not a complete flight-control computer failure model. Existing oil/hydraulic/generator/canopy cautions can issue generic CAUTION airborne. Power/ground/reset/invalid data are explicit gates.

Urgent terrain speech preempts ordinary cues and MWS/RWR/IR audio. Missile warning preempts an already playing ordinary caution and defers noncritical calls. ACK silences current ordinary control/caution calls; it cannot suppress an ongoing urgent terrain recovery warning. ALT2 voice test is an explicit test, produces no fake HUD threat, and cancels on a second press/power loss. It cycles the actual six assets. Existing RWR_Bearings changes and EW/MWS detection logic remain intact; only audio priority gates changed.

## Simplified IRS lifecycle and uncertainty

The IRS remains a declared simulation approximation: actual simulator velocity is integrated without invented stochastic bias. It now exposes an estimated uncertainty budget rather than implying ideal integration is precise. Aided baseline15m/.1deg; unaided position budget grows1NM/hour up to10NM and heading budget .05deg/min up to5deg. These are intentionally chosen mod parameters, not F-22 performance specifications or probabilistic integrity bounds. Heading/position truth sensors themselves are not randomly displaced.

Steady GPS aiding follows measured position directly, including active pause. On restoration after an unaided interval, velocity prediction plus a50m/s correction bound removes the discrepancy without an instant route jump. Missing/invalid velocity, a model-time rewind or a sample gap>2s invalidates unaided estimation; aiding is required to reseed. Unpowered navigation does not fabricate inertial motion.

Cold/manual alignment needs180s of valid, ground, stationary(<1m/s) conditions. Moving alignment resets. A main-power interruptionÃ¢â€°Â¤5s retains completed alignment. A longer interruption loses readiness; an aircraft previously aligned can use30s of valid GPS-aided airborne recovery. Manual re-alignment still requires the ground process. These timing/backup conveniences are custom policy. GPS-off loss of the unpowered position estimate remains invalid until aiding returns, even if alignment was retained. No automatic AP reengagement occurs after recovery.

## Bezel / keypad integration contracts

Do not add routes in MFD_System here; the overhaul parent owns it. Device IDs remain8NAV,25FLIGHT_GUIDANCE,27ALTITUDE,28PILOT_WARNINGS. Commands below are device-targeted requests; normal packed input decoding still applies to button commands. Absolute-value commands take the raw numeric value, including0/negative where allowed.

| Owner | Commands / values |
| --- | --- |
| NAV8 |10830next,10831previous,10832auto/manual,10833/34range in/out,10835direct,10836reload,10837selectID,10838own-position mark,10839commit stagedcoordinate,10840undo edit,10841WPDSG,10842undesignate |
| Flight25 |10930sourcecycle;10931/32courseÃ‚Â±1deg;10933/34TCNchannelÃ‚Â±;10935X/Y;10936TCNmode;10937/38ILSstep;10939true/magnetic;10940GPSaid;10941leaveOBS;10942manualIRSrealign;10943WPT+undesignate;10944TCN;10945ILS;10948OBS toggle |
| Flight25 absolute |10946TCNchannel1Ã¢â‚¬â€œ126;10947ILSkHz(valid channel);10949course000Ã¢â‚¬â€œ359 |
| Flight25 AP buttons |10950ALT;10951ATT;10952CAS A/T;10953AP+AToff;10954HDG;10955NAV;10956/57HDGÃ‚Â±;10958/59ALTÃ‚Â±100ft;10960RALT;10961/62paddlepress/release;10963/64VSÃ‚Â±100fpm;10965/66speedÃ‚Â±;10967syncheading;10968Mach A/T;10969V/S |
| Flight25 absolute targets |11010trueHDGdegrees;11011baroALTft;11012VSfpm;11013CASkt;11014Mach;11015RALTft. Routes to EFM10520..10525. |
| Altitude27 |11020STDrestore;11021/22pressureÃ‚Â±;11023units;11024absolute mmHg;11025absolute barofloorft;11026absolute radarfloorft |
| Warnings28 |11000ACK;11001test/cancel;11002/03volumeÃ‚Â±;11004mute |

Route/CNI exports include independent `F22_TCN_BRG_VALID`/`RANGE_VALID`, ILS LOC/GS validity, source/reference/course, `F22_NAV_GUIDANCE_VALID`, fresh `F22_NAV_STEER_*` and display strings. `F22_NAV_VALID` describes computed route/map data; it does not authorize AP coupling. Loss of ownship now clears GUIDANCE_VALID as well as STEER_VALID. IRS exports: `F22_INS_READY`, `F22_INS_ESTIMATE_VALID`, `F22_INS_COASTING`, `F22_INS_POSITION_UNCERTAINTY_M`, `F22_INS_HEADING_UNCERTAINTY_DEG`, `F22_INS_STATUS_TEXT`. CNI COM1/2 are not backed by a separately implemented own voice-radio tuning/transmit system; do not advertise UHF/VHF presets, guard, encryption or independent radio audio as operational. Common DCS communications dialog remains the available voice interface.

## Exact implementation files in this lane

Native: `EFM/source/NativeAltimetry.{h,cpp}`; scoped edits to `Autopilot.h`, `RAPTOR.cpp`, `EFM/CMakeLists.txt`; tests `test_native_altimetry.cpp`, `test_autopilot.cpp`. RAPTOR scope is include/reset/update of altimetry, fresh indicated altitude and MAIN_POWER health in navigationFrame,10500..10525 third-value command routing, AP RALT readout and valid modeled FCS damage telemetry. Existing NAV radio backend, AFCS damping and other workers' EFM changes are retained.

Controllers: `Altitude_Settings.lua`, `Altitude_System.lua`, `ICP_Flight_Pages.lua`, `Pilot_Warnings.lua`, `Pilot_Warning_System.lua`, `INS_Model.lua`; scoped `Flight_Guidance.lua`, `Navigation_System.lua`, `Nav_Guidance.lua`, `ICP_System.lua`, `Avionics.lua`, `HUD_Flight_Data.lua`, `devices.lua`, `device_init.lua`. All controller names are under Cockpit/Scripts/Systems unless stated.

Presentation: `ICP/flight_pages.lua`, ICP/page_1 include, HUD/pilot_warnings.lua and tactical_page include, HUD/page altitude validity parent, UFD_LEFT/RIGHT/base_page live BARO footer and validity, MFD_COMMON/adi_page baro validity. Original HUD font/material/scale/collimator resources are unchanged. Audio priority integration: narrow RWR_System/MWS_System/Weapon_System gates. Input additions: keyboard/default.lua and joystick/default.lua, no physical assignments replaced. Six warning WAV/sdef pairs and generator. Tests: `test_altitude_settings.py`, `test_icp_flight_pages.py`, `test_pilot_warnings.py`, `test_pilot_warning_owner.py`, `test_ins_lifecycle.py`, strengthened HUD/nav tests, intentional ADI-validity snapshot update and Lua syntax list.

## Qualification and remaining limits

Core paused acceptance passed on DCS2.9.30.28738: real QNH750mmHg changed indicated altitude3219.95Ã¢â€ â€™2853.88ft; STD760 restored3219.95ft; saved QNH restored; keypad2992/1500MSL/500AGL accepted; AP7000ft target entered with APoff then preserved on engagement; actual original voice sound object reported playing and cancel cleared it. HUD altitude needle now follows that same datum. Five DCS-native ICP screenshots inspected: `o/work/ap-alt-warnings/icp-native-pages.png`; header/help moved inside the five physical apertures after the first capture caught clipping.

Actual physics descent (no synthetic altitude/velocity/warning injection) crossed the3000ft barometric floor and issued ALTITUDE. At approximately1751ft radar height, vertical speedÃ¢Ë†â€™125.9m/s and pitchÃ¢Ë†â€™38.7deg, PULL UP had priority3 with the actual sound object playing. Test froze at that point. Actual banked warning flight and full FCS-fault flight injection are not claimed; handedness/inverted/invalid-terrain/fault validity and priority are exercised in actual-Lua tests. Real RWR/MWS simultaneous attack audio remains a broader combat flight qualification item.

Native TACAN16X ground T/R, actual ILS advisory reception, NAV/ALT/CAS hold, takeover and signal/power lifecycle were qualified by the preceding navigation baseline (guide evidence). A/A TACAN, representative maps, turbulence, engine-out and the full fuel/stores/Mach envelope remain unqualified. This change does not turn them into supported proof claims.

Final INS/native acceptance and installed checkpoint are below. Runtime/build ownership was returned to the overhaul coordinator after closing only this chat's owned acceptance process. No other/user DCS process was stopped or reloaded.

## Research basis

- Top Mach ALT/AP page separation: https://downloads.justflight.com/support/manuals/TMS_F-22A_PremiumEdition_UserManual.pdf (ALT/AP pages22Ã¢â‚¬â€œ23). Used as a simulator workflow reference, not recovered real F-22 HOTAS software.
- FAA altimeter setting / standard-pressure convention: https://www.faa.gov/air_traffic/publications/atpubs/aip_html/part2_enr_section_1.7.html .
- NASA standard-atmosphere layer model: https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/earth-atmosphere-equation-english/ .
- Local DCS Hornet/Viper manuals and common TF-51 receiver/altimeter Lua were read as convention/API references; no paid DLL, Lua implementation or assets are redistributed.

## Final native / installed checkpoint

Final accepted native run: `o/work/ap-alt-warnings/native-check-complete.log` and `dcs.log`. QNH/STD/keypad/needle/audio contracts passed again with the final standalone native DLL and full literal dependency closure of the selected Lua entrypoints. No COCKPITBASE startup/runtime Lua error was present in this final log. Unrelated stock payload database warnings are not mod cockpit failures.

Real physics40s GPS-off interval: IRS READY/ESTIMATE/COAST valid, position budget35.5788m and heading budget0.133335deg. GPS restore remained valid and returned the budget to15m/.1deg. At about62s, AP and CAS A/T remained engaged, barometric target3218.7818ft, indicated3212.8312ft, errorâˆ’5.9506ft, vertical speed0.0390m/s. These are a steady-airframe case; they do not qualify the full AP envelope. The first estimate candidate incorrectly predicted movement under steady GPS during active pause; the corrected policy follows measured position directly while continuously aided. Its regression test covers this explicitly.

Native altimetry now keeps the prior fresh healthy publication while solving the next sample. It publishes invalidity only on an actual failure, eliminating artificial per-update VALID=0 pulses that concurrent cockpit readers could catch.

Verification:12/12 compiled CTest checks pass after the final native change. The final focused set is13/14 complete Python/Lua scripts passing: all AP/ALT/INS/warnings, native startup, HUD agreement, navigation guidance/entry/designation, ADI snapshots and syntax checks pass. `test_navigation.py` passes route math, device lifecycle and render construction, then its legacy MFD_System bezel-routing assertion fails under the parent's concurrent menu redesign. Exact failing contract was sent to that owner; this lane did not modify MFD_System. The earlier live global checkpoint67/70 had only the concurrent A/G release/usability/overhaul-release cases failing; those belong to the stores owner. The source tree continues evolving across lanes; do not describe these as an all-mod green suite. Final captions were shortened and header strings bounded to30characters after the native layout inspection; no font/geometry was changed for that cleanup.

37 owned runtime files were installed/byte-verified, manifest `o/work/ap-alt-warnings/owned-installed-handoff.json`. Final native DLL SHA256: `4e2d060bf34f730314ef8a93b147f36ad02021fa45c3fafa288875b1f19adb4e`. `installed-manifest.json` records the tested dependency-closure checkpoint; shared AA/stores sources can subsequently diverge under their own owners. No broad folder replacement was used.

Runtime/build handoff was sent to overhaul coordinator01a17555-a30e-7a52-a1c9-b2b5407b3cd5 and ground-render owner01a17586-a292-7b90-b998-f04c2f64570d. All owned test processes were closed, control/evaluation files restored by the harness, and this lane has no remaining runtime reservation. Other workers may now proceed under coordinator ownership. No commits, publishing or extra new Codex chats were created.

## NAV-03 radio follow-up moved to its own handoff

The authoritative factory/ABI evidence, isolated candidate, default-OFF integration patch, hashes, tests and remaining native qualification are in [OVERHAUL_COMMS_HANDOFF.md](OVERHAUL_COMMS_HANDOFF.md). COM remains inactive and uninstalled. Exploratory COM paragraphs are removed here to avoid superseded accessor/PTT interpretations. Existing NAV/ALT/AP/warning behavior above is unchanged.

Coordinator follow-up: parent reported migrating the legacy NAV-routing test to the new family PB2 entry and that it passes. The earlier13/14 focused checkpoint above is historical. Parent also reported combined vehicle/stores/NAV Debug14/14 CTest; this lane did not independently rerun that combined checkpoint.
