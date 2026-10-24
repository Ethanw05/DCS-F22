# Read-only radar STT telemetry bridge (no fake radar simulation)

## Source decision

Read before implementation:
- [DCS avSimpleRadar contract](https://modding.caffeinesimulations.com/Aircraft/Lua/Devices/avSimpleRadar/): `RADAR_STT_RANGE` (meters), `RADAR_STT_AZIMUTH`/`ELEVATION` (radians), `RADAR_STT_FRIENDLY` for real single-target track. `avSimpleRadar` supports RWS and STT **but not TWS**, and requires `avSimpleElectricSystem`.
- [ED modding forum radar example](https://forum.dcs.world/topic/188347-basic-radar-example-code/): warns that mixing simple radar/weapon systems with inherited FC3 avionics can break guided A/A weapons. Consequently this commit does **not** silently replace the F-15C/FC3 host radar.
- [USAF F-22 2002 HUD](https://www.safety.af.mil/Portals/71/documents/Magazines/FSM/fsmjun02.pdf?ver=2017-03-28-101049-403): authentic primary-flight layout; does not establish exact F-22 radar symbology.
- [MIL-STD-1787](https://quicksearch.dla.mil/qsDocDetails.aspx?ident_number=37143): generic flight/weapons symbology standard, not an APG-77 manual.

## Integrated

`Systems/Radar_Data_Bridge.lua` is an `avLuaDevice` that passively reads documented native STT parameter handles. It never creates targets, acquires locks, steers a radar, sets TWS, or supplies missile guidance. Validity gates require radar selected power, main power, weapon master mode 2–6, realistic finite range/angles and changing telemetry at least every two seconds. Data staleness, power loss, navigation mode and invalid geometry all clear target validity. It publishes HUD `A/A_TARGET_VALID`, `A/A_CUE_VALID`, slant range NM, relative azimuth/elevation, IFF and a readback availability flag.

The PMFD labels a live STT return **only if the interface actually publishes a valid one**. The HUD shows its track box only within approximate FOV, and the gun gets a measured range label without pretending it has a ballistic lead solution. A friendly target does not produce a SHOOT cue.

**Critical limit:** The inherited FC3/F-15C radar may provide **none** of these compatible STT parameter handles. In that case the displays correctly show NO TRACK. If this happens, a different full sensor/weapon host implementation is required. Native F-15C track/export APIs cannot be assumed from undocumented names. TWS on the current PMFD is a native requested **selection**, not simulated APG-77 tracking.

## Tests required in DCS

- Lock/unlock targets with and without active native radar, see whether `RADAR_STT_RANGE` changes and whether `RADAR_STT_*\u00a0` handles are published at all.
- Loss of power or target lock clears target after ≤2 s; range meters→nautical miles correct, IFF values -1/0/1 display.
- 15° az/12.5° el cue limit and no ghost contact when mission restarts.
- Confirm BVR request and PMFD radar selection stay synchronized after both keyboard and OSB inputs.


## Search-return B-scope follow-up

Read [ED modding discussion with extracted RADAR_CONTACT_%02d_* conventions](https://forum.dcs.world/topic/188347-basic-radar-example-code/). The host parameter families identify individual *returns*, not multi-target TWS track files. This patch passively observes the first twelve `RADAR_CONTACT_01` through `_12` range/azimuth/time values, drops invalid or unchanged-for-two-second samples, and maps genuine contacts into a fixed +/-60° azimuth, 80-NM B-scope. It publishes `HUD_RADAR_SEARCH_RETURNS` and plotting parameters without controlling underlying radar detection.

**Not implemented:** an APG-77 AESA radar, physically modeled beam/PRF/clutter/target RCS, TWS correlation, datalink and true AMRAAM fire-control. An aircraft with inherited FC3 avionics may leave these parameters unset. The scope then correctly has no plots; actual detection and missile guidance remain FC3 behaviors.
