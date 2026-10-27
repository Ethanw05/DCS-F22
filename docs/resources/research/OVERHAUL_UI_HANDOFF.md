# Stores and display navigation overhaul — 25 October 2026

This source pass retains the original front-view weapon-bay artwork visible in the audited USAF museum photograph. It uses Hornet-style contextual store/mode/program controls as an explicitly designed adaptation. These bezel assignments and program fields are not claimed to be recovered F-22A operational software.

## Operational layout

The left display defaults to Attack (logical7), right to Defensive (7), lower to Stores/Bays (5). Main-display Tactical requests its current tactical format; Navigation and Stores open the lower display; Systems opens the left systems menu. The small-display menu groups Tactical, Navigation, Stores, Systems. Systems contains ENG/FCS/FUEL/ADI/CHECKS. Setup and diagnostic telemetry are secondary main-display destinations. Placeholder MAP/SYS pages remain historical files but are not operational menu choices. Functional A/G ground radar is distinct from the old placeholder MAP.

Stores is one bay/inventory picture with home, PROG, MODE, DOORS and FUZE sublevels. Top weapon keys are actual carried ground-weapon classes. Side-bay defensive missiles remain visible in the inventory; they do not become ground-weapon selections. Original front-view artwork is preserved. Per-station native counts and selected-class outlines come from Weapon_System. The active program station has a separate blue outline. Engine THRUST is actual modeled achieved thrust divided by modeled available maximum at the current condition; absent vehicle contract shows RPM instead.

Home displays only the selected GUN/CCIP/AUTO mode. MODE opens compatible alternatives and consumes blank/unavailable keys. Guided coordinate bombs do not offer CCIP. The weapon capability registry owns all compatibility decisions. FUZE displays STORE DEFAULT/FUZE NOT ADJUSTABLE because no cockpit fuze adapter is qualified; no decorative timing setting is offered.

## Stores keys and numeric entry

Physical bezel numbers: top1..5 left-to-right, right6..10 top-to-bottom, bottom11..15 right-to-left, left16..20 bottom-to-top.

| Key | Home / normal action | PROG action |
| --- | --- | --- |
|1..5|Select displayed carried ground-weapon class|Same|
|6|MODE compatible alternatives|Same|
|7|Cycle retained profile1/2|Same|
|8|Enter total QTY|Enter PULSES|
|9|Enter current interval: time ms or impact spacing ft|Same|
|10|FUZE readback|Same|
|11|DOORS actual open/transit/closed readback|Same|
|12|PROG|Return home|
|13|Parent MENU|Return home|
|14|Unassigned|Toggle time/impact-spacing units|
|15|Unassigned|Single/pair|
|16|Unassigned|Copy live designation to active weapon station|
|17|Unassigned|Clear active station target|
|18|FCS|Step active program station|
|19/20|FUEL/ENG|Same|

MODE uses top1 GUN/2 CCIP/3 AUTO only where capability permits, right6/bottom13 return. DOORS has a ground override on right10, weight-on-wheels gated by MFD and achieved actuator supply in Weapon_System. Flight bay motion remains automatic. Ground override does not imply a separate weapon-selection action.

Quantity/time/spacing/pulses open one transactional numeric entry on the physical front keypad, including zero. CLR removes one digit, OP5 commits, UNDO cancels. SAFE NAV programming is permitted. Invalid input does not change the retained profile. Return, page change, power loss and incompatible master-mode changes cancel entry. Program changes cancel existing release consent. Aircraft mode/weapon/release state remains Weapon_System-owned; display navigation never manufactures those values.

## Integration files and contracts

MFD_COMMON/lcd.lua supplies native write-only-safe drawing primitives, stencil and bezel positions. MFD_COMMON/menu_page.lua supplies the three small-display menus. MFD_CENTER/stores_program.lua supplies the unified bay format; bay_page.lua is its wrapper. Systems/Stores_Display.lua routes bezel navigation. MFD_System owns display defaults, page/focus, defensive inspection and CM-editor dispatch. ICP_System has only a narrow stores-context change allowing NAV alongside A/G. PMFD_System changes are its menu family and show-Tactical hook; tactical sensor behavior remains owned by that lane.

UI commands10822/23/24 on MFD_SYSTEM open lower Stores/lower NAV/left Systems;10825 on PMFD_SYSTEM shows Tactical. These are device scoped. SMS_PROGRAM_PAGE is1 only while the powered lower Stores format is active. SMS_UI_PAGE is0 home/1 program/2 doors/3 fuze/4 mode. Numeric fields and program/station values are Weapon_System-owned. Full backend contract is in OVERHAUL_STORES_HANDOFF.md.

Defensive routing: right6 NEXT10906,7 PREV10907,8 DETAIL10908;15 ALL/THRT10902,13 PWR10900,11 MUTE10901 to RWR_SYSTEM. Left20 PROG10910,19 CHAFF10911,18 FLARE10912,17 INTVL10913,16 REPS10914 to EW_SYSTEM. Both edges reach the original device even after a page/power transition, so latched controls do not stick. Unpowered/decoded release edges cannot select a page.

MFD_System and Engine_Data now consume EFM_VEHICLE_VALID-gated achieved hydraulic pressure, oil, temperature and nozzle state. The previous pressure/nozzle/oil proxies are fallback only when the EFM vehicle contract is absent. Vehicle approximations are documented in OVERHAUL_VEHICLE_HANDOFF.md.

## Evidence and remaining qualification

Actual-Lua/write-only native-element tests cover unique names, valid parents, persistent labels, fully predeclared SMS handles, button routing, class-window identity, compatible modes, retained program state, SAFE NAV keypad zero/commit, power/mode/page cancellation, blank-key consumption and release-edge ownership. The independent reviewer migrated only obsolete menu expectations in existing A/G/NAV tests, retaining backend assertions.

Source-driven bitmap/font previews are in DlcBuilder/stores-overhaul-2026-10-25/previews. They use actual Lua, original bay textures and the shipped font with synthetic parameter fixtures. They are layout evidence, not DCS screenshots or flight validation. The reusable old rasterizer can drop text when reused between fixtures, so fixtures are rendered in separate processes and native graph visibility is checked independently. Native LCD fit, multi-head/VR optical performance and complete release/impact flight matrix require their own checkpoint.

## Research basis

- Historical architecture and display roles: [Brower, The Avionics Handbook chapter32, §32.3.7](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf).
- Original bay graphic reference: [USAF National Museum cockpit photograph080116-F-1234P-002](https://www.nationalmuseum.af.mil/Upcoming/Photos/igphoto/2000412735/).
- Official local DCS FA-18C Early Access Guide, stores303–306 and ground radar186–198: carried wingform inventory, compatible employment selections, MODE sublevel, quantity/interval conventions.
- Official local DCS F-16C guide, inventory366 and stores619–623: inventory versus employment, retained profiles and contextual modes. The physical keypad is this mod's adaptation; it is not proof of a real F-22/F-16 shared input convention.
- Full source provenance, local PDF locations and confidence levels remain in [the historical50-finding audit](../../audit/README.md#retired-report-a25).

Physical oil caution is a declared mod estimate at100psi. All three ENG pages now rotate the oil needles from OIL_L/R PSI at the retained270psi sweep, matching numeric readout and pressure-based color.

Operational DMS page cycling skips legacy side-display bay duplicates. Existing ENG/FCS bay shortcuts now open the primary lower Stores display; left SMS shortcuts are labeled ATTACK to match their new role. Legacy bay files are retained for history/compatibility but no longer operational menu/cycle destinations.

Main-menu rightPB6 NAV LYR andPB7 RF/IR toggle the existing tactical navigation/passive layers through device-scoped RWR10915/10916. Green boxes show actual layer state; their release edges return to that owner even after leaving the menu.


## Native checkpoint after merged vehicle/stores/menu integration

DCS native held-mission UI acceptance passed: actual default L7 Attack/R7 Defensive/C5 Stores; achieved hydraulic3950psi matches display; SAFE NAV quantity2 and interval200ms accepted through physical keypad including zero; capability MODE popup/CCIP return, PROG/DOORS/MENU and ENG selection/release behavior; selected-threat and CM controls. Master arm remained SAFE. No COCKPITBASE startup/runtime Lua error. Parent closed only its owned DCS process before handing runtime to ground-video owner.

Artifacts: DlcBuilder/stores-overhaul-2026-10-25/native-ui-check.log, native-ui-dcs.log, native-ui-results.json and ui-installed-manifest.json. F22-Overhaul-*.png are native captures. The default forward camera cuts off the physical lower display, so those forward captures prove Attack/Defensive fit but do not yet prove lower Stores legibility. A separate downward camera inspection is required. This held check is not a ballistic/impact or full envelope flight result.

Shared-source checkpoint before the subsequent HUD and ground-video integration:79/79 Python/Lua scripts. Merged Debug DLL:14/14 compiled tests, independently repeated by reviewer. Later changes require updated checkpoint evidence. The native harness initially sent keypad digits before a queued cross-device command could run during hold; it was corrected to step simulation between pilot actions before the accepted run.

GUN is a global cannon mode, independent of retained bomb profiles. Gun home shows CANNON20MM and actual round count; bomb QTY/interval/fuze/program controls are hidden/consumed. Selecting a carried ground class restores its retained CCIP/AUTO profile. Cannon pickle cannot start a bomb program; cannon firing uses the trigger.


Left Attack is now contextual: A/A keeps selected-track/support detail; A/G uses the existing weapon/target/solution owners for current weapon/mode, active station, live versus stored coordinate, solution state and estimated guided LAR. It does not create another target or sensor. Unguided/gun range/TOF are hidden for coordinate-guided weapons because free-fall prediction is not a valid guided arrival-time estimate. TopPB2 opens lower Stores;PB3 brings up main Tactical; other unlabeled former SMS bay controls are consumed. AA and AG formats are mutually exclusive by HUD master mode, including backgrounds.


## Reference-based Defensive overview

The later direct human clarification controls affiliation colors: RED hostile, GREEN positive-friendly, YELLOW unknown. CYAN is reserved for actual verified wingman/flight membership; no such data is fabricated. This supersedes the earlier cyan-for-all-friendlies interpretation of the museum photograph.

The right normal page now follows the public photo's two fine blue rings, compact white ownship/bearing stems and lower-right expendable readbacks. Large headers, explanatory footers and the editor row are removed from normal use. Source/age inspection and manual CM editing remain behind DETAIL. Default is the overview. Unlabeled normal-view buttons consume input; MENU, DETAIL and ALL/THRT remain visible. Real ranged tracks use existing radar range; passive-only RF/optical tracks use fixed outer bearing ticks, never strength-derived range. Source-specific RF/optical observation times control alert/coast, independently of fresh radar updates. The common source identities are unchanged. Vertical/unplottable directions are filtered before the16-contact bound; every circle is one native line mesh, rather than72 elements.

Defensive_Overview publishes a complete invalid construction snapshot. MFD independently ages it at0.25s so a stopped producer cannot leave a current-looking picture. All affiliation and uncertainty limits remain those of the actual common sensors; photograph geometry does not manufacture friendly/hostile/range evidence. The actual-Lua preview is labeled synthetic; native fit remains a separate test.

## User-requested F-22 ownship correction — 22:56 MDT

The Defensive overview now uses the aircraft and canopy contours from the existing FCS artwork, replacing the stick-aircraft symbol. `MFD_COMMON/f22_outline.lua` records the original `fcs_page.dds` SHA256 and preserves its aircraft proportions. The disconnected FCS control labels are excluded. One batched native line element draws the 61 contour vertices; the original texture and FCS pages are unchanged.

The actual overview model, native-element construction, visible controls, freshness and owner-routing checks pass after this two-file change. A complete actual-Lua preview was visually inspected at `D:/Codex-F22-Overhaul-2026-10-25/previews-defensive/defensive-fcs-outline-2256.png`. Its contacts are synthetic; it is not a native DCS screenshot. Ground-video validation owns the next coordinated native install and will include the new outline resource.

## Matching native capture inspection

The subsequent owned DCS checkpoint passed the full 91/91 source suite before copying. Native `F22-Ground-Video-MAP-225717.png` confirms the right display renders the outlined F-22 and two rings. Native `F22-Ground-EW-Stores-Down-230316.png` exposes the complete lower Stores home page: original front bay graphic, selected MK-83 class, current CCIP mode, station inventory and bezel labels are contained within the LCD. The coordinator independently inspected both original 3440×1440 screenshots and native-pixel detail crops. This supersedes the earlier forward-camera limitation for home-page placement; it does not qualify VR readability, every programming subpage or ballistic accuracy.

The final run04 archive also contains native HOME, MODE, PROGRAM, ENTRY and DOORS close views, under `D:/Codex-F22-Overhaul-2026-10-25/ground-build/run04/screenshots/`. The coordinator inspected MODE/PROGRAM/ENTRY/DOORS. Layouts fit, but ENTRY exposed an unsupported-glyph defect: the empty input used underscores, absent from the shipped FONT_PFD descriptor. Source now uses four supported hyphens. The actual Stores controller/binding checks and a new real-font literal check pass. This single-file correction was made after run04 and is not credited to its screenshot; native verification is queued with the later stores flight slot. The current warning session was not changed.
