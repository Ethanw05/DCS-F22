# F-22 study resources

Checked 24 October 2026.

Study references for developing this mod from the Grinnelli F-22A baseline. It includes primary technical material, official public documents, manufacturer announcements, and explicitly labelled implementation sources. Access status is part of each entry: a discovered title or indexed excerpt is not presented as a fully reviewed paper. Mirrors and companion publication records are grouped where possible. The catalogue is a bounded public-source collection, not a claim to contain all information that exists.

## Highest-value additions

- Harris and Black: original F-22 control-law development paper, with 14 pages available through the web retrieval service.
- Brower: an accessible 11-page USAF-authored chapter on integrated avionics and display roles.
- Bailey and Greeley/Schwartz: directly relevant cockpit-design papers, currently limited to abstracts/indexed material.
- Peron: official high-angle-of-attack test summary; accessible copy is only one page.
- Public AFMAN operations/training/evaluation documents, with retrieval and version limitations recorded.
- Manufacturer references for F119 vectoring, APG-77, ALR-94 and Scorpion integration.

## Reading priorities for implementation

Use the manufacturer film and published JASDF/USAF illustration for basic HUD geometry. Use avionics architecture sources for display responsibilities and integration goals. Use flight-control papers for validation methodology and era-specific behaviours. Use product cards for basic geometry. Preserve the difference between a technology demonstration, a development contract, and an operationally fielded configuration.

## HUD, cockpit and display engineering

### R01 — GEC-Marconi F-22 HUD film, 7 July 1995

[Source](https://rochesteravionicarchives.co.uk/items/f-22-head-up-display-m)

**Access/review:** Inspected video.

**Use and limits:** Manufacturer test rig; direct symbology evidence. MP4: https://ark-raa.s3.eu-west-1.amazonaws.com/documents/e2ZXZgBQHM_1717047981.mp4

### R02 — USAF Flying Safety, June 2002 — Heads Up on Heads-Up

[Source](https://www.safety.af.mil/Portals/71/documents/Magazines/FSM/fsmjun02.pdf?ver=2017-03-28-101049-403)

**Access/review:** Indexed; direct retrieval blocked.

**Use and limits:** Maj Jeff Long; printed pp. 4–9, F-22 illustration p. 5. Accessible reproduction in the next paper; shared illustration origin.

### R03 — Aiba, JASDF Aeromedical Laboratory, 2008

[Source](https://www.jstage.jst.go.jp/article/jasdfaml/48/1/48_21/_pdf/-char/ja#page=3)

**Access/review:** Full text and figures inspected.

**Use and limits:** Figure 3 is the F-22 HUD illustration; Figure 1 explains counter-pointer scales. Not a complete mode specification.

### R04 — BAE digital light engine announcement, 2017

[Source](https://www.baesystems.com/en/article/digital-light-engine-technology-to-illuminate-f-22-head-up-display)

**Access/review:** Primary announcement reviewed.

**Use and limits:** HUD image-source modernization; do not infer a new layout or fleet completion.

### R05 — Raytheon F-22 digital HUD projector, 2017

[Source](https://raytheon.mediaroom.com/2017-09-12-Raytheon-projector-selected-for-new-F-22-digital-head-up-display-by-BAE-Systems)

**Access/review:** Primary announcement reviewed.

**Use and limits:** Drop-in optical/mechanical interface context.

### R06 — David C. Bailey — F-22 Cockpit Display System, 1994

[Source](https://doi.org/10.1117/12.177777)

**Access/review:** Publisher metadata/indexed excerpt; full text blocked.

**Use and limits:** SPIE 2219, pp. 157–165. A related DASC record is DOI 10.1109/DASC.1994.369439; do not count these automatically as independent evidence.

### R07 — Greeley and Schwartz — F-22 cockpit avionics: a systems integration success story, 2000

[Source](https://doi.org/10.1117/12.397775)

**Access/review:** Abstract reviewed; full text blocked.

**Use and limits:** Lockheed authors, SPIE 4022. Physical cockpit, controls, displays and human-factors integration. Abstract mirror: https://www.researchgate.net/publication/252554513_F-22_cockpit_avionics_a_systems_integration_success_story

### R08 — C. T. Bartlett — A second generation holographic Head Up Display

[Source](https://electronicimaging.spiedigitallibrary.org/proceedings/Download?downloadType=proceedings+article&isResultClick=True&urlId=10.1117%2F12.164709)

**Access/review:** Indexed lead; publisher blocked.

**Use and limits:** DOI 10.1117/12.164709. Indexed text references an F-22 HUD and an outline drawing. Do not claim the full paper or figure was inspected.

### R09 — Ronald W. Brower, USAF — Lockheed F-22 Raptor, Avionics Handbook chapter 32, 2001

[Source](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf)

**Access/review:** Full chapter accessible; relevant sections reviewed.

**Use and limits:** Original technical chapter on integrated avionics, display roles, processing and recovery. Historical architecture, not a current software specification; copy is a mirror.

### R10 — NASA/CR-97-206824 — Helmet-Mounted Display Design Guide, 1997

[Source](https://ntrs.nasa.gov/citations/19980018292)

**Access/review:** Downloaded; relevant pages inspected.

**Use and limits:** Newman and Greeley. PDF page 117/printed p. 95 explicitly omits F-22 JHMCS symbology. Appendix lists FF22MTAC.TXT/BMP but the files were not located. Historical HMD programme discussion does not establish fielding. PDF: https://ntrs.nasa.gov/api/citations/19980018292/downloads/19980018292.pdf

### R11 — Mulholland — Common software and interface for different HMD aircraft symbology sets, 2000

[Source](https://doi.org/10.1117/12.389156)

**Access/review:** Indexed/abstract evidence; full text blocked.

**Use and limits:** VSI software-interface discussion includes F-22 symbology sets. Does not prove operational F-22 JHMCS installation.

### R12 — NASA — Test techniques for evaluating flight displays

[Source](https://ntrs.nasa.gov/citations/19930012621)

**Access/review:** NASA abstract reviewed.

**Use and limits:** General display evaluation methodology, useful for testing a new HUD. Not F-22-specific symbology.

### R13 — MIL-HDBK-87213, electronically/optically generated airborne displays

[Source](https://quicksearch.dla.mil/WMX/Default.aspx?token=463898)

**Access/review:** Official indexed text; full document not inspected.

**Use and limits:** General display requirements and verification guidance. Mirror: https://www.cevians.com/app/uploads/2021/01/MIL-HDBK-87213.pdf ; record edition before applying requirements.

### R14 — MIL-STD-1787 official DLA record

[Source](https://quicksearch.dla.mil/qsDocDetails.aspx?ident_number=37143)

**Access/review:** Public catalogue reviewed.

**Use and limits:** Aircraft Display Symbology. Catalogue metadata is public; displayed distribution restrictions mean this is not an unrestricted full-text source.

### R15 — Ontiveros, AFIT thesis, 2008

[Source](https://scholar.afit.edu/etd/2761/)

**Access/review:** Downloaded; relevant figure inspected.

**Use and limits:** Development of a Night Vision Goggle Heads Up Display for Paratrooper Guidance. Printed p. 16/PDF p. 35 has a small F-22-captioned photo; inadequate for symbol transcription.

### R16 — Merriman and Karn — History of Human Factors in US Navy Aircraft Cockpit Design: 1969–2019

[Source](https://doi.org/10.1177/1071181319631405)

**Access/review:** Relevant author text reviewed.

**Use and limits:** Historical context for Flight Symbology Development Group influence; not a full F-22 symbol dictionary.

### R17 — Rochester: F-22 HUD optical module

[Source](https://rochesteravionicarchives.co.uk/items/f-22-hud-optical-module)

**Access/review:** Archive record/index reviewed.

**Use and limits:** Hardware provenance and geometry; separate object, not another symbology study.

### R18 — Rochester: prototype optical module and CRT assembly

[Source](https://rochesteravionicarchives.co.uk/items/f-22-hud-prototype-optical-module-crt-assembly)

**Access/review:** Archive record/index reviewed.

**Use and limits:** Prototype hardware reference.

### R19 — Rochester: diffractive combiner assembly

[Source](https://rochesteravionicarchives.co.uk/items/f-22-hud-diffractive-combiner-assembly)

**Access/review:** Archive record/index reviewed.

**Use and limits:** Optical hardware reference.

## Flight controls, aerodynamics, propulsion and dimensions

### R20 — Harris and Black, Lockheed — F-22 control law development and flying qualities, 1996

[Source](https://doi.org/10.2514/6.1996-3379)

**Access/review:** 14-page author PDF accessible through web retrieval; relevant text/plots reviewed.

**Use and limits:** AIAA-96-3379. Important distinction between YF-22 experience and F-22 development. Author PDF: https://www.researchgate.net/profile/Jeffrey-Harris-17/publication/269064311_F-22_control_law_development_and_flying_qualities/links/5693cac008ae3ad8e33b2fbc/F-22-control-law-development-and-flying-qualities.pdf

### R21 — Lee R. Peron, AFFTC — F-22 Initial High Angle-of-Attack Flight Test Results, 2000

[Source](https://sfte-ec.org/sfteecold/data/Abstract/A2000-II-02.pdf)

**Access/review:** One-page abstract/introduction inspected.

**Use and limits:** EMD high-alpha testing and departures; the accessible PDF is only one page, not the complete technical results. SFTE listing: https://www.sfte.org/high_aoa_departure_resistanc.php

### R22 — Rainey and Kohn — F-22 Flight Test Program Update, 1998

[Source](https://man.fas.org/dod-101/sys/ac/docs/f-22-emd-paper.htm)

**Access/review:** Original test-team paper mirrored; relevant text reviewed.

**Use and limits:** SETP-era envelope expansion, handling tasks, test aircraft and avionics test-bed context.

### R23 — Anderson and Mortara — F-22 Aeroelastic Design and Test Validation, 2007

[Source](https://doi.org/10.2514/6.2007-1764)

**Access/review:** Bibliographic/publisher lead; full text not inspected.

**Use and limits:** Aeroelastic and structural validation; not a substitute for aerodynamic coefficient tables.

### R24 — Maximum Control Surface Freeplay, Design and Flight Testing Approach on the F-22

[Source](https://www.researchgate.net/publication/268477804_Maximum_Control_Surface_Freeplay_Design_and_Flight_Testing_Approach_on_the_F-22)

**Access/review:** Bibliographic lead.

**Use and limits:** 2007 AIAA conference paper; potential actuator/freeplay modelling background, not validated numeric inputs here.

### R25 — Pratt & Whitney F119 product page

[Source](https://www.rtx.com/prattwhitney/products/military-engines/f119)

**Access/review:** Primary technical page reviewed.

**Use and limits:** 35,000-pound thrust class; two-dimensional pitch vectoring up/down up to 20 degrees, integrated FADEC/flight controls. Provides no complete altitude/Mach engine deck.

### R26 — Pratt & Whitney — 20 years of F119 flight, 2017

[Source](https://www.prattwhitney.com/newsroom/news/2017/09/07/pratt-whitney-celebrates-20-years-of-flight-for-the-f119-engine)

**Access/review:** Primary announcement indexed.

**Use and limits:** Engine/airframe development history; supporting context rather than performance calibration.

### R27 — Lockheed Martin F-22 Product Card

[Source](https://www.lockheedmartin.com/content/dam/lockheed-martin/aero/documents/f22/F-22-Product-Card.pdf)

**Access/review:** Manufacturer PDF indexed; direct retrieval blocked.

**Use and limits:** Published dimensions and wing area; wing area 840 square feet / 78.04 square metres.

### R28 — Lockheed Martin F-22 Fast Facts, September 2020

[Source](https://lockheedmartin.com/content/dam/lockheed-martin/aero/documents/F-22/FG19-24749_C%20F-22FastFacts_09_2020.pdf)

**Access/review:** Manufacturer PDF indexed; direct retrieval blocked.

**Use and limits:** Production/modernization snapshot; preserve the 2020 date.

### R29 — USAF F-22 fact sheet

[Source](https://www.af.mil/about-us/fact-sheets/display/article/104506/f-22-raptor/)

**Access/review:** Official indexed content; direct retrieval blocked.

**Use and limits:** General publicly released capabilities and configuration; approximate headline figures, not a flight-model truth table.

### R30 — DVIDS/NAWDC F-22 orthographic views, 2025

[Source](https://www.dvidshub.net/image/9081653/f-22-raptor-right-orthographic-view)

**Access/review:** Official page and caption reviewed.

**Use and limits:** Six-view geometry reference family. Caption data should be corroborated with programme/manufacturer sources before treating all numbers as authoritative.

### R31 — NASA — Cave of the Winds

[Source](https://www.nasa.gov/wp-content/uploads/2015/03/Cave_of_the_Winds.pdf)

**Access/review:** Relevant passage indexed.

**Use and limits:** Langley ATF support history; explains why NASA does not publish the YF-22/YF-23 tunnel results discussed there. Not a source for a complete public aero database.

### R32 — NATO RTO-TR-029 — Flight Control Design: Best Practices

[Source](https://publications.sto.nato.int/publications/STO%20Technical%20Reports/RTO-TR-029/TR-029-%24%24ALL.pdf)

**Access/review:** Indexed; direct retrieval blocked.

**Use and limits:** General control-design/validation methodology referencing F-22 work. Not aircraft-specific control source code.

### R33 — National Research Council — Aviation Safety and Pilot Control, 1997

[Source](https://www.nationalacademies.org/read/5469/chapter/11)

**Access/review:** Publisher page reviewed.

**Use and limits:** Workshop provenance identifies YF-22/F-22 pilot-coupling presentations. This linked appendix is a participant list, not those presentations' full texts.

## Sensors, weapons and configuration chronology

### R34 — Northrop Grumman AN/APG-77 AESA

[Source](https://www.northropgrumman.com/what-we-do/mission-solutions/radars/an-apg-77-aesa)

**Access/review:** Manufacturer description indexed.

**Use and limits:** System role and broad air/ground capability. Does not justify an exact detection range against every target.

### R35 — Northrop Grumman — F-22 SAR demonstration

[Source](https://investor.northropgrumman.com/news-releases/news-release-details/northrop-grumman-completes-successful-demonstration-new)

**Access/review:** Primary announcement indexed; direct retrieval blocked.

**Use and limits:** APG-77(V)1 air-to-ground/SAR development; test-bed demonstration date must be separated from aircraft fleet fielding.

### R36 — BAE AN/ALR-94 product page

[Source](https://www.baesystems.com/en-us/product/an-alr-94)

**Access/review:** Primary page reviewed.

**Use and limits:** Integrated warning, passive geolocation, targeting support and countermeasures roles; no complete performance or cockpit format specification.

### R37 — BAE F-22 EW sustainment announcement, 2023

[Source](https://www.baesystems.com/en-us/article/bae-systems-to-keep-f-22-raptor-electronic-warfare-mission-systems-ready-and-relevant)

**Access/review:** Primary announcement indexed.

**Use and limits:** Confirms named system and sustainment context; not new symbol geometry.

### R38 — Thales ROST-HD/Scorpion development announcement, 20 September 2024

[Source](https://www.thalesdsi.com/2024/09/20/thales-awarded-diu-contract-f22-hmd-interface-dev/)

**Access/review:** Primary page reviewed.

**Use and limits:** F-22-specific HMD integration/testing contract. Does not establish fleet-wide operational availability.

### R39 — F-22 Increment 3.2B Selected Acquisition Report, December 2017

[Source](https://www.esd.whs.mil/Portals/54/Documents/FOID/Reading%20Room/Selected_Acquisition_Reports/FY_2017_SARS/18-F-1016_DOC_10_AF_F-22_Inc_32B_Mod_SAR_Dec_2017.pdf)

**Access/review:** Official report indexed.

**Use and limits:** AIM-9X/AIM-120D integration, electronic protection and datalink modernization scope. Plans and delivered configurations differ.

### R40 — DOT&E F-22 FY2019 report

[Source](https://www.dote.osd.mil/Portals/97/pub/reports/FY2019/af/2019f22a.pdf)

**Access/review:** Official report indexed.

**Use and limits:** Increment 3.2B-era test/configuration chronology.

### R41 — DOT&E F-22 FY2024 report

[Source](https://www.dote.osd.mil/Portals/97/pub/reports/FY2024/af/2024f-22a.pdf)

**Access/review:** Official report indexed; direct retrieval blocked.

**Use and limits:** Later operational-flight-program test status. Public report does not reveal the underlying classified evaluation details.

### R42 — DOT&E F-22 FY2025 report

[Source](https://www.dote.osd.mil/Portals/97/pub/reports/FY2025/af/2025f-22a.pdf)

**Access/review:** Official report indexed; direct retrieval blocked.

**Use and limits:** Current public modernization/test overview. Confirm retrieved version before extracting detailed claims.

### R43 — USAF/WADS F-22 fact sheet: armament

[Source](https://www.wads.ang.af.mil/About-Us/Fact-Sheets/Article/1175462/f-22-factsheet/)

**Access/review:** Official indexed content.

**Use and limits:** Baseline internal gun/missile/JDAM carriage. Useful for rejecting unsupported loadouts; not every later upgrade is captured.

### R44 — USAF/Edwards — first supersonic SDB drop

[Source](https://www.edwards.af.mil/News/Display/Article/396020/f-22-raptor-performs-first-supersonic-sdb-drop/)

**Access/review:** Primary test announcement indexed.

**Use and limits:** GBU-39 separation/integration testing; does not supply a complete bombing solution.

### R45 — USAF/ACC — Langley SDB fit test

[Source](https://www.acc.af.mil/News/Article-Display/Article/202995/langley-crew-conducts-fit-test-for-new-weapon/)

**Access/review:** Primary announcement indexed.

**Use and limits:** Stores-fit and carriage development; fit checks alone do not prove operational integration.

### R46 — Lockheed Martin Mako product/development announcement, 2024

[Source](https://www.lockheedmartin.com/en-us/news/features/2024/mako-a-hypersonic-missile-thats-more-than-ready.html)

**Access/review:** Primary announcement indexed; direct retrieval blocked.

**Use and limits:** Hypersonic multi-mission missile development; does not validate the mod's custom MAKO air-to-air implementation or its numbers.

### R47 — Boeing — integrated F-22 avionics package, 13 December 1999

[Source](https://boeing.mediaroom.com/1999-12-13-Boeing-Delivers-Updated-F-22-Integrated-Avionics-Package)

**Access/review:** Primary announcement indexed.

**Use and limits:** Historical Block 1.2 software and systems integration context.

## Operations, life support and official imagery

### R48 — AFMAN 11-2F-22A Volume 3 — Operations Procedures

[Source](https://static.e-publishing.af.mil/production/1/af_a3/publication/afman11-2f-22av3/afman11-2f-22av3.pdf)

**Access/review:** Official indexed record; direct retrieval blocked; version unresolved.

**Use and limits:** Search results expose a 2 July 2026 cover and older 2018 extracts at the same URL. Do not mix editions or cite detailed current procedures until actual PDF retrieval verifies the version.

### R49 — AFMAN 11-2F-22A Volume 1 — Aircrew Training, 7 August 2025

[Source](https://static.e-publishing.af.mil/production/1/af_a3/publication/afman11-2f-22av1/afman11-2f-22av1.pdf)

**Access/review:** Official indexed excerpts reviewed; full download blocked.

**Use and limits:** Training and block-differences requirements, including HUD-out training. Not the technical flight manual.

### R50 — AFMAN 11-2F-22A Volume 2 — Aircrew Evaluation Criteria, 14 August 2023

[Source](https://static.e-publishing.af.mil/production/1/af_a3/publication/afman11-2f-22av2/afman11-2f-22av2.pdf)

**Access/review:** Official indexed excerpts reviewed; full download blocked.

**Use and limits:** Evaluation tasks and HUD-out emergency-procedure checks; useful for a simulator test plan.

### R51 — DoD IG DODIG-2013-041, including 2010 AIB material

[Source](https://www.airandspaceforces.com/SiteCollectionDocuments/Reports/2013/February%202013/Day13/DODIG_F-22_020613.pdf)

**Access/review:** Original report mirror downloaded; relevant pages inspected.

**Use and limits:** CAUT evidence and accident reconstruction. The reconstruction is not literal HUD video. Official URL: https://media.defense.gov/2013/Feb/06/2001712802/-1/-1/1/DODIG-2013-041.pdf

### R52 — USAF — automatic backup oxygen installation, 2014

[Source](https://www.af.mil/News/Article-Display/Article/478362/installation-of-backup-oxygen-system-in-f-22-combat-fleet-continues/)

**Access/review:** Primary announcement indexed.

**Use and limits:** ABOS retrofit chronology and life-support context; no full pressure/flow or emergency logic specification.

### R53 — USAF — return to normal operations, 2013

[Source](https://www.af.mil/News/Article-Display/Article/109415/f-22-resumes-normal-flight-operations/)

**Access/review:** Primary announcement indexed.

**Use and limits:** Aircrew equipment modifications and operational restriction history; preserve chronology.

### R54 — Congressional hearing — F-22 Pilot Physiological Issues, 2012

[Source](https://www.govinfo.gov/content/pkg/CHRG-112hhrg76215/html/CHRG-112hhrg76215.htm)

**Access/review:** Official hearing indexed.

**Use and limits:** Primary testimony for life-support development and corrective actions. Statements must be attributed and dated.

### R55 — USAF/DVIDS — F-22 Raptor: Inside the Cockpit, 16 May 2019

[Source](https://www.dvidshub.net/video/681055/f-22-raptor-inside-cockpit)

**Access/review:** Official provenance reviewed; footage not frame-audited in this pass.

**Use and limits:** 2:41 film by Sam Eckholm. Candidate visual material; legibility of HUD symbols must be checked before transcription.

### R56 — USAF/DVIDS — Full F-22 Demo, 2020

[Source](https://www.trngcmd.marines.mil/News/Videos/videoid/744272/)

**Access/review:** Official description indexed; footage not frame-audited.

**Use and limits:** Demo cockpit footage, useful for motion/handling observation with unknown camera and aircraft conditions.

### R57 — USAF/DVIDS — Cockpit B-Roll, video 992965

[Source](https://www.dvidshub.net/video/992965/f-22-raptor-aerial-demonstration-team-cockpit-b-roll)

**Access/review:** Official provenance reviewed; footage not frame-audited.

**Use and limits:** Page posted January 2026 but description identifies 2023-season flying. Do not label it a 2026 aircraft configuration from upload date.

### R58 — USAF/DVIDS — Max Vertical Climb, video 759958

[Source](https://www.acc.af.mil/News/Video/dvpTag/f/dvpmoduleid/20299/videoid/759958/)

**Access/review:** Official description indexed; footage not frame-audited.

**Use and limits:** Additional real-aircraft visual candidate, not a calibrated thrust/weight measurement.

## Simulation implementation and mod ecosystem

### R59 — Grinnelli F-22 source

[Source](https://github.com/grinnellidesigns/f-22a)

**Access/review:** Cloned at 8484b44; source inventory and selected deep review.

**Use and limits:** 323 tracked files; open custom EFM/Lua with proprietary DCS avionics dependencies. This is the implementation under audit, not an aircraft reference.

### R60 — B-HOOP Block 40 original developer announcement

[Source](https://www.reddit.com/r/hoggit/comments/1tg5m2y/update_on_f22_mod_for_dcs_world_f22_block_40/)

**Access/review:** Developer post reviewed.

**Use and limits:** Custom avionics/HUD claims and WIP status. Public source/release not verified.

### R61 — Nightstorm enhancement thread

[Source](https://forum.dcs.world/topic/252855-f-22a-raptor-mod-enhancement-mod/)

**Access/review:** Author post and final public page reviewed.

**Use and limits:** External addon, separate from public GitHub fork audit. ZIP source not audited.

### R62 — Custom Fox-3 guidance compatibility discussion, March 2026

[Source](https://forum.dcs.world/topic/385903-custom-fox-3-missiles-are-now-broken/)

**Access/review:** Contributor reports and both pages reviewed.

**Use and limits:** First-person modder reports, not a confirmed universal root cause or current fix.

### R63 — ZedaSoft commercial F-22 simulator

[Source](https://www.zedasoft.com/product/f-22-raptor/)

**Access/review:** Vendor description indexed.

**Use and limits:** Commercial HUD/navigation/weapons plugin claim. No public source or independent aircraft-fidelity validation located.

### R64 — Legacy F-22 autothrottle addon

[Source](https://github.com/kingDevGit/DCS-F-22A-Auto-throttle-ATC)

**Access/review:** Repository/README reviewed.

**Use and limits:** Last push February 2023; compatibility with 2025 EFM unverified.

## Evidence limits and corrections

- The JASDF F-22 illustration reproduces the USAF illustration; it is not an independent second visual observation.
- The 1995 rig demonstration, 2001 architecture chapter, later operational increments and current upgrade announcements describe different eras.
- The 1997 NASA HMD guide is historical research. Its discussion of F-22/JHMCS does not prove the operational F-22 fielded that system.
- AFMAN Volume 3 indexed results mix editions at one URL. An actual downloaded current PDF is required before version-specific conclusions.
- Several official publishers returned HTTP 403 or bot checks. These entries remain useful leads, with their access limits stated.
- Simulator manuals and mod screenshots cannot independently establish real F-22 display formats.
- Full aerodynamic tables, complete engine decks, detailed radar/EW performance and full current HUD mode logic were not established by these sources.


## Additional research: aircraft systems and test development

### R65 — Thrust vector aided maneuvering of the YF-22 Advanced Tactical Fighter prototype — Robert Barham, 1994

[Source](https://doi.org/10.2514/6.1994-2105)

Publisher bibliographic record located; full text not reviewed. Prototype thrust-vectoring development; distinguish YF-22 results from production F-22 behaviour.

### R66 — F-22 Aircraft Battery-Charger-Controller System — Thomas Stoneham, 1999

[Source](https://saemobilus.sae.org/papers/f-22-aircraft-battery-charger-controller-system-1999-01-1363)

Publisher abstract reviewed. Describes a 28 V nickel-cadmium battery and a charger-controller powered from 270 VDC. Full paper access not established.

### R67 — F-22 ECS/TMS Design Optimization for Reliability and Integrity — James Sprouse, 1996

[Source](https://saemobilus.sae.org/papers/f-22-environmental-control-thermal-management-system-design-optimization-reliability-integrity-a-case-study-961339)

Publisher abstract reviewed; full paper not reviewed. Integrated environmental conditioning/pressurization and thermal-management design assurance.

### R68 — Application of MIL-C-87252 in F-22 Liquid Cooling System — Baird and Ferentinos, 1998

[Source](https://saemobilus.sae.org/papers/application-mil-c-87252-f-22-liquid-cooling-system-981543)

Publisher abstract reviewed; full paper not reviewed. Coolant selection, PAO fluid application and ECS/TMS cooling-system lessons.

### R69 — F-22 ECS/TMS Flight Test Program: Downloadable Constants — Ashford and Brown, 2000

[Source](https://saemobilus.sae.org/papers/f-22-environmental-control-system-thermal-management-system-ecs-tms-flight-test-program-downloadable-constants-innovative-approach-2000-01-2265)

Publisher abstract reviewed; full paper not reviewed. Parameterized ECS software tuning during flight testing; not a source for the actual constant values.

### R70 — Development of an Integrated Environmental Control System, 1998

[Source](https://saemobilus.sae.org/papers/development-integrated-environmental-control-system-981544)

Publisher indexed abstract reviewed. F-22 ECS/TMS development challenges and lessons; full paper not reviewed.

### R71 — F-22 ECS/TMS Qualification Test Program Overview — Sprouse, 1997

[Source](https://saemobilus.sae.org/papers/f-22-ecs-tms-qualification-test-program-overview-972261)

Publisher bibliographic record located. Qualification-test reference; detailed contents not reviewed.

### R72 — Vapor Cycle System for the F-22 Raptor, 2000

[Source](https://saemobilus.sae.org/papers/vapor-cycle-system-f-22-raptor-2000-01-2268)

Publisher indexed abstract reviewed. Functional description of the refrigeration pack and compressor; full paper not reviewed.

### R73 — F-22 Avionic Test and Evaluation Standard File Format, 1997

[Source](https://www.sfte.org/technical_library_-_sensors_an.php)

SFTE primary catalogue lists the paper; article link requires member login. Detailed contents not reviewed.

### R74 — Instrumenting the Prototype Fighter: The YF-22A Story, 1994

[Source](https://www.sfte.org/technical_library_-_sensors_an.php)

SFTE primary catalogue lists the paper; article link requires member login. Prototype test-instrumentation reference, not an operational avionics manual.

### R75 — Boeing: First F-22 Avionics Software, 30 November 1998

[Source](https://boeing.mediaroom.com/1998-11-30-Boeing-Delivers-First-F-22-Avionics-Software)

Primary announcement reviewed. Early flight-test-bed software and cockpit/display integration chronology.

### R76 — Boeing: F-22 Avionics Software Block 3.0, 27 November 2000

[Source](https://boeing.mediaroom.com/2000-11-27-Boeing-Delivers-F-22-Avionics-Software)

Primary announcement reviewed. Historical sensor-fusion and weapons-delivery development. This early Block 3.0 naming is distinct from later operational increments.

### R77 — Boeing: F-22 Integrated Avionics Software Block 3.1, 6 February 2002

[Source](https://boeing.mediaroom.com/2002-02-06-Boeing-Delivers-F-22-Integrated-Avionics-Software)

Primary announcement reviewed. Radar/EW/CNI/GPS integration chronology; preserve the 2002 date and development context.

### R78 — Boeing: Updated F-22 Avionics Software, 26 October 1999

[Source](https://boeing.mediaroom.com/1999-10-26-Boeing-Delivers-Updated-F-22-Avionics-Software)

Primary announcement indexed. EW/CNI and missile-launch-detector test development; full detailed technical implementation not published here.

### R79 — Origins of the F-22 Raptor — Albert Piccirillo, 1998

[Source](https://saemobilus.sae.org/papers/origins-f-22-raptor-985566)

Publisher record and indexed abstract reviewed. Aircraft development provenance; full paper not reviewed.

### R80 — Lockheed Martin: F-22 Infrared Defensive System integration, 22 January 2025

[Source](https://news.lockheedmartin.com/2025-01-22-Lockheed-Martin-to-Modernize-Air-Force-F-22-Raptor-with-Advanced-Infrared-Threat-Detection-Sensors)

Primary announcement reviewed. Distributed embedded TacIRST sensors/IRDS integration contract; not proof of fleet-wide completion or evidence for the mod external pod implementation.

