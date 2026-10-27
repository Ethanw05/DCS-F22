# A/G radar rebuild and native evidence — 26 October 2026

**Historical checkpoint:** [the later Hornet parity audit](../../audit/README.md#retired-report-a21) supersedes this document's current-behavior, API-parity, two-hit confirmation, camera, DynamicParam and INTL descriptions. Its native measurements remain historical evidence of the specific earlier build, not certification of Hornet parity.

This document supersedes the terrain-return/dot-map acceptance claims in the earlier ground-radar notes. The changes here were implemented directly, without delegating to agents or messaging other chats. DCS flight measurements and native texture readbacks are the acceptance evidence; cockpit pictures are not being used as proof of sensor operation.

## Why the previous imagery remained broken

1. **The aircraft obstructed its own radar shadow render.** The shared renderer includes model geometry in the radar shadow pass. An offset that looked successful with ownship in active pause failed in actual motion. The previous 12 m clearance, even with fresh EFM pose interpolation, produced only 13–17 occupied samples out of 4,096 in level flight at about 250 m/s. In a controlled 30 m → 12 m → 30 m moving-flight sequence, the output recovered to roughly 2,300–2,500 samples, collapsed again, then recovered again. Gain remained 0.5. Changing gain was not the fix.
2. **The old cockpit pose lagged the physical/rendered aircraft.** At flight speed that delay placed a nominally forward camera inside or behind the aircraft. The camera now receives a quaternion/position/velocity snapshot from `ed_fm_set_current_state`, predicts it to the callback's model time, and uses the same captured view for camera, world point, and parameters. A separate renderer clearance of 30 m is supported by the moving-flight experiment. It is a graphics workaround, not the actual APG-77 antenna position.
3. **Projection and image-reference contracts were incomplete.** The recovered MAP camera uses the selected horizontal sector, a 90° vertical FOV, tangent-ratio aspect, and 10 m near clip. The orthographic map is retained for a sweep. Overlay/TDC coordinates formerly followed a newer cockpit pose. They now follow the native sweep reference while terrain is visible; GMT without terrain follows current ownship. Freezing retains the image/reference and sweep phase instead of erasing it.
4. **Anonymous ground-clutter records were being treated as a ground radar.** Those records were neither terrain imagery nor identified vehicle tracks. They could not supply useful GMT/GMTT. The air-radar clutter generator is now disabled. Terrain comes from the shared renderer, and moving vehicles come from a separate bounded native scene detector.
5. **The acceptance process was inadequate.** A populated image in active pause, a parameter callback, or a screenshot did not establish moving-flight performance. Calling that fixed was premature. The new logs distinguish renderer availability, actual GPU signal, source frame, contact gates, tracking, and weapon handoff.

## What is implemented

| Function | Current behavior |
|---|---|
| MAP | Shared DCS terrain/object reflectance, terrain/object shadows, real-beam processing, sweep, gain, range and azimuth controls; georeferenced TDC terrain designation |
| GMT | Default clean background; separate confirmed moving-vehicle bricks, scan history, native positions/velocities, terrain and object line-of-sight tests |
| GMTT | TDC/MFD acquisition, four-bar selected symbol, speed, heading, motion vector, stopped-target retention, coast and expiry |
| INTL | Terrain background and GMT contacts together; can disable the background for a clean GMT page |
| Controls | Top: MAP, GMT, DESIG, CLEAR, INTL. Existing range, azimuth, recenter, freeze and emission controls retained |
| Target handoff | Radar coordinates pass through the existing ground-designation owner to selected-store AUTO/JDAM delivery |
| Stores | Existing aircraft/bay-based stores page retained. Quantity/interval stay in the front keypad page opened by Stores HUD |

The detector executes after the owned common radar's native `update_radar` callback. It does not query the scene from the graphics thread or EFM worker. It copies contact values and retains no borrowed scene-object pointers. Search covers the current narrow azimuth slice, with explicit work bounds, ownship exclusion, confirmation, age limits, and a forward field of regard. An acquired target may stop, but cannot be tracked through the aircraft after leaving the forward sector.

The ordinary GMT movement gate uses the recovered Hornet simulation predicate: 8–55 knots of total object velocity. The selected track bypasses that movement gate so a truck stopping at an intersection does not immediately vanish. Two observations confirm a contact; unobserved contacts expire after six seconds. These are declared simulation choices, not recovered F-22 performance specifications.

## IDA chain and resources

Research used the user's local IDA databases read-only. Independent implementation calls shared DCS interfaces; it does not load or call FA18C.dll. No proprietary shader or decompiled function body was copied into the mod.

| Resource / address | What it establishes |
|---|---|
| FA18C primary radar vtable `0x1806359E8`, constructor `0x1804A4B80`, initialize `0x1804A99F0` | APG-73 radar ownership, pose setup and 1/60 activity schedule |
| FA18C `0x1804A92C0`, `0x1804A42D0`, `0x1804A3FC0` | Native ownship pose, camera orientation/depression and projection fields |
| FA18C MPD `0x1804ECB70`, camera `0x180477DA0` | Actual radar display branch and DynamicParam meanings; separates MAP from unrelated TGP branches |
| FA18C `0x1804A1FF0`, `0x1804A3B70` | AG search/track state and bounded spatial search; GMT/SEA masks differ |
| FA18C `0x1804A0210`, `0x1804A12B0`, `0x1804A14F0`, `0x18049F890` | Movement predicate, terrain/object obstruction, contact expiry |
| FA18C `0x1804A40E0`, MPD controllers `0x180521680`, `0x180521700`, `0x1805217F0` | Selected track, ground speed, heading and selected symbol |
| CockpitBase `0x1803451E0`, primary radar slot 15 | Correct native spatial-update phase; slot 6 is the Lua device update, not the detector phase |
| CockpitBase `0x180341326`, `0x180335610`, `0x180332DB8` | Independent verification of terrain LOS: `globalLand` virtual +120 receives two float world points and returns visibility |
| edObjects `0x18000B430`, `0x18000D160`, `0x180013F60`, `0x180002B70` | AABB query ABI, bounded callback convention and registered/moving-object conversion |
| edObjects `0x1800037C0` | Segment intersection ABI, output point/fraction/normal; non-null string return denotes intersection |
| SceneRenderer `0x180045F40`, `0x180045E80` → `0x180044450`, `0x180046220` | Radar input conversion, scene collection, orthographic reflectance and shadow passes |
| enlight `0x180006530`, `0x180003630`, `0x180005D40`, `0x1800059E0`, `0x1800057C0` | Sweep source caching, source processing/blur, scan compositing and final color/quantization |
| `D:/DCS/Bazar/shaders/enlight/radar.fx` | Actual installed PS_SOURCE, PS_SCAN and PS_FINAL contracts; raw reflectance and radiation-weight channels differ |
| `D:/DCS/Bazar/shaders/model/functions/radar.hlsl`, `enlight/radarFunc.hlsl` | Terrain/object reflectance and range/normal-dependent processing |
| `D:/DCS/Config/Effects/radar.lua` | Shared MAP/JF_17 RBM presets, viewport differences, 3.3° beam blur; EXP presets use a different DBS path |
| `D:/DCS/Mods/aircraft/FA-18C/Cockpit/Scripts/Multipurpose_Display_Group/Common/indicator/Pages/MPD/RDR/RDR_AG.lua` | Moving-track bricks and separate selected-track/speed/heading presentation |

The full chain is: native ownship/camera → common indicator radar parameters → SceneRenderer radar passes → orthographic terrain/object reflectance and shadows → enlight source processing → beam blur → scan composition → final GPU texture → our MFD material. GMT is a separate scene-detection/track/symbol path, not bright pixels interpreted as vehicles.

Runtime ABI guards pin this implementation to the inspected DCS binary profiles. Incompatible versions fail closed instead of applying unchecked offsets. Among the research fingerprints: CockpitBase SHA-256 `163d55167503da8dd0ea9eb459e17206fc3dc8d6b4805b5b13bbe58341beb794`; edObjects SHA-256 `dfcbde26de71f85d8b9b9b57554ad9f6781ed9bae9a2eb6b7a08e55c9199d468`.

## Native measurements

Evidence root: `D:/Codex-F22-Overhaul-2026-10-25/ag-rebuild-20261026/`.

| Trial | Result / evidence |
|---|---|
| Moving self-occlusion A/B/A | 30 m recovered → 12 m collapsed → 30 m recovered in one continuous flight. `moving-occlusion-aba.log`, `moving-occlusion-native-gmt/dcs.log` |
| Production clearance, diagnostic offsets zero | Another 4.8 km of actual flight retained roughly 2,978 occupied samples at the final snapshot. `frontend-moving.log` |
| Texture registration | Eight actual GPU captures over about 6.3 km. Seven predicted row shifts: 5.87–6.49; measured: 6,6,6,6,6,6,7. Occupancy 2,920–3,037 / 4,096. Correlation uses horizontal image gradients to reduce the sweep brightness footprint. `image-registration.json`, `image-registration-analysis.json` |
| Turning/range/freeze | Actual heading changed from east through about 127° while terrain remained populated; tested 5→40→5 NM and freeze/resume in moving flight. `turn-ranges.log`, `map-registration-turn-ranges/dcs.log` |
| Native GMT | Cross-range truck detected at about 17.3 kt; parked control excluded. Native contact position/velocity matched the separately logged mission observer. `frontend-fixtures.log`, `frontend-gmt-flight/dcs.log` |
| Actual MFD acquisition | OSB 3 acquired ID 16778752 in GMTT; displayed 17.34 kt and ~4° heading. Stopping the truck retained a live zero-speed track. Destroying it expired the track and designation. `acquire-cross.log`, `track-loss.log` |
| Final clean GMT default | At ~2,000 m altitude, native detection and actual MFD acquisition worked with terrain disabled. ID 16778496 remained acquired during subsequent normal flight and INTL on/off transitions; final speed 15.47 kt, track/designation valid, terrain disabled. Object-obstruction rejects were recorded separately. `gmt-clean-final.log`, `gmt-clean-acquire.log`, `final-clean-gmt/dcs.log` |
| MAP → JDAM | Real MFD terrain designation produced a schema-2 native AUTO solution; station 4 released native weapon ID 16778496. Requested point N=-365000, E=626661. Bracketed terminal estimate N=-364991.409, E=626663.454: ~8.93 m horizontal error, terminal radius bound ~1.41 m. This is one measured shot, not a guaranteed CEP. `map-jdam-native/dcs.log` |
| Stores HUD → keypad | Actual lower Stores HUD button and ICP option/digit/ENTER commands committed quantity 2 and time interval 350 ms with two loaded bombs, then restored 1 / 200 ms. A prior attempt with only one remaining bomb correctly limited quantity to one. `ccip-trial.log` |
| CCIP regression | Normal northbound flight at ~200 m/s, ~2,000 m altitude. Native prediction N=-359052.722, E=619999.952. Separately logged live samples at t=32.27/32.28 bracket terrain clearance +1.256/-0.620 m. Linear contact estimate differs by 4.33 m horizontally, conservative interval radius 3.09 m. `ccip-native-regression/dcs.log`, `ccip-live-bracket-analysis.json`. The older terminal-only analyzer remains INCONCLUSIVE because its final live sample was already slightly below terrain; no exact collision point is claimed. |

The numeric 64×64 capture is a diagnostic sampling grid, not the renderer's 512×512 texture resolution. Registration within a sampled row establishes scale and motion direction at that sampling resolution; it does not certify subpixel imagery accuracy. Native target coordinates and the weapon terminal observer are measured separately.

## Logging and tests

`F22_AG_SCAN` records source readiness/reason, actual rendered pose and motion age, scan direction/fraction, callbacks/rejections, GPU texture/channel signal, GMT query/candidate/rejection counts and selected-track state. `F22_AG_CONTACTS` records IDs, native world points, velocities, ages and displayed coordinates. Optional GPU readback captures numeric texture data and its sweep reference; it never changes the source texture. Mission/export observers used for validation are read-only inputs to the test analysis, never production sensor data.

Focused C++ tests pass for camera/projection and stale-pose guards, GMT speed/beam/confirmation/expiry/ID reuse, the common-radar callback wrapper, and native ground publication. Lua tests pass for GMT transport/acquisition/coast/loss, MAP reference/designation gates, freeze/sweep continuity, MFD construction, A/A↔A/G ownership, navigation designation, stores/keypad routing and delivery geometry. Older MAP tests were updated to explicitly select MAP and test source availability rather than require obsolete clutter records.

Final installed files are `bin/f22.dll`, `AG_Radar_Computer.lua`, `AG_Radar_System.lua`, `Radar_System.lua`, `PMFD_System.lua`, `PMFD_CENTER/ag_radar_format.lua`, and `AG_Radar_Video/init.lua`. Their hashes match the tested source/build in `installed-final-manifest.json`. Deployment used this explicit list and preserved unrelated work. The final owned DCS test process was closed after archiving its log.

## Limits retained explicitly

- These tests used desktop DCS with VR disabled. VR-specific frame timing has not been rerun; the 30 m graphics clearance must not be presented as an all-hardware guarantee.
- Real-beam MAP retains the common engine's beam blur. It is not SAR or photographic imagery. EXP/DBS, SEA, terrain following and real APG-77 detection performance are not implemented or claimed by this rebuild.
- INTL runs the terrain and vehicle paths together as an allowed modernized mod behavior; it is not an exact recreation of the Hornet's alternating sweep scheduler.
- The bounded GMT detector uses native object kinematics, visibility and scan history, not a simulated RF receiver/Doppler signal chain. Specific classification, clutter rejection and detection probability remain approximations.
- A JDAM receives a coordinate snapshot. Tracking a moving vehicle does not make the released JDAM a moving-target homing weapon. Use the track to locate/designate a suitable stationary aimpoint or stopped vehicle.
- The JDAM release envelope remains the previously documented conservative estimate around the native ballistic solution. Fuze programming is still limited by actual store/native support; unsupported controls must not be represented as functional.
- Low altitude, steep attitude, extreme speed, dense mission performance and multiple terrain maps still need broader flight coverage. The precise bad behavior reproduced here now has logged regression evidence rather than a screenshot-only acceptance claim.
