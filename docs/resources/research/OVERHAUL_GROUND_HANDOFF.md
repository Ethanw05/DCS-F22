# Ground radar / core video handoff - in progress

## Qualification status

The rejected80x80 flat tile prototype was never integrated or installed. The replacement supplies a dedicated owned common ccIndicator to DCS's real GPU radar renderer. Source is integrated and compiled, and native camera/parameter callbacks have run without faults in owned held missions. **Owned run05 stayed black after the gray transfer artifact was corrected. The user subsequently reported intermittent real terrain during maneuvers; a stable, usable terrain map remains unqualified.** READY1 and callback counters are interface evidence only. Keep F22_AG_VIDEO_GEOMETRY_QUALIFIED=0; no image-derived coordinate designation is authorized by this checkpoint.

Three owned test processes were individually verified and closed after archiving their probes. Native READY1/reason0 and703 callbacks were observed by model11s; later counters exceeded24000 with no fault. Increasing gain to1 did not produce a usable image. Archives are D:/Codex-F22-Overhaul-2026-10-25/ground-build/run01..run03. The independent user flight is preserved separately under user-flight-2026-10-25-2130. Its as-flown code used the earlier material candidate and recorded six missing-mfd8 errors. It contains no native video readiness/frame diagnostics and cannot qualify the image.

**Run05 tested the neutral-transfer correction:** the gray artifact is gone, but the image is black at20NM/gain50 and40NM/gain100. The corrected display transfer is installed; terrain and geometry remain unqualified. The newer honest MAP UNAVAIL footer is source-only.

## Verified common renderer interface

Installed DCS2.9.30.28738 x64, read-only MCP/IDA evidence:

- IcClickable virtual+184/+192/+200/+208/+216 forwards camera, world point, condition, count and parameters to registered render targets.
- ccIndicator primary virtual+168 camera,+176 point,+184 condition,+192 parameters,+200 always-render. Original table has41 entries and an MSVC RTTI prefix.
- TVScreenCondition3 maps to Visualizer mode11 (0x180090DA0); Visualizer0x18008FCE0 builds DCSMFDDesc radar block+280 from Graphics::Camera and18 existing DynamicParam unions.
- SceneRenderer0x180034260 dispatches mode11 to RadarModule::addPasses0x180045F40 and enlight::AGRadar. The core path includes actual terrain/model reflectivity, orthographic depth, radar shadows, scan storage and DBS shaders. Core renderer/shaders are not copied or patched.
- F/A-18 ccMPD_F18 get_screen_params0x1804ECB70 independently confirms direction0,fraction1,blur2,gain4,erase6,preset7,quantization8,intensity min/max9/10.
- Global engine preset JF_17 is full-viewport green RBM in DCS/Config/Effects/radar.lua. This is a common engine preset name, with no JF-17 aircraft dependency.
- ccIndicator::set_render_materials0x180390960 creates material render_target_(index+1), assigning source texture mfd(index) by runtime name. MCP disassembly shows the explicit increment at0x1803909E6. Common kneeboard Lua uses GetRenderTarget()+1 too. Thus target8 consumes **render_target_9**, not8. MakeMaterial loads a disk texture and is unsuitable for this binding, even with class MFD.
- wTVPictureSourceProvider::get_target_name0x180180CD0 supports mfd0..31, so target8 is within the verified common interface.
- Core MFD pixel shader multiplies video by a second mask texture. Current source uses the installed neutral16x16 RGBA white asset Bazar/TempTextures/white.png; no paid aircraft mask is copied.

## Owned source and registration

No new deviceID. Controller is existing RADAR_COMPUTER14; dedicated indicator target8 is registered immediately before PMFD_CENTER consumer, preserving HUD-first registration. Lua page uses the native render_target_9 material and one video quad. Source init has no ordinary cockpit artwork.

Owned files: EFM/source/NativeGroundVideo.cpp/.h,GroundVideoView.h; narrow calls in NativeGroundRadar.cpp; EFM/tests/test_native_ground_video.cpp and CMake test registration; Systems/AG_Radar_Video/init.lua/empty.lua; Systems/AG_Radar_System.lua; PMFD_CENTER/ag_radar_format.lua; dedicated device_init indicator; narrow Radar_System early VIDEO-handle declaration block; tests/test_ground_video.py and common-library whitelist in test_standalone.py. Parent owns MFD/PMFD routing and all other display integration.

The native adapter clones only the exact dedicated ccIndicator table, retaining RTTI and original lifecycle. Build fingerprints gate CockpitBase,Visualizer,SceneRenderer,enlight,GraphicsVista. A foreign table is rejected before typed getters; target/context/controller are revalidated on every install attempt, including the already-owned fast path. A shared Guard latches malformed parameter-buffer fault7 until explicit reset; condition,camera,point,parameters and published readiness all fail closed. Stale,disabled,wrong-owner or nonfinite camera/point input produces neutral finite output. Reset/new install advances an epoch so reused render-thread state is not accepted. Render callbacks use locked snapshots and never call Lua/EDPARAM. No global renderer/module hook exists.

## Controls, mapping and publication

Lua publishes source marker, enable, independent model TIME, NORTH/ALTITUDE/EAST, true HEADING radians, fixed120deg FOV, scan direction/fraction, gain and erase sequence. Native reads existing range5..40NM. Width120/60/30 is physical scan width inside the fixed120deg image; it does not magnify. View data must be finite/current within0.5s; power, A/G HUD_MODE7 and radar power gate it.

Native READY means owned adapter installed; REASON0ready,1modules pending,2unsupported build,3symbols missing,4ownership mismatch,5source pending,7bad buffer. FRAMES counts callbacks, never nonzero GPU pixels. Lua designation additionally requires geometry-qualified1, fresh native returns/current pose and nonfrozen image. Rejected commands preserve accepted coordinates.

Existing elevation_up/down10614/15 adjust gain5%; vertical_span10623 toggles FRZ. Range10607/8,AZ10616,recenter10617,designate10606 and clear10609/30 remain. No new command IDs. FRZ pins the source pose/sweep and inhibits designation; actual GPU freeze behavior is still unqualified. Parent must keep bezel labels/routing aligned.

Model.project remains x=right/range*1.65 and y=-.76+forward/range*1.52, with video quad x+-0.825,y+-0.76. Native orthographic geometry is one selected range wide/deep. Actual cardinal orientation/range/cursor matching must be proved in DCS before enabling geometry-qualified1. The single image overlays clipped range arcs/azimuth lines and a separated cursor; old256 clutter strokes are removed. A ground designation uses an open cross. Native terrain noise remains an internal bounded-footprint selection source, not displayed dots or identified vehicles.

## Checks and next runtime

Fresh VS2026 x64 Debug build at D:/Codex-F22-Overhaul-2026-10-25/ground-build passes all15 native CTests. Actual-Lua ground video regression passes5103 scan cases, bounded gain, pinned frozen pose, power/time reset, unqualified/frozen designation rejection, one243-element video page, early VIDEO handles, one-based material and registration order. Latest frozen shared source passes91/91 Python/Lua checks. All15 native CTests pass after correcting near/far ordering. The launcher refused before any copy because a new user/unowned DCS35024 --restarted opened during the suite. No current source/EDM/palette/projection/mask correction was installed into that flight.

Next owned run: current mask/early-binding correction; actual nonzero coast/terrain image; cardinal/range/cursor alignment; gain/width/freeze/power lifecycle and frame cost. If still black, preserve the exact failure evidence and keep designation disabled. Installer includes current Lua/DLL, warning6-file closure and parent's explicit corrected Shapes/F-22A.EDM. No broad Shapes copy. User flight archive is immutable.

Exact-name harness mission F22-Dogfight-Validation.miz is required. Our launcher refuses to install while any DCS process exists and records the owned PID. Do not stop a different/user process. Native controls/eval backups are in os/work/ground-radar/runtime-control-before.json. Original IDAs13337/38/39 remain untouched; owned scratch renderer DBs13340..43 are under os/work/ground-radar/ida-render. No current ground-owned DCS is running at this handoff update.

## Honest GMT/EXP boundary

Common avSimpleRadar::scan_for_targets0x180343EA0 uses bounded viObjectManager(mask32); unit_handler0x1803446B0 rejects ordinary ground wsType level1=2 before detection. get_detection_status0x180340E10 applies beam,RCS/range,velocity and terrain LOS only to accepted objects. NOISE has no vehicle identity. AGRadar can rasterize model reflectivity but provides no identified vehicle/velocity observation API here.

Genuine GMT needs a separately verified bounded ground-scene query plus physical RCS/LOS/beam/Doppler/observation-lifetime gates. No mission-unit truth, coalition/type hostility or random dots are used as detections. GMT/GMTT and EXP/DBS are not implemented/qualified by this checkpoint. Real magnification must not be called SAR.

Primary behavior reference: Eagle Dynamics official Hornet guide A/G radar chapter186..198 and provided reference RDR_AG.lua, which uses a separate1024x1024 video layer and stabilized quantized terrain imagery. Public primary manual: https://www.digitalcombatsimulator.com/upload/iblock/8d7/2s3e89jqknz7xmti8hrhe1bjt2uw1s3e/DCS%20FA-18C%20Early%20Access%20Guide%20EN.pdf

Source native DLL SHA256: 91FE9F95A916C161FDE3436804AE7BA6F77DE5AED313440CFDAD1EA3C1009E74 (unqualified GPU build).


## Projection ABI correction and external runtime hold

GraphicsVista Camera::getProjectionDesc at0x18001E91C copies camera+700 into ProjectionDesc.near(+28), and camera+704 into far(+32); constructor confirms near1/far1000 defaults. The prior adapter reversed them, producing near=range and far0. A shared typed Projection now writes FOVx,FOVy,aspect,near0,far=range*1852 in this exact20-byte sequence. Range5/10/20/40 and rejected-input neutral projection regressions pass. This is a concrete fixed native projection defect, but actual GPU output after correction is untested.

The frozen launcher also explicitly includes parent's corrected Shapes/F-22A.EDM and terrain warning6-file closure. It refuses any install while DCS exists. New PID35024 uses tempMission.miz A/A and is not any current owned ground test; no stop/eval/install/flight-control action was made. Parent is preserving its flight data read-only. Resume only after the current flight/process is gone or ownership is explicitly resolved. The complete source-rendered EW preview is a synthetic fixture, not native flight evidence.


## Run04 native evidence and source-only MFD transfer candidate

Owned37112 was verified against the exact ground mission, archived to D:/Codex-F22-Overhaul-2026-10-25/ground-build/run04 and closed. The runtime slot was released to the coordinator for warnings, Stores and COM; Ground must obtain the next explicit slot before any install/control. Final snapshot: VIDEO_READY1/reason0,96540 callbacks,20NM,120deg,gain.5,unfrozen,designation0. Startup no DM/rack/COCKPITBASE faults were found. Actual 2D native EW FCS-derived F-22 ownship and Stores HOME/MODE/PROG/ENTRY/DOORS were captured. The coordinator found the ENTRY empty underscores absent from FONT_PFD and staged supported hyphens separately; that marker is still pending native recheck. These captures do not qualify VR, weapon delivery or GPU terrain.

Held-footprint terrain sampling proved land inside20NM at heading125.58deg: center10NM10.044m,15NM73.390m,20NM267.406m; left/right20NM733.064/785.955m. Independent pixels found97.235% of a video interior exactlyRGB160, with the remainder mainly independent overlays. Thus the frame is not explained by an all-sea footprint. User suggested pilot near-passout, then asked to continue the existing route; LOAD_G1 and saturated neighboring displays do not by themselves exclude lingering pilot effects.

New read-only GraphicsVista scratchMCP13345/PID30980 resides in ground-build/ida-graphics, separate from original IDAs. Exact-module metadata and decompilations are os/work/ground-radar/graphics-*.json. CockpitBase ceSimple::set_mat_params0x1803AB220 zeros17 dynamic unions and a foreign MFD material gets no normalized transfer inputs unless explicitly configured. GraphicsVista MFDMaterial draw0x180019990 consumes dynamic0 colored,6 inversion,7 brightness,8 contrast; it normalizes0/0 to b=-.8,c~.158, not zero GPU contrast. Its pc0 comes from its own colored/luma tables, not those union zeros. Consequently the defect does not establish why raw imagery has no variance.

A SOURCE-ONLY two-file candidate explicitly supplies colored and neutral normalized.5/.5 to the one named F22_AG_RADAR_VIDEO quad using the existing common change_color_when_parameter_equal_to_number controller0x180387120. Its forced-color setters0x180372430/0x1803723A0 populate exactly the ceSimple foreign-MFD path's0/7/8/9 inputs, with no shared parser/material mutation. Existing actual-Lua regression verifies the payload and still constructs243 elements. No DLL change. This must be tested in the next owned run; preserve geometry0 and obtain raw mfd8/final-consumer contrast evidence if flatness persists. The generic set_contrast_raw controller only configures dynamic11 and is not a substitute for these MFD fields.


## Run05 neutral-transfer A/B and external process change

The coordinator released the slot after Stores. start_transfer_runtime.py passed freshzeroDCS, exacttwofile source hashes and immutable run04DLL checks, backed up allinstalledfilehashes, and copied ONLY ag_radar_format.lua. OwnedPID24352 loaded the sameSE mission; run05/installed-delta.json and installed-before-manifest.json preserve the exact closure. No voice/COM/EDM/nativeDLL source was copied.

Actual captures at234651/234710 show the former uniform gray field removed, but the video remains black with only independent green scale/cursor overlays. Atmodel11: READY1/reason0/713callbacks,20NM,120deg,gain.5. A bounded additional4seconds at40NM/gain1 still produced black. Final96540 counts fromrun04 must not be substituted forrun05: run05's later snapshot is11628callbacks/model15.3. GEOMETRY_QUALIFIED0 and DESIGNATION_VALID0 were explicitly logged and observed before the process ended. Rawmfd8/renderer output is still unobserved, so this is a narrow final-transfer correction, not terrain success. The exact same sourcepose asrun04 is N-344619.875/U998.260/E601539/heading2.191869084, whose20NM land footprint was already measured. A planned repeatfootprint query was not executed after ownership changed.

Owned24352 ended outside Ground's control. The new fresh PID/mission guard refused the next evaluation BEFORE writing the shared control or eval file. Freshreads found foreign9980 with no missionargument, then1964 --restarted; no stop/control/install/launch action was made against either. The coordinator holds all runtime until this session is resolved. The full24352DCSlog had already been rotated away by those restarts; parent confirms it has no fullcopy. Do not invent or label the new tiny logs asrun05. run05 preserves the three exactnativecaptures, owner-copiedparameter snapshots, installedbefore/afterpage and allhashes. capture-pixels.json reports91.76% exactblack and smallnearblack/independentgreenoverlay remainder in a40000pixel interior sample. This does not qualify imagegeometry or rawGPUvariance.

A subsequent SOURCE-ONLY footer correction replaces NO RETURN (which incorrectly meant no selectable footprint, and was forced by geometry0) with MAP UNAVAIL while geometry is unqualified. A qualified image without a selectable footprint no longer makes an empty-scan claim. Targeted actualLua groundvideo checks pass243elements and earlyhandlebindings. This footer is not yet installed; run05 retains its exact earlierA/Bbytes.

Read-only Hornet comparison byNAV confirms condition3, direction/fraction/blur/gain/defaultquant0, one-shotpreset delivery and one-basedmaterialname are analogous. Hornetcamera uses near10/farR, FOVy90/aspecttan(FOVx/2); currentadapter near0/FOVysameasFOVx remains a contractdifference, not a proved blackcause. GraphicsVista getClipVolume alone does not establish near0 failure. Installed radar.fx PS_FINAL295..306 producesalpha fromstorageval.z; PS_SCAN writesz1onscannedpixels. Hornethelper usesadditive_alpha=true versuscurrentfalse; actualblendstate/alpha effects need proof. NAV is tracing whether the commonempty source's MFDOverlayPass clears the radar result, plus rawtarget/allocation/latebinding. Same-name DX11 texturewrapper reconstruction is explicitly supported, so missingmfd8startupalone is not permanentbindingfailure proof.


## Current source-only checkpoint: stabilized antenna, accumulation and readiness

The later human flight reports establish a stronger condition-dependent observation than the stationary fixture: terrain patches sometimes appear during maneuvering/nose-up, while straight level can remain empty. Preserve that evidence; do not call this a permanent texture-binding failure. Original IDAs and the unowned user DCS session remain untouched. All changes below are SOURCE ONLY: the production DLL still has the run04/run05 hash and has not been rebuilt, linked or installed with these changes. The coordinator must combine this owned closure with the frozen NAV/async-A/G bridge before any native launch.

The frozen 10-file owned source closure and exact hashes are os/work/ground-radar/ground-next-checkpoint-manifest.json, with copies under next-checkpoint/. It includes the existing CMake file with one additional publication-test target; merge that addition carefully with other lanes' changes.

1. AG_Radar_System now separates the heading-map video sector from body-relative acquisition LOS. Video azimuth comes from map cursor azimuth; the physical sensor retains the body transform. Range/operating changes erase; TDC sector steering and AZ width do not erase unchanged pixel geometry. Actual Lua tests include300 pitch/roll updates across120/60/30deg, body compensation, stable map center, steering/AZ retention and exactly one range erase. Installed pre-fix negative controls fail both AZ retention and narrowed-sector attitude retention. This is a concrete narrow-sector fix, not a complete explanation of default120deg level-flight blankness.

2. GroundVideoView now supplies the recovered Hornet MAP-style earth-stabilized13deg depressed basis F=(cosH*cos13,-sin13,sinH*cos13), U=(cosH*sin13,cos13,sinH*sin13), R=(-sinH,0,cosH). Aircraft pitch/roll are not added again. The13deg setting is a reference-derived mod convention, not a recovered APG-77 specification. The renderer near plane is10m, matching the actual Hornet camera; this is not a minimum detection range. The consistent120x120 FOV/aspect1 is retained initially; Visualizer's mode11 radar descriptor consumes horizontal FOV. The earlier isolated near-only proposal is superseded by this source checkpoint, not installed.

3. Primary AGRadar::update rotates F upward by half the preset vertical angle and negates its Y for the radiation cutoff at+260; renderScanned sends this as params2.x. Default verticalAngle90 gives cutoff=-sin(beamElevation+45deg). Tests evaluate the full installed PS_SOURCE weight: at20km altitude/10NM the old level beam is below.001 while the depressed beam exceeds.2. Cardinal tests also check right-handed orthonormal basis, forward ground intersection/bearing/range and finite nonsingular near/far projection. This explains a plausible high-altitude loss mechanism without claiming the entire live failure is solved.

4. NativeGroundRadar no longer publishes a manufactured READY0/reason5/count0 pulse on every healthy.1s update. Local validation precedes publication, prior healthy readiness remains during the sample, and completed rows/time/count precede READY1. Genuine context/ownership/write/clock failures inhibit; an unusable noise-return buffer clears its count without falsely invalidating the owned adapter. tests/test_native_ground_publication.cpp executes the actual adapter against fake parameter callbacks and owned VirtualAlloc native memory. It traces20 healthy updates and real failure/recovery paths. A separately compiled pre-fix adapter fails at the actual healthy READY0 write; the patched adapter passes. This is interface readiness continuity, not atomic multi-field sensor snapshots or GPU image proof.

5. NativeGroundVideo has opt-in timing observations only, reset OFF by source init: CLOCK_CHECKS, FUTURE_REJECTS, STALE_REJECTS, CLOCK_DELTA_MS and MAX_LEAD_MS under the F22_AG_VIDEO_ prefix, enabled by F22_AG_VIDEO_TIMING_DIAGNOSTIC. Render callbacks use atomics; only the simulation update accesses/publishes parameters. Existing strict timestamp acceptance is unchanged. Both Lua's native model clock and this adapter resolve the same wTime export; no rounding bug or future-skew tolerance is asserted without measured callback timing.

6. The source-only MAP UNAVAIL footer honestly reflects unqualified geometry; it replaces the old NO RETURN claim based merely on absent selectable footprints. Geometry remains0 and image-based designation remains inhibited.

Validation so far: isolated VS2026 x64 Debug build compiles the actual NativeGroundVideo source as an object library without linking a production DLL, and both stabilized-lookdown/radiation and actual-adapter publication tests pass. The pre-fix publication negative control fails as expected. Full current Python/Lua checks are recorded separately. No integrated native build, new camera in DCS, accumulation flight, timing measurement, cardinal/range/cursor image acceptance or VR acceptance is claimed.

NAV's additional primary traces rule out a hidden first-eight-target limit (Visualizer explicitly builds all32), generic mode11 overlay color clear (negative sentinel skips it), a necessarily stale missing-texture wrapper (same-name late reconstruction exists), and raw scan alpha0 alone hiding RGB (MFD pc1 has alpha1). The gated 3-color binding instrument under os/work/ground-radar/binding-probe is isolated, defaults OFF, passes native-style Lua construction checks and has never been installed; use only if later evidence still needs that discriminator, never as terrain imagery.
