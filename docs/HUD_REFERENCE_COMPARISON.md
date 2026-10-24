# HUD picture comparison

Reviewed 2026-10-24 for the original Lua HUD. No third-party cockpit code, textures, fonts or models imported. Source links permit inspection without redistributing restricted pictures/manuals.

## Evidence and provenance

| Reference | What was actually inspected | Weight and limitation |
| --- | --- | --- |
| [Aiba, JASDF Aeromedical Laboratory, 2008](https://www.jstage.jst.go.jp/article/jasdfaml/48/1/48_21/_pdf/-char/ja), printed pp.22–23, Fig.1/3 (R03) | Full paper and rendered Fig.3 labeled F-22 HUD | A research publication explicitly identifying counter-pointer F-22 speed/altitude presentation. Fig.3 is an illustration reproduced from a 2002 source, **not an authenticated operational HUD recording**. Fig.1 defines 10 kt/dot, 100 kt/revolution and 100 ft/dot, 1,000 ft/revolution. It does not establish every F-22 mode or optical dimension. |
| [Telstar Logistics, C-130J copilot HUD photograph](https://commons.wikimedia.org/wiki/File:C-130J_Co_Pilot%27s_Head-up_display.jpg) | Original 1,600 × 1,200 photograph, not its generated search caption | Aircraft identified by photographer; former Castle AFB. Strong visual evidence for this displayed layout. It does not establish what flight/mode the symbology represents or the complete C-130J specification. Commons date and camera EXIF disagree; do not date it more precisely from those alone. CC BY 2.0, author Telstar Logistics. |
| [Top Mach Studios F-22A Premium manual, 2022](https://downloads.justflight.com/support/manuals/TMS_F-22A_PremiumEdition_UserManual.pdf), printed pp.17–18 | Rendered annotated HUD image and explanation | Clear game implementation reference: circular gauges, heading, flight path, bank, ladder and ancillary flight readouts. Authors explicitly identify their simulation/manual as fictional approximations. Similarity to R03 is corroboration of a design choice, not an independent measurement of the aircraft. |
| [Julhelm, SF2 F-22 Cockpit 1.0](https://combatace.com/files/file/12851-f-22-cockpit/) (R177); [Crusader avionics update](https://combatace.com/files/file/15086-sf2_f-22a_new_avionics_10/); [Operation Darius HUD gallery](https://combatace.com/gallery/image/42291-f-22-cockpit-close-up-of-hud/) | Listings, credits and descriptions. Old linked screenshots returned site placeholder graphics; gallery did not expose a retrievable image | **Visual comparison still blocked by unavailable images.** The 2014 update claims a closer HUD but describes unfinished work; the 2019 gallery is a different add-on. No archive downloaded. R177 requires consent for modification/reposting. Reference-only use remains the plan; no copying or inference from a placeholder. |
| [NovaLogic F-22 Lightning 3 screenshot collection](https://www.mobygames.com/game/3743/f-22-lightning-3/screenshots/) | Public gameplay image shown in image search, including a HUD without the twin counter-pointer layout | Evidence of an older game's design divergence, not of F-22 aircraft behavior. Screen-edge game UI and combat messages must not be treated as projected cockpit symbology. |
| [BAE Systems, F-22 HUD digital light engine, 2017](https://www.baesystems.com/en/article/digital-light-engine-technology-to-illuminate-f-22-head-up-display) | Manufacturer announcement | Establishes a planned form/fit/function image-source upgrade, not a complete symbology specification. A newer projector cannot be used to date or validate an arbitrary online HUD image. |

## Direct picture comparison

| Feature | F-22 illustration, R03 Fig.3 | C-130J photograph | Top Mach MSFS screenshot | Decision for this mod |
| --- | --- | --- | --- | --- |
| Speed/altitude | Two dotted circular counters, left/right, with digital values | Same broad arrangement | Same broad arrangement | Use original counter-pointer geometry; scales come from R03, not guessed from the C-130J photo. |
| Heading | Across the upper region | Upper scale/readout | Upper scale/readout | Add a wrapping heading tape and central reference. Tape span and glyph size remain assumptions. |
| Attitude | Central ladder, positive/negative differentiation | Central ladder | Central ladder | Project pitch marks in angular units and rotate them with bank; test sign/alignment in DCS. |
| Flight path | Central flight-path symbology | Central flight-path symbology | Explicit flight-path/velocity cue | Use **ground** velocity expressed in aircraft axes; hide when invalid and flag caged/off-scale. |
| Roll | Lower bank scale | Lower bank scale | Lower bank scale | Add lower scale and pointer. Exact tick placement/range are approximate. |
| Extra readouts | Ancillary flight numbers around the central region | Flight/navigation readouts, different aircraft/mode | Many annotated game features | Add measured Mach, g, AoA and radar altitude; do not import transport-specific approach/cargo cues or simulated autopilot/nav cues without backing data. |
| Combat | One public illustration cannot specify all modes | Transport picture does not define fighter cues | Entertainment simulation | Keep F-15 native tactical HUD fallback for combat. No fabricated APG-77 tracks, missile envelopes or bomb guidance. |

**Conclusion:** The user-identified resemblance is well supported at the flight-display layout level. It is reasonable to use the C-130J photo to cross-check spacing/readability and general symbol families. It does **not** justify cloning its mode logic, limits, scale changes, declutter, flight director or warning behavior into an F-22. Aircraft software and eras are not established as identical by these pictures.

## Implementation and verification

`Cockpit/Scripts/HUD/page.lua` contains original line geometry. `Systems/HUD_System.lua` owns data, validity, brightness and custom NAV/native combat selection. No performance/control-law values come from screenshots.

`tests/lua/hud_test.lua` checks counter wrap, velocity projection, heading wrap, power/mode transitions, bounded brightness, absence of per-frame native command spam, and unique/valid indicator construction. These checks cannot emulate DCS collimation, native HUD suppression, optical alignment, line/font rendering or VR. Those remain mandatory simulator checks. `HUD/config.lua` labels the unverified collimator plane and clipping dimensions explicitly.
