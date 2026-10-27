# DCS-F22 — standalone development build

A standalone cockpit and avionics implementation for the Grinnelli Designs F-22A, retaining its custom external flight model. This fork uses shared DCS radar, payload, weapon and RWR services; the F-15C, Flaming Cliffs and Hornet modules are not prerequisites. It installs under Saved Games without editing another aircraft's files.

The native adapters were qualified locally on **DCS 2.9.30.28738, Windows x64**. Their private interfaces are version checked; compatibility with another DCS build requires validation. This is an actively developed community mod, not a claim to reproduce classified F-22 avionics.

## Current systems

- Own HUD and head-down displays, computed gun pipper, native ballistic funnel and maneuver cues.
- RWS, ACM acquisition, native STT and an own TWS track/scan controller with real native missile support.
- Native stores, bay-gated release, dynamic launch envelopes and estimated missile flyout/activation timing. Actual seeker state remains separate from predictions.
- Independent passive RWR, radar/RWR identity association and prioritized warning audio.
- Independent optical missile warnings with HUD clock sectors, EW bearings and distinct audio; actual R-73 attacks qualified without paid aircraft modules.
- Native chaff/flare dispensing and ECM controls; status and quantities follow the common simulator service.
- Mission-route navigation, coordinate entry/markpoints, direct-to and optional automatic sequencing; compass steering and explicit WPDSG target presentation.
- Native TACAN/ILS receivers, true/magnetic references, course/CDI guidance and CNI keypad tuning.
- Independent ATT/HDG/ALT/RALT/NAV/V-S relief modes plus CAS/Mach autothrottle, takeover and validity gates. See [navigation and AFCS guide](docs/NAVIGATION_AND_AUTOPILOT.md).
- A/G terrain MAP radar with cursor designation; ground gun CCIP, conventional-bomb CCIP/AUTO and stock GBU-32 coordinate handoff through the common payload service.

Local flight qualification includes operation with the F-15C and Hornet directories removed from DCS's module search path, plus loaded-module checks proving their aircraft avionics DLLs absent. See [standalone status and limits](docs/STANDALONE_DESIGN.md) for the tested scope. Multiplayer, complete rearm/respawn coverage, advanced datalink and new AESA detection physics remain outside that acceptance. Navigation radio and AFCS acceptance is recorded separately in the [navigation/AFCS guide](docs/NAVIGATION_AND_AUTOPILOT.md) and [evidence notes](docs/resources/research/NAVIGATION_AUTOPILOT_EVIDENCE.md); ILS remains advisory and A/A TACAN is unqualified.

## Radar and HOTAS controls

The DCS Controls menu separates **F-22 HOTAS - Stick** (trigger, weapon release, trim, target/display management and countermeasures) from **F-22 HOTAS - Throttle** (weapon selection, radar cursor, elevation, range and seeker cage/uncage). Labels describe each function and its short/hold behavior. Existing command IDs and saved button/axis assignments are retained.

**Sensor Control Switch directions select focus only:** Up selects HUD, Down the primary display, Left the left MFD and Right the right MFD. Repeating a direction preserves its page. Green corner marks identify the focused display; the HUD shows a small HUD focus label. A bezel-button interaction also focuses that display, including lower center. Change formats with the existing MFD bezel controls.

Bind **Sensor Control Switch Depress - Execute Focused Screen Function** in the Stick group. It is separate from **TDC Depress** and executes once per press:

| Focused format | SCS depress |
| --- | --- |
| A/A radar | Request STT on the selected/cursor track; preserve an existing STT lock |
| A/G MAP radar | Designate the return beneath the cursor |
| HUD in A/G | Designate the HUD line of sight on terrain |
| HUD in A/A, radar unlocked | Select boresight acquisition |
| Right MFD EW | Toggle priority threat view |
| MFD navigation | Zoom in |
| Passive system/menu pages | No sensor command; use their bezel controls |

TDC retains its existing designation behavior, including selecting TWS tracks and designating through the HUD in A/G. SCS depress does not open a page-selection menu, change master arm or release weapons. Existing physical direction/TDC assignments are retained; assign the new depress binding to your preferred switch button.

On the radar page, the five **left bezel buttons**, from top to bottom, select **AZ** scan width (30/60/120 degrees total), **HT** scan height (10/20/40 degrees), **EL UP**, **EL DN** and **CNTR** to recenter the elevation and cursor. Bottom **RNG IN/OUT** buttons change range. The blue scan readout shows the effective coverage and whether it is manual RWS coverage or automatic TWS coverage; TWS may recenter/resize around designated targets and missile-support obligations. Scan edits preserve an existing STT lock and apply to the subsequent search. These are simulation settings, not verified APG-77 controls.

The combined HOTAS radar-coverage binding changes width on a short press and height on a half-second hold. Radar antenna elevation up/down are separately bindable in the throttle group. Hardware button numbers depend on the user's profile.

With a missile and radar target selected, the HUD shows a launch-range ruler: the long tick marks maximum range, the short tick minimum range, and the hooked tick the dynamic turning-target limit when available. The chevron shows current target range; the number above the ruler is its adaptive full-scale slant range in nautical miles.

The radar uses Hornet-style launch-acceptability bars alongside the selected target's bearing: minimum range, the dynamic turning-target limit when available, and maximum range, connected by a steering line. On our polar map these follow the target bearing and the radar's actual horizontal range scale; native slant-range limits are projected at the target's height. The selected-target symbol shows current range. An arrow at the outer end means maximum range extends beyond the selected radar scale; it is not drawn as a false maximum-range cap at the display edge.

## Ground attack

Select **Air-to-Ground** using the throttle master-mode control. The radar MFD becomes a ground MAP page; turn **EMIT** on for radar returns. Its top buttons select **GUN**, **CCIP** or **AUTO**. Arm the aircraft in flight before firing/releasing. The existing weapon-select Gun control selects the ground gun while in A/G. Trigger second stage fires it; the terrain pipper uses the actual native shell trajectory, muzzle and wind, with remaining ammunition displayed.

For **CCIP**, use the optional **Mk-83 CCIP/AUTO training** store. It references the existing simulator bomb and is explicitly a non-standard F-22 loadout. Aim with the computed impact pipper and press weapon release; the sight accounts for remaining main-bay opening time using a constant-velocity prediction. A pipper outside the glass is labelled accordingly. JDAM release is inhibited in CCIP.

For **AUTO**, designate a ground coordinate using the radar cursor/TDC, a HUD boresight terrain mark, or **Designate Selected Steerpoint**. DMS Up selects the HUD and TMS Up/TDC then designates its boresight; with radar selected, designation uses an actual MAP return. TMS Down clears the ground designation. Fly the steering line and hold weapon release before the release cue reaches the reference. Consent opens the bay and the computer releases one bomb within the computed timing/cross-track window. Releasing the button cancels consent. The GBU-32 preset uses the stock guided bomb and receives the designated world coordinate at native release. Its AUTO window is deliberately conservative, based on native ballistic reach rather than a claimed operational JDAM launch envelope.

MAP pixels represent native terrain/surface returns with a bounded image age; they do not identify individual vehicles. SAR imagery, moving-ground-target tracking, laser designation, programmable fuzes/ripple attacks and GBU-39 integration remain future work. Aircraft-specific RF performance and production F-22 attack-computer behavior are not reproduced.

Two airborne practice missions are included in `Missions/Ground Attack`: **F-22A - Ground Attack - JDAM AUTO** and **F-22A - Ground Attack - CCIP Training**. Each starts 5.4 NM south of a stationary truck group, with target steerpoint 2, two bombs, two AIM-9X, two AIM-120C and full guns. Their briefings give the delivery steps. These missions contain no development hooks or automatic pause/control scripts.

Local native flight tests verified a real gun burst and trigger stop, a conventional bomb release, a guided AUTO release and ground-target damage, and actual radar-cursor designation/clear through the common HUD target owner. CCIP impacts differed from the native prediction by approximately 22–41 m in active-pause release tests. Active pause freezes the platform while the sight's bay-delay prediction assumes forward travel, so these tests do not qualify normal-flight CCIP accuracy during bay opening. That validation remains pending. The clean land JDAM repeat ended about 13 m horizontally from its designation. These are measured cases, not an accuracy guarantee across delivery conditions.

## Build and install

1. Clone with Git LFS installed, then run `git lfs pull` to retrieve the models, textures and audio. A source ZIP containing LFS pointers is insufficient.
2. Build `bin/f22.dll` with Visual Studio 2022 C++ tools and CMake 3.30+. See [development setup](docs/DEVELOPMENT.md).
3. Place the aircraft root (including `entry.lua`, `bin/f22.dll`, `Cockpit`, `FM`, `Input` and the asset directories) in `Saved Games/DCS/Mods/aircraft/F-22A`. Restart DCS after installation. Remove older copies of this same mod from other aircraft-mod directories to avoid duplicate registration.

The repository contains our source and public aircraft assets. Proprietary DCS DLLs, IDA databases and test-control hooks are not distributed as aircraft prerequisites. CI builds the DLL and runs the C++ and Python/Lua regressions; the DLL artifact still needs the aircraft assets from a complete checkout.

## Development references

- [Standalone status and architecture](docs/STANDALONE_DESIGN.md)
- [Development setup and tests](docs/DEVELOPMENT.md)
- [HUD/system test plan](docs/HUD_AND_SYSTEMS_TEST_PLAN.md)
- [Research archive](docs/resources/research/README.md) and [public study catalogue](docs/RESOURCES.md)

Older audit and roadmap documents describe earlier development states. The current standalone status takes precedence over their historical dependency descriptions.

## Credits and original project

Based on [Grinnelli Designs' F-22A](https://github.com/grinnellidesigns/f-22a), upstream commit `8484b44cf8bc46540376435f0ba584f9f3e8bf44`. Original source history, model/assets attribution, copyright notices and GPL licence are retained. Original 3D authoring projects are not supplied by this fork. See [LICENSE](LICENSE), [contributors](Contributors.md) and [contributing](CONTRIBUTING.md).

The upstream release used F-15C avionics. Its aircraft-module preload workaround is superseded here by the own cockpit and common-device integration. The original aircraft overview follows.

## About the Raptor
The Lockheed Martin F-22 Raptor is an American single-seat, twin-engine, all-weather stealth tactical fighter aircraft developed for the United States Air Force. As the result of the USAF’s Advanced Tactical Fighter program, the aircraft was designed as an air superiority fighter, but also has ground attack, electronic warfare, and signals intelligence capabilities.

The prime contractor, Lockheed Martin, built most of the F-22’s airframe and weapons systems and conducted final assembly, while Boeing provided the wings, aft fuselage, avionics integration, and training systems. The aircraft first flew in 1997 and was variously designated F-22 and F/A-22 before it formally entered service in December 2005 as the F-22A.

## Features
* **NEW!** Full EFM, complete with thrust vectoring!
* Highly detailed, 6-dof cockpit
* Interactive (clickable) cockpit
* Detailed PBR textures
* Multiple MFD pages to explore
* Unique configuration MFD page
* Additional liveries
* Aerobatic smoke system
* Photoshop paint kit

## Independent AP, altimetry and pilot warnings

AP now opens flight-control modes and targets; ALT opens barometric settings and independent MSL/AGL warning floors. The ICP rocker changes pages. Select a field, type digits, select it again to accept. ALT2 provides voice test/cancel, mute and caution acknowledge. Barometric altitude is calculated from actual EFM static pressure, with a common datum for HUD/ADI/AP/floor warnings; enter local QNH or select STD. Original HUD fonts are retained.

Own terrain, altitude-floor and modeled control-damage warning logic uses newly synthesized speech; no Hornet/F-15 warning recordings are required or bundled. The mod's terrain-warning and IRS estimates are deliberate approximations. See [NAV/ALT/AP/warning implementation and qualification](docs/resources/research/OVERHAUL_NAV_HANDOFF.md) for controls, signal-validity contracts, audio provenance and tested limits.
