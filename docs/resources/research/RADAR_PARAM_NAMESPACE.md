# Radar mode namespace / electrical separation

DCS `avSimpleRadar` has a documented native `RADAR_MODE` parameter with numeric modes **1 SEARCH, 2 acquisition attempt, 3 STT lock**. The pre-overhaul PMFD invented a different meaning for that same globally shared parameter (`0 RWS-selected / 1 TWS-selected`), writing values once per frame. That would corrupt native mode readback whenever an actual `avSimpleRadar` is integrated.

Fix: all user-requested RWS/TWS selection state in `PMFD_System.lua`, PMFD text, `ICP_System.lua` and weapon HUD code now uses **`PMFD_RADAR_SELECTION`**. `RADAR_MODE` is reserved for native radar status only. This is not yet a native radar, and doesn't unlock APG-77 behavior; it unblocks connecting a host radar without the mod forcing it to SEARCH/OFF.

Sources: [DCS native radar parameter details](https://modding.caffeinesimulations.com/Aircraft/Lua/Devices/avSimpleRadar/) and [ED forum radar example + FC3 combination warning](https://forum.dcs.world/topic/188347-basic-radar-example-code/). Validate PMFD radar OSB toggles and BVR HUD requests against native FC3 mode selection in actual DCS.
