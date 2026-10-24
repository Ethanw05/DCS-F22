# Bibliography and traceability

**Legend**: P = primary/official; R = peer-reviewed research; S = secondary comparative simulation. Accessible abstract/preview does not mean full text verified. Do not embed copyright-controlled PDFs or screenshots without permission.

| Ref | Reference | Status and implementation relevance |
|---|---|---|
| N01 | [USAF *Flying Safety*, June 2002, `fsmjun02.pdf`](https://www.safety.af.mil/Portals/71/documents/Magazines/FSM/fsmjun02.pdf?ver=2017-03-28-101049-403) | P. Published F-22 HUD (Figure 1), counter-pointer discussion. Official PDF may return 403; copy provided by user. |
| N02 | [Kiyohiko Aiba, 2008: *Format Comparison between Moving-Tape and Counter-Pointer as Displaying Airspeed and Altitude on a Head-Up Display*](https://www.jstage.jst.go.jp/article/jasdfaml/48/1/48_21/_pdf/-char/ja) | R. JASDF pilot survey, nine pages. Fig. 3 repeats F-22 illustration; Fig. 1(B) documents generic 10-kt/100-ft tick increments and 100-kt/1000-ft turns. Do not claim those figures are validated production F-22 counter ranges. |
| N03 | [FSDeveloper: MIL-STD, *F-22A Advanced Avionics*, 2018–2025 thread](https://www.fsdeveloper.com/forum/threads/f-22a-advanced-avionics.443209/) | S. Explicitly references MIL-STD-1787, 'Increment 3.1/3.2A Update-5', custom vehicle-management systems, and public F-22 simulators. No public code/reuse license confirmed. |
| N04 | [Original MIL-STD/Richard Carter HUD screenshot](https://richardacarter.com/wp-content/uploads/2018/04/1F.png) | S. Visual comparison only, not authenticated real aircraft capture. |
| N05 | [Original MIL-STD/Richard Carter SAR screenshot](https://richardacarter.com/wp-content/uploads/2018/04/4F.png) | S. Simulated radar page, not APG-77 technical data. |
| N06 | [FSDeveloper: camera view texture in an XML gauge rendering bug](https://www.fsdeveloper.com/forum/threads/camera-view-texture-in-an-xml-gauge-rendering-bug.441228/) | S. MIL-STD discussion of a simulated sensor camera texture/XML cockpit rendering. |
| N07 | [FSDeveloper: autopilot PID variable calculation](https://www.fsdeveloper.com/forum/threads/autopilot-pid-variable-calculation.448274/page-2) | S. MIL-STD's feedback-control implementation discussion, not production F-22 gains. |
| N08 | [David Allerton, *Principles of Flight Simulation* (2009)](https://onlinelibrary.wiley.com/doi/book/10.1002/9780470685662) | Published textbook; cited by MIL-STD for control/autopilot pseudocode. Especially Chs. 4–5. Book/code access and licensing require separate confirmation. |
| N09 | [DLA ASSIST: MIL-STD-1787 Aircraft Display Symbology](https://quicksearch.dla.mil/qsDocDetails.aspx?ident_number=37143) | P. HUD guidance/specification family, not an F-22-specific operating manual. Current distribution control may apply. |
| N10 | [MIL-HDBK-87213, Airborne Displays (1996)](https://www.cevians.com/app/uploads/2021/01/MIL-HDBK-87213.pdf) | P. Public-release generic HUD geometry, luminance, optical and verification methods; **not** F-22 optical calibration. |
| N11 | [F-22 Cockpit Avionics: A Systems Integration Success Story (2000)](https://doi.org/10.1117/12.397775) | P conference paper/abstract. Human–machine interface and avionics architecture; full text not verified. |
| N12 | [Steve Pace, *F-22 Raptor: America's Next Lethal War Machine* (1999)](https://library.qu.edu.iq/wp-content/uploads/2020/09/4.pdf) | Historical book. Prototype-era cockpit and HUD discussions, verify dimensions against manufacturer evidence. |
| N13 | [Boeing: F-22 Advanced Avionics Integration (1998)](https://boeing.mediaroom.com/1998-01-29-Boeing-Begins-Integrating-F-22-Fighters-Advanced-Avionics) | P. VMS, integrated vehicle systems, displays and integration architecture. |
| N14 | [DoD FY2018 Operational Test & Evaluation report](https://www.dote.osd.mil/Portals/97/pub/reports/FY2018/other/2018DOTEAnnualReport.pdf?ver=2019-08-21-155621-540) | P. Increment 3.1, 3.2A/3.2B and Update 5 capability *context*, not simulated tactical algorithms. |
| N15 | [BAE: F-22 Digital Light Engine HUD technology (2017)](https://www.baesystems.com/en-us/article/digital-light-engine-technology-to-illuminate-f-22-head-up-display) | P for HUD optical modernization; promotional HUD image is not authenticated F-22 operational symbology. |
| N16 | [USAF Museum: F-22A cockpit photograph](https://commons.wikimedia.org/wiki/File:Lockheed_Martin_F-22A_Raptor_cockpit.jpg) | Attributed real hardware photo, HUD optical structure only. |
| N17 | [Rochester Avionic Archives: F-22 HUD diffractive combiner](https://rochesteravionicarchives.co.uk/items/f-22-hud-diffractive-combiner-assembly) | Historical hardware archive, combiner geometry/composition, not powered HUD. |
| N18 | [Russian VPK.name comparative holographic HUD article](https://vpk.name/news/35397_kitaiskii_golograficheskii_ils_dlya_j-11b_foto.html) | Secondary, comparative F-22 cockpit image only. |
| N19 | [Chinese Sina F-22A HUD close-up article (2006)](https://jczs.news.sina.com.cn/p/2006-05-27/1032373310.html) | Attributed unpowered cockpit photo; no operational HUD symbols. |
| N20 | [DVIDS: F-22 Raptor Inside the Cockpit (2019)](https://www.dvidshub.net/video/681055/f-22-raptor-inside-cockpit) | Official video, cockpit authentic; legible HUD symbology not established. |

## Explicitly unresolved from MIL-STD's posts

- The identity/location and license of the **1974 FORTRAN gunsight source** he said he adapted.
- Which **public F-22 simulators** he used as MFD references.
- The developer's unpublished original research bibliography, source code and permission to reuse code.
- The precise scope of the original MIL-STD-1787 revision(s) he referenced.

Search for these as separate leads; do not turn a plausible source into a confirmed citation. Cross-reference [existing catalog](../../docs/RESOURCES.md) to avoid counting mirrors and repeated illustrations as independent evidence.
