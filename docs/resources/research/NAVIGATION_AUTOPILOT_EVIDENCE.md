# Navigation and AFCS evidence - 25 October 2026

## Public F-22 evidence

Ronald W. Brower (USAF), "F-22 Avionics", The Avionics Handbook, 2001, chapter 32, identifies the integrated CNI navigation functions as GPS, TACAN and ILS, with MLS described as growth. The architecture includes an advanced ring-laser-gyro inertial reference system. This supports the equipment families; it does not establish today's production F-22 control laws, alignment times, menus or display details.

Public chapter: https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf

AFMAN 11-2F-22A Vol. 2 is an aircrew evaluation publication, not an aircraft systems/flight manual. It was consulted as context rather than treated as an authoritative AFCS mode specification. No allegedly classified or restricted flight manual is a prerequisite for this implementation.

## Hornet presentation and control precedent

Eagle Dynamics' installed DCS FA-18C Early Access Guide EN, pages 121-122, figures 42-44: normal WYPT steering uses command-heading guidance and range/time readouts. WPDSG explicitly converts a selected waypoint to a target, with a Target Designation diamond. Pages 137-138 cover TACAN; the autopilot section describes conventional ATT, HSEL, BALT, RALT and CPL choices.

Official manual: https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf

Installed reference Lua: FA-18C/Cockpit/Scripts/Multipurpose_Display_Group/HUD_AVQ32/indicator/Pages/HUD_common.lua. Ordinary command-heading strokes and target-heading diamonds use separate controller arguments. Designated-waypoint marker visibility is independently controlled. Course steering is presented around the velocity vector with 4/8-degree reference dots. These are Hornet-inspired conventions, not claims of identical F-22 symbology.

## Live IDA MCP observations

Read from the user's existing MCP instances: CockpitBase.dll (13337), FA18C-unpacked.dll (13338), Weapons.dll (13339). No proprietary binary or IDB is redistributed.

- Hornet callback registry 0x1804E4C50: command-heading 0x1804E2AB0 separates ordinary and target navigation data. It wraps relative heading and clamps at +/-15 degrees.
- Hornet designated-waypoint visibility 0x1804DF210 uses a distinct validity/coordinate path; ordinary waypoint selection alone does not enable it.
- Hornet course-steering enable 0x1804E3440 and dots 0x1804E3400 are separate from target designation.
- Hornet ILS callback 0x1804D9720 subtracts vertical deviation for the horizontal fly-to bar.
- Common avTACAN updateRangeBearing 0x1802EA990 converts measurement meters to nautical miles (factor 1/1852). getRange 0x1802E9FA0 returns that stored NM value. The adapter converts it back to meters at its boundary.
- Common avILS update_LOC 0x1802E1920 and update_Marker 0x1802E19C0 publish 0.6 times angular deviation, with separate validity. Positive GS error is high; the display inverts it to a fly-down bar.
- Common avDevice::start starts the activity timer; make_default_activity alone does not.
- avTACAN factory aliases are not registered in this host. The adapter owns one common receiver using its verified constructor, initialization, context, start, electrical connection, release and destructor contracts.
- TACAN and ILS connectElecPower take DC then AC. The current bridge preserves separate achieved left/right generator enables. One surviving engine generator plus usable DC is the declared estimated receiver feed; battery/GPU/APU AC conversion remains unqualified. See [CNI-03](../../overhaul/CNI-03.md).

CockpitBase qualification: PE timestamp 0x6ac12468, SizeOfImage 0x59a000, DCS 2.9.30.28738 Windows x64. WorldGeneral supplies the simulator map conversion and magnetic variation. All 34 exported contracts were checked in the local PE export tables. Receiver use fails closed on a different CockpitBase ABI.

## Explicit approximations

ATT/HDG/ALT/RALT/NAV implement conventional fighter relief behavior. V/S, CAS hold and Mach hold are mod extensions; the exact production F-22 mode set and gains are not established by these public references. Current BALT captures standalone indicated pressure altitude from the selected QNH/STD setting. Radar and generic standby pressure measurements retain independent validity. See [NAV-WP03](../../overhaul/NAV-WP03.md).

The current two-reference simulation uses explicit normal480/retained90/training30-second estimates, independent component health, separate NAV/HUD/right-SFG selection and independent INS_Model state. GPS supplies checked host observations; coasting uncertainty and correction limits are estimates. Production drift/satellite geometry/jamming/spoofing and automatic airborne realignment are not claimed. The official indexed AFMAN11-2F-22AV3 (20 September2018), p36 §7.9.1.1 was reread27 October2026 for the alternate GINS/SFG distinction; direct PDF access still returned403. See [NAV-WP02](../../overhaul/NAV-WP02.md).

CDI full scale is 2 NM for route/OBS. ILS display sensitivity is conventionally +/-2.5 degrees LOC and +/-0.7 degrees GS. NASA describes these conventional angular values in https://ntrs.nasa.gov/api/citations/20140003882/downloads/20140003882.pdf ; localizer installation widths can vary, as explained by FAA AIM https://www.faa.gov/air_traffic/publications/atpubs/aim_html/chap1_section_1.html . These are display choices rather than certification of each DCS facility.

ILS is advisory only. No automatic ILS capture, autoland, VNAV, predictive terrain following, RF/accuracy model unique to the F-22, TACAN audio identification, ADF, ICLS or MLS is claimed. Manual UTC/arrival timing is a bounded planning aid with no throttle authority. Ground TACAN T/R was exercised; A/A TACAN modes are exposed native requests but remain unqualified.
