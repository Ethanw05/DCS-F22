# A/G boresight terrain markpoint

**Research step, before code**: [DCS OpenSource Terrain module](https://modding.caffeinesimulations.com/Aircraft/Lua/Modules/Terrain/) and [ED modding forum's cockpit Terrain examples](https://forum.dcs.world/topic/188460-terrain-related-functions-example-code/) specify `require("terrain")`, `Terrain.GetHeight(x,z)`, map axes (x north, z east) and height in meters MSL. The general [US Navy HUD A/G display explanation](https://navyflightmanuals.tpub.com/P-1219/Hud-Air-To-Ground-Symbology-25.htm) establishes markpoint/reticle *conventions*, but not the F-22's production implementation.

**Feature**: The ICP `MARK` switch (previously commented out) now sends a custom event when `HUD_MODE==7`. An independent `AG_Mark_System.lua` traces aircraft boresight against DCS terrain elevations and saves the first intersection, if one exists within 40 km. A second press clears it. In other modes MARK preserves the existing kneeboard-mark command.

This stores a *sim-world point*, not a valid weapon target. It can be rendered and can show changing slant range based on actual positions; the marker clips when it leaves the provisional ±15°/±12.5° HUD field of view. It does not provide CCIP/CCRP, bomb release consent, GPS coordinates to a JDAM, sensor targeting, ground radar mapping, or native FC3 stores integration. Those remain separate research and code tasks.

Assumptions: DCS aircraft heading/pitch convention, terrain sampling availability in cockpit Lua, proper cockpit clickable switch bounds, real HUD combiner and optical projection all require in-game testing. Cliff/terrain transitions are solved by step + bisection, so very narrow obstructions may be missed; this is a **visual mark**, not a certified avionics solution.


### Internal MARK event reliability correction

The first implementation used `dispatch_action(nil,10074)` to send a new command to a separate Lua device, but this isn't a verified registered native DCS aircraft action. It now increments the shared `HUD_AG_MARK_SEQUENCE` parameter from the ICP, which `AG_Mark_System` consumes once, independent of the DCS action dispatcher. The standard kneeboard MARK command is unchanged in non-A/G modes. Sequence is initialized on markpoint device startup to prevent acting on a stale request. No native weapon targeting or JDAM data is emitted.
