# NAV HUD: actual mission waypoint computation

This subsystem is independent of the earlier handwritten flight-display illustration. Under the general primary-flight-reference rules identified in [MIL-STD-1787](https://quicksearch.dla.mil/qsDocDetails.aspx?ident_number=37143), the guidance cue must be derived from real navigational coordinates rather than moved arbitrarily.

## DCS evidence

- [DCS cockpit device stubs](https://modding.caffeinesimulations.com/Aircraft/Lua/Stubs/DeviceStubs/): `get_mission_route()` returns the aircraft mission-editor flight plan, and `get_model_time()` is available.
- [ED forum cockpit scripting example, 2017](https://forum.dcs.world/topic/157970-export-and-use-coordinates-in-mission-file/): route waypoints expose `x`, `y`, and `alt`; `get_base_data().getSelfCoordinates()` returns local x, altitude, and map y.
- [USAF HUD study, 1994](https://pubmed.ncbi.nlm.nih.gov/8018075/) supports clearly legible steering cues in a primary-flight-reference HUD, without supplying F-22-specific coordinate tuning.

## Code/data contract

`Systems/Navigation_System.lua` is the sole producer of `HUD_WP_*` data. It ignores route positions lacking numeric coordinates and skips the first waypoint if a flight plan has a departure/spawn point. Steering commands use the already inherited next/previous DCS cockpit keys; no fake mission path is generated.

`Systems/NavGeometry.lua` calculates waypoint LOS in the body frame from actual x/east, y/north, altitude coordinates and heading/pitch/roll. The HUD marker is displayed only when the real waypoint is forward and inside a **provisional** ±15° horizontal and ±12.5° vertical usable field of view. The distance text remains valid for offscreen targets while `HUD_WP_CUE_VALID` controls the marker itself. No path/waypoint -> no marker or range.

### Assumptions and tests

- DCS heading sign conventions, roll rotation, coordinate meaning and `get_mission_route` availability must be verified with test waypoints north/east/south/west and 0°,90° banks.
- In particular the HUD's figure is not an optical camera calibration and an accurate F-22 eye point remains unknown.
- The generic 30°×25° advertised historic HUD FOV is used as a conservative cue clipping assumption, NOT as measured optical geometry.
- Waypoint altitude `alt` is not assumed to equal ground height; **do not use mission navigation points as targets for JDAM/CCIP/AG designation automatically**.
- Lua device numeric data is validated; DCS APIs themselves still need in-game validation.
