# F-22 study resources

Checked 24 October 2026.

**153 numbered entries.** Start with the [focused reading guide](RESEARCH_GUIDE.md) for avionics, HUD and flight performance. R88–R147 are the 60 additions from the expanded aircraft research pass; R148–R153 add standalone-mod implementation references and an official performance-summary lead. Supporting methods and access-limited leads are labelled.

The [overhaul assessment](OVERHAUL_ASSESSMENT.md) connects the references to the current code. The [standalone design](STANDALONE_DESIGN.md) and [roadmap](OVERHAUL_ROADMAP.md) separate implementable improvements from host-interface uncertainties.

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

<a id="r01"></a>

### R01 — GEC-Marconi F-22 HUD film, 7 July 1995

[Source](https://rochesteravionicarchives.co.uk/items/f-22-head-up-display-m)

**Access/review:** Inspected video.

**Use and limits:** Manufacturer test rig; direct symbology evidence. MP4: https://ark-raa.s3.eu-west-1.amazonaws.com/documents/e2ZXZgBQHM_1717047981.mp4

<a id="r02"></a>

### R02 — USAF Flying Safety, June 2002 — Heads Up on Heads-Up

[Source](https://www.safety.af.mil/Portals/71/documents/Magazines/FSM/fsmjun02.pdf?ver=2017-03-28-101049-403)

**Access/review:** Indexed; direct retrieval blocked.

**Use and limits:** Maj Jeff Long; printed pp. 4–9, F-22 illustration p. 5. Accessible reproduction in the next paper; shared illustration origin.

<a id="r03"></a>

### R03 — Aiba, JASDF Aeromedical Laboratory, 2008

[Source](https://www.jstage.jst.go.jp/article/jasdfaml/48/1/48_21/_pdf/-char/ja#page=3)

**Access/review:** Full text and figures inspected.

**Use and limits:** Figure 3 is the F-22 HUD illustration; Figure 1 explains counter-pointer scales. Not a complete mode specification.

<a id="r04"></a>

### R04 — BAE digital light engine announcement, 2017

[Source](https://www.baesystems.com/en/article/digital-light-engine-technology-to-illuminate-f-22-head-up-display)

**Access/review:** Primary announcement reviewed.

**Use and limits:** HUD image-source modernization; do not infer a new layout or fleet completion.

<a id="r05"></a>

### R05 — Raytheon F-22 digital HUD projector, 2017

[Source](https://raytheon.mediaroom.com/2017-09-12-Raytheon-projector-selected-for-new-F-22-digital-head-up-display-by-BAE-Systems)

**Access/review:** Primary announcement reviewed.

**Use and limits:** Drop-in optical/mechanical interface context.

<a id="r06"></a>

### R06 — David C. Bailey — F-22 Cockpit Display System, 1994

[Source](https://doi.org/10.1117/12.177777)

**Access/review:** Publisher metadata/indexed excerpt; full text blocked.

**Use and limits:** SPIE 2219, pp. 157–165. A related DASC record is DOI 10.1109/DASC.1994.369439; do not count these automatically as independent evidence.

<a id="r07"></a>

### R07 — Greeley and Schwartz — F-22 cockpit avionics: a systems integration success story, 2000

[Source](https://doi.org/10.1117/12.397775)

**Access/review:** Abstract reviewed; full text blocked.

**Use and limits:** Lockheed authors, SPIE 4022. Physical cockpit, controls, displays and human-factors integration. Abstract mirror: https://www.researchgate.net/publication/252554513_F-22_cockpit_avionics_a_systems_integration_success_story

<a id="r08"></a>

### R08 — C. T. Bartlett — A second generation holographic Head Up Display

[Source](https://electronicimaging.spiedigitallibrary.org/proceedings/Download?downloadType=proceedings+article&isResultClick=True&urlId=10.1117%2F12.164709)

**Access/review:** Indexed lead; publisher blocked.

**Use and limits:** DOI 10.1117/12.164709. Indexed text references an F-22 HUD and an outline drawing. Do not claim the full paper or figure was inspected.

<a id="r09"></a>

### R09 — Ronald W. Brower, USAF — Lockheed F-22 Raptor, Avionics Handbook chapter 32, 2001

[Source](https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf)

**Access/review:** Full chapter accessible; relevant sections reviewed.

**Use and limits:** Original technical chapter on integrated avionics, display roles, processing and recovery. Historical architecture, not a current software specification; copy is a mirror.

<a id="r10"></a>

### R10 — NASA/CR-97-206824 — Helmet-Mounted Display Design Guide, 1997

[Source](https://ntrs.nasa.gov/citations/19980018292)

**Access/review:** Downloaded; relevant pages inspected.

**Use and limits:** Newman and Greeley. PDF page 117/printed p. 95 explicitly omits F-22 JHMCS symbology. Appendix lists FF22MTAC.TXT/BMP but the files were not located. Historical HMD programme discussion does not establish fielding. PDF: https://ntrs.nasa.gov/api/citations/19980018292/downloads/19980018292.pdf

<a id="r11"></a>

### R11 — Mulholland — Common software and interface for different HMD aircraft symbology sets, 2000

[Source](https://doi.org/10.1117/12.389156)

**Access/review:** Indexed/abstract evidence; full text blocked.

**Use and limits:** VSI software-interface discussion includes F-22 symbology sets. Does not prove operational F-22 JHMCS installation.

<a id="r12"></a>

### R12 — NASA — Test techniques for evaluating flight displays

[Source](https://ntrs.nasa.gov/citations/19930012621)

**Access/review:** NASA abstract reviewed.

**Use and limits:** General display evaluation methodology, useful for testing a new HUD. Not F-22-specific symbology.

<a id="r13"></a>

### R13 — MIL-HDBK-87213, electronically/optically generated airborne displays

[Source](https://quicksearch.dla.mil/WMX/Default.aspx?token=463898)

**Access/review:** Official indexed text; full document not inspected.

**Use and limits:** General display requirements and verification guidance. Mirror: https://www.cevians.com/app/uploads/2021/01/MIL-HDBK-87213.pdf ; record edition before applying requirements.

<a id="r14"></a>

### R14 — MIL-STD-1787 official DLA record

[Source](https://quicksearch.dla.mil/qsDocDetails.aspx?ident_number=37143)

**Access/review:** Public catalogue reviewed.

**Use and limits:** Aircraft Display Symbology. Catalogue metadata is public; displayed distribution restrictions mean this is not an unrestricted full-text source.

<a id="r15"></a>

### R15 — Ontiveros, AFIT thesis, 2008

[Source](https://scholar.afit.edu/etd/2761/)

**Access/review:** Downloaded; relevant figure inspected.

**Use and limits:** Development of a Night Vision Goggle Heads Up Display for Paratrooper Guidance. Printed p. 16/PDF p. 35 has a small F-22-captioned photo; inadequate for symbol transcription.

<a id="r16"></a>

### R16 — Merriman and Karn — History of Human Factors in US Navy Aircraft Cockpit Design: 1969–2019

[Source](https://doi.org/10.1177/1071181319631405)

**Access/review:** Relevant author text reviewed.

**Use and limits:** Historical context for Flight Symbology Development Group influence; not a full F-22 symbol dictionary.

<a id="r17"></a>

### R17 — Rochester: F-22 HUD optical module

[Source](https://rochesteravionicarchives.co.uk/items/f-22-hud-optical-module)

**Access/review:** Archive record/index reviewed.

**Use and limits:** Hardware provenance and geometry; separate object, not another symbology study.

<a id="r18"></a>

### R18 — Rochester: prototype optical module and CRT assembly

[Source](https://rochesteravionicarchives.co.uk/items/f-22-hud-prototype-optical-module-crt-assembly)

**Access/review:** Archive record/index reviewed.

**Use and limits:** Prototype hardware reference.

<a id="r19"></a>

### R19 — Rochester: diffractive combiner assembly

[Source](https://rochesteravionicarchives.co.uk/items/f-22-hud-diffractive-combiner-assembly)

**Access/review:** Archive record/index reviewed.

**Use and limits:** Optical hardware reference.

## Flight controls, aerodynamics, propulsion and dimensions

<a id="r20"></a>

### R20 — Harris and Black, Lockheed — F-22 control law development and flying qualities, 1996

[Source](https://doi.org/10.2514/6.1996-3379)

**Access/review:** 14-page author PDF accessible through web retrieval; relevant text/plots reviewed.

**Use and limits:** AIAA-96-3379. Important distinction between YF-22 experience and F-22 development. Author PDF: https://www.researchgate.net/profile/Jeffrey-Harris-17/publication/269064311_F-22_control_law_development_and_flying_qualities/links/5693cac008ae3ad8e33b2fbc/F-22-control-law-development-and-flying-qualities.pdf

<a id="r21"></a>

### R21 — Lee R. Peron, AFFTC — F-22 Initial High Angle-of-Attack Flight Test Results, 2000

[Source](https://sfte-ec.org/sfteecold/data/Abstract/A2000-II-02.pdf)

**Access/review:** One-page abstract/introduction inspected.

**Use and limits:** EMD high-alpha testing and departures; the accessible PDF is only one page, not the complete technical results. SFTE listing: https://www.sfte.org/high_aoa_departure_resistanc.php

<a id="r22"></a>

### R22 — Rainey and Kohn — F-22 Flight Test Program Update, 1998

[Source](https://man.fas.org/dod-101/sys/ac/docs/f-22-emd-paper.htm)

**Access/review:** Original test-team paper mirrored; relevant text reviewed.

**Use and limits:** SETP-era envelope expansion, handling tasks, test aircraft and avionics test-bed context.

<a id="r23"></a>

### R23 — Anderson and Mortara — F-22 Aeroelastic Design and Test Validation, 2007

[Source](https://doi.org/10.2514/6.2007-1764)

**Access/review:** Bibliographic/publisher lead; full text not inspected.

**Use and limits:** Aeroelastic and structural validation; not a substitute for aerodynamic coefficient tables.

<a id="r24"></a>

### R24 — Maximum Control Surface Freeplay, Design and Flight Testing Approach on the F-22

[Source](https://www.researchgate.net/publication/268477804_Maximum_Control_Surface_Freeplay_Design_and_Flight_Testing_Approach_on_the_F-22)

**Access/review:** Bibliographic lead.

**Use and limits:** 2007 AIAA conference paper; potential actuator/freeplay modelling background, not validated numeric inputs here.

<a id="r25"></a>

### R25 — Pratt & Whitney F119 product page

[Source](https://www.rtx.com/prattwhitney/products/military-engines/f119)

**Access/review:** Primary technical page reviewed.

**Use and limits:** 35,000-pound thrust class; two-dimensional pitch vectoring up/down up to 20 degrees, integrated FADEC/flight controls. Provides no complete altitude/Mach engine deck.

<a id="r26"></a>

### R26 — Pratt & Whitney — 20 years of F119 flight, 2017

[Source](https://www.prattwhitney.com/newsroom/news/2017/09/07/pratt-whitney-celebrates-20-years-of-flight-for-the-f119-engine)

**Access/review:** Primary announcement indexed.

**Use and limits:** Engine/airframe development history; supporting context rather than performance calibration.

<a id="r27"></a>

### R27 — Lockheed Martin F-22 Product Card

[Source](https://www.lockheedmartin.com/content/dam/lockheed-martin/aero/documents/f22/F-22-Product-Card.pdf)

**Access/review:** Manufacturer PDF indexed; direct retrieval blocked.

**Use and limits:** Published dimensions and wing area; wing area 840 square feet / 78.04 square metres.

<a id="r28"></a>

### R28 — Lockheed Martin F-22 Fast Facts, September 2020

[Source](https://lockheedmartin.com/content/dam/lockheed-martin/aero/documents/F-22/FG19-24749_C%20F-22FastFacts_09_2020.pdf)

**Access/review:** Manufacturer PDF indexed; direct retrieval blocked.

**Use and limits:** Production/modernization snapshot; preserve the 2020 date.

<a id="r29"></a>

### R29 — USAF F-22 fact sheet

[Source](https://www.af.mil/about-us/fact-sheets/display/article/104506/f-22-raptor/)

**Access/review:** Official indexed content; direct retrieval blocked.

**Use and limits:** General publicly released capabilities and configuration; approximate headline figures, not a flight-model truth table.

<a id="r30"></a>

### R30 — DVIDS/NAWDC F-22 orthographic views, 2025

[Source](https://www.dvidshub.net/image/9081653/f-22-raptor-right-orthographic-view)

**Access/review:** Official page and caption reviewed.

**Use and limits:** Six-view geometry reference family. Caption data should be corroborated with programme/manufacturer sources before treating all numbers as authoritative.

<a id="r31"></a>

### R31 — NASA — Cave of the Winds

[Source](https://www.nasa.gov/wp-content/uploads/2015/03/Cave_of_the_Winds.pdf)

**Access/review:** Relevant passage indexed.

**Use and limits:** Langley ATF support history; explains why NASA does not publish the YF-22/YF-23 tunnel results discussed there. Not a source for a complete public aero database.

<a id="r32"></a>

### R32 — NATO RTO-TR-029 — Flight Control Design: Best Practices

[Source](https://publications.sto.nato.int/publications/STO%20Technical%20Reports/RTO-TR-029/TR-029-%24%24ALL.pdf)

**Access/review:** Indexed; direct retrieval blocked.

**Use and limits:** General control-design/validation methodology referencing F-22 work. Not aircraft-specific control source code.

<a id="r33"></a>

### R33 — National Research Council — Aviation Safety and Pilot Control, 1997

[Source](https://www.nationalacademies.org/read/5469/chapter/11)

**Access/review:** Publisher page reviewed.

**Use and limits:** Workshop provenance identifies YF-22/F-22 pilot-coupling presentations. This linked appendix is a participant list, not those presentations' full texts.

## Sensors, weapons and configuration chronology

<a id="r34"></a>

### R34 — Northrop Grumman AN/APG-77 AESA

[Source](https://www.northropgrumman.com/what-we-do/mission-solutions/radars/an-apg-77-aesa)

**Access/review:** Manufacturer description indexed.

**Use and limits:** System role and broad air/ground capability. Does not justify an exact detection range against every target.

<a id="r35"></a>

### R35 — Northrop Grumman — F-22 SAR demonstration

[Source](https://investor.northropgrumman.com/news-releases/news-release-details/northrop-grumman-completes-successful-demonstration-new)

**Access/review:** Primary announcement indexed; direct retrieval blocked.

**Use and limits:** APG-77(V)1 air-to-ground/SAR development; test-bed demonstration date must be separated from aircraft fleet fielding.

<a id="r36"></a>

### R36 — BAE AN/ALR-94 product page

[Source](https://www.baesystems.com/en-us/product/an-alr-94)

**Access/review:** Primary page reviewed.

**Use and limits:** Integrated warning, passive geolocation, targeting support and countermeasures roles; no complete performance or cockpit format specification.

<a id="r37"></a>

### R37 — BAE F-22 EW sustainment announcement, 2023

[Source](https://www.baesystems.com/en-us/article/bae-systems-to-keep-f-22-raptor-electronic-warfare-mission-systems-ready-and-relevant)

**Access/review:** Primary announcement indexed.

**Use and limits:** Confirms named system and sustainment context; not new symbol geometry.

<a id="r38"></a>

### R38 — Thales ROST-HD/Scorpion development announcement, 20 September 2024

[Source](https://www.thalesdsi.com/2024/09/20/thales-awarded-diu-contract-f22-hmd-interface-dev/)

**Access/review:** Primary page reviewed.

**Use and limits:** F-22-specific HMD integration/testing contract. Does not establish fleet-wide operational availability.

<a id="r39"></a>

### R39 — F-22 Increment 3.2B Selected Acquisition Report, December 2017

[Source](https://www.esd.whs.mil/Portals/54/Documents/FOID/Reading%20Room/Selected_Acquisition_Reports/FY_2017_SARS/18-F-1016_DOC_10_AF_F-22_Inc_32B_Mod_SAR_Dec_2017.pdf)

**Access/review:** Official report indexed.

**Use and limits:** AIM-9X/AIM-120D integration, electronic protection and datalink modernization scope. Plans and delivered configurations differ.

<a id="r40"></a>

### R40 — DOT&E F-22 FY2019 report

[Source](https://www.dote.osd.mil/Portals/97/pub/reports/FY2019/af/2019f22a.pdf)

**Access/review:** Official report indexed.

**Use and limits:** Increment 3.2B-era test/configuration chronology.

<a id="r41"></a>

### R41 — DOT&E F-22 FY2024 report

[Source](https://www.dote.osd.mil/Portals/97/pub/reports/FY2024/af/2024f-22a.pdf)

**Access/review:** Official report indexed; direct retrieval blocked.

**Use and limits:** Later operational-flight-program test status. Public report does not reveal the underlying classified evaluation details.

<a id="r42"></a>

### R42 — DOT&E F-22 FY2025 report

[Source](https://www.dote.osd.mil/Portals/97/pub/reports/FY2025/af/2025f-22a.pdf)

**Access/review:** Official report indexed; direct retrieval blocked.

**Use and limits:** Current public modernization/test overview. Confirm retrieved version before extracting detailed claims.

<a id="r43"></a>

### R43 — USAF/WADS F-22 fact sheet: armament

[Source](https://www.wads.ang.af.mil/About-Us/Fact-Sheets/Article/1175462/f-22-factsheet/)

**Access/review:** Official indexed content.

**Use and limits:** Baseline internal gun/missile/JDAM carriage. Useful for rejecting unsupported loadouts; not every later upgrade is captured.

<a id="r44"></a>

### R44 — USAF/Edwards — first supersonic SDB drop

[Source](https://www.edwards.af.mil/News/Display/Article/396020/f-22-raptor-performs-first-supersonic-sdb-drop/)

**Access/review:** Primary test announcement indexed.

**Use and limits:** GBU-39 separation/integration testing; does not supply a complete bombing solution.

<a id="r45"></a>

### R45 — USAF/ACC — Langley SDB fit test

[Source](https://www.acc.af.mil/News/Article-Display/Article/202995/langley-crew-conducts-fit-test-for-new-weapon/)

**Access/review:** Primary announcement indexed.

**Use and limits:** Stores-fit and carriage development; fit checks alone do not prove operational integration.

<a id="r46"></a>

### R46 — Lockheed Martin Mako product/development announcement, 2024

[Source](https://www.lockheedmartin.com/en-us/news/features/2024/mako-a-hypersonic-missile-thats-more-than-ready.html)

**Access/review:** Primary announcement indexed; direct retrieval blocked.

**Use and limits:** Hypersonic multi-mission missile development; does not validate the mod's custom MAKO air-to-air implementation or its numbers.

<a id="r47"></a>

### R47 — Boeing — integrated F-22 avionics package, 13 December 1999

[Source](https://boeing.mediaroom.com/1999-12-13-Boeing-Delivers-Updated-F-22-Integrated-Avionics-Package)

**Access/review:** Primary announcement indexed.

**Use and limits:** Historical Block 1.2 software and systems integration context.

## Operations, life support and official imagery

<a id="r48"></a>

### R48 — AFMAN 11-2F-22A Volume 3 — Operations Procedures

[Source](https://static.e-publishing.af.mil/production/1/af_a3/publication/afman11-2f-22av3/afman11-2f-22av3.pdf)

**Access/review:** Official indexed record; direct retrieval blocked; version unresolved.

**Use and limits:** Search results expose a 2 July 2026 cover and older 2018 extracts at the same URL. Do not mix editions or cite detailed current procedures until actual PDF retrieval verifies the version.

<a id="r49"></a>

### R49 — AFMAN 11-2F-22A Volume 1 — Aircrew Training, 7 August 2025

[Source](https://static.e-publishing.af.mil/production/1/af_a3/publication/afman11-2f-22av1/afman11-2f-22av1.pdf)

**Access/review:** Official indexed excerpts reviewed; full download blocked.

**Use and limits:** Training and block-differences requirements, including HUD-out training. Not the technical flight manual.

<a id="r50"></a>

### R50 — AFMAN 11-2F-22A Volume 2 — Aircrew Evaluation Criteria, 14 August 2023

[Source](https://static.e-publishing.af.mil/production/1/af_a3/publication/afman11-2f-22av2/afman11-2f-22av2.pdf)

**Access/review:** Official indexed excerpts reviewed; full download blocked.

**Use and limits:** Evaluation tasks and HUD-out emergency-procedure checks; useful for a simulator test plan.

<a id="r51"></a>

### R51 — DoD IG DODIG-2013-041, including 2010 AIB material

[Source](https://www.airandspaceforces.com/SiteCollectionDocuments/Reports/2013/February%202013/Day13/DODIG_F-22_020613.pdf)

**Access/review:** Original report mirror downloaded; relevant pages inspected.

**Use and limits:** CAUT evidence and accident reconstruction. The reconstruction is not literal HUD video. Official URL: https://media.defense.gov/2013/Feb/06/2001712802/-1/-1/1/DODIG-2013-041.pdf

<a id="r52"></a>

### R52 — USAF — automatic backup oxygen installation, 2014

[Source](https://www.af.mil/News/Article-Display/Article/478362/installation-of-backup-oxygen-system-in-f-22-combat-fleet-continues/)

**Access/review:** Primary announcement indexed.

**Use and limits:** ABOS retrofit chronology and life-support context; no full pressure/flow or emergency logic specification.

<a id="r53"></a>

### R53 — USAF — return to normal operations, 2013

[Source](https://www.af.mil/News/Article-Display/Article/109415/f-22-resumes-normal-flight-operations/)

**Access/review:** Primary announcement indexed.

**Use and limits:** Aircrew equipment modifications and operational restriction history; preserve chronology.

<a id="r54"></a>

### R54 — Congressional hearing — F-22 Pilot Physiological Issues, 2012

[Source](https://www.govinfo.gov/content/pkg/CHRG-112hhrg76215/html/CHRG-112hhrg76215.htm)

**Access/review:** Official hearing indexed.

**Use and limits:** Primary testimony for life-support development and corrective actions. Statements must be attributed and dated.

<a id="r55"></a>

### R55 — USAF/DVIDS — F-22 Raptor: Inside the Cockpit, 16 May 2019

[Source](https://www.dvidshub.net/video/681055/f-22-raptor-inside-cockpit)

**Access/review:** Official provenance reviewed; footage not frame-audited in this pass.

**Use and limits:** 2:41 film by Sam Eckholm. Candidate visual material; legibility of HUD symbols must be checked before transcription.

<a id="r56"></a>

### R56 — USAF/DVIDS — Full F-22 Demo, 2020

[Source](https://www.trngcmd.marines.mil/News/Videos/videoid/744272/)

**Access/review:** Official description indexed; footage not frame-audited.

**Use and limits:** Demo cockpit footage, useful for motion/handling observation with unknown camera and aircraft conditions.

<a id="r57"></a>

### R57 — USAF/DVIDS — Cockpit B-Roll, video 992965

[Source](https://www.dvidshub.net/video/992965/f-22-raptor-aerial-demonstration-team-cockpit-b-roll)

**Access/review:** Official provenance reviewed; footage not frame-audited.

**Use and limits:** Page posted January 2026 but description identifies 2023-season flying. Do not label it a 2026 aircraft configuration from upload date.

<a id="r58"></a>

### R58 — USAF/DVIDS — Max Vertical Climb, video 759958

[Source](https://www.acc.af.mil/News/Video/dvpTag/f/dvpmoduleid/20299/videoid/759958/)

**Access/review:** Official description indexed; footage not frame-audited.

**Use and limits:** Additional real-aircraft visual candidate, not a calibrated thrust/weight measurement.

## Simulation implementation and mod ecosystem

<a id="r59"></a>

### R59 — Grinnelli F-22 source

[Source](https://github.com/grinnellidesigns/f-22a)

**Access/review:** Cloned at 8484b44; source inventory and selected deep review.

**Use and limits:** 323 tracked files; open custom EFM/Lua with proprietary DCS avionics dependencies. This is the development baseline, not an aircraft reference.

<a id="r60"></a>

### R60 — B-HOOP Block 40 original developer announcement

[Source](https://www.reddit.com/r/hoggit/comments/1tg5m2y/update_on_f22_mod_for_dcs_world_f22_block_40/)

**Access/review:** Developer post reviewed.

**Use and limits:** Custom avionics/HUD claims and WIP status. Public source/release not verified.

<a id="r61"></a>

### R61 — Nightstorm enhancement thread

[Source](https://forum.dcs.world/topic/252855-f-22a-raptor-mod-enhancement-mod/)

**Access/review:** Author post and final public page reviewed.

**Use and limits:** External addon, separate from public GitHub fork audit. ZIP source not audited.

<a id="r62"></a>

### R62 — Custom Fox-3 guidance compatibility discussion, March 2026

[Source](https://forum.dcs.world/topic/385903-custom-fox-3-missiles-are-now-broken/)

**Access/review:** Contributor reports and both pages reviewed.

**Use and limits:** First-person modder reports, not a confirmed universal root cause or current fix.

<a id="r63"></a>

### R63 — ZedaSoft commercial F-22 simulator

[Source](https://www.zedasoft.com/product/f-22-raptor/)

**Access/review:** Vendor description indexed.

**Use and limits:** Commercial HUD/navigation/weapons plugin claim. No public source or independent aircraft-fidelity validation located.

<a id="r64"></a>

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

<a id="r65"></a>

### R65 — Thrust vector aided maneuvering of the YF-22 Advanced Tactical Fighter prototype — Robert Barham, 1994

[Source](https://doi.org/10.2514/6.1994-2105)

Publisher bibliographic record located; full text not reviewed. Prototype thrust-vectoring development; distinguish YF-22 results from production F-22 behaviour.

<a id="r66"></a>

### R66 — F-22 Aircraft Battery-Charger-Controller System — Thomas Stoneham, 1999

[Source](https://saemobilus.sae.org/papers/f-22-aircraft-battery-charger-controller-system-1999-01-1363)

Publisher abstract reviewed. Describes a 28 V nickel-cadmium battery and a charger-controller powered from 270 VDC. Full paper access not established.

<a id="r67"></a>

### R67 — F-22 ECS/TMS Design Optimization for Reliability and Integrity — James Sprouse, 1996

[Source](https://saemobilus.sae.org/papers/f-22-environmental-control-thermal-management-system-design-optimization-reliability-integrity-a-case-study-961339)

Publisher abstract reviewed; full paper not reviewed. Integrated environmental conditioning/pressurization and thermal-management design assurance.

<a id="r68"></a>

### R68 — Application of MIL-C-87252 in F-22 Liquid Cooling System — Baird and Ferentinos, 1998

[Source](https://saemobilus.sae.org/papers/application-mil-c-87252-f-22-liquid-cooling-system-981543)

Publisher abstract reviewed; full paper not reviewed. Coolant selection, PAO fluid application and ECS/TMS cooling-system lessons.

<a id="r69"></a>

### R69 — F-22 ECS/TMS Flight Test Program: Downloadable Constants — Ashford and Brown, 2000

[Source](https://saemobilus.sae.org/papers/f-22-environmental-control-system-thermal-management-system-ecs-tms-flight-test-program-downloadable-constants-innovative-approach-2000-01-2265)

Publisher abstract reviewed; full paper not reviewed. Parameterized ECS software tuning during flight testing; not a source for the actual constant values.

<a id="r70"></a>

### R70 — Development of an Integrated Environmental Control System, 1998

[Source](https://saemobilus.sae.org/papers/development-integrated-environmental-control-system-981544)

Publisher indexed abstract reviewed. F-22 ECS/TMS development challenges and lessons; full paper not reviewed.

<a id="r71"></a>

### R71 — F-22 ECS/TMS Qualification Test Program Overview — Sprouse, 1997

[Source](https://saemobilus.sae.org/papers/f-22-ecs-tms-qualification-test-program-overview-972261)

Publisher bibliographic record located. Qualification-test reference; detailed contents not reviewed.

<a id="r72"></a>

### R72 — Vapor Cycle System for the F-22 Raptor, 2000

[Source](https://saemobilus.sae.org/papers/vapor-cycle-system-f-22-raptor-2000-01-2268)

Publisher indexed abstract reviewed. Functional description of the refrigeration pack and compressor; full paper not reviewed.

<a id="r73"></a>

### R73 — F-22 Avionic Test and Evaluation Standard File Format, 1997

[Source](https://www.sfte.org/technical_library_-_sensors_an.php)

SFTE primary catalogue lists the paper; article link requires member login. Detailed contents not reviewed.

<a id="r74"></a>

### R74 — Instrumenting the Prototype Fighter: The YF-22A Story, 1994

[Source](https://www.sfte.org/technical_library_-_sensors_an.php)

SFTE primary catalogue lists the paper; article link requires member login. Prototype test-instrumentation reference, not an operational avionics manual.

<a id="r75"></a>

### R75 — Boeing: First F-22 Avionics Software, 30 November 1998

[Source](https://boeing.mediaroom.com/1998-11-30-Boeing-Delivers-First-F-22-Avionics-Software)

Primary announcement reviewed. Early flight-test-bed software and cockpit/display integration chronology.

<a id="r76"></a>

### R76 — Boeing: F-22 Avionics Software Block 3.0, 27 November 2000

[Source](https://boeing.mediaroom.com/2000-11-27-Boeing-Delivers-F-22-Avionics-Software)

Primary announcement reviewed. Historical sensor-fusion and weapons-delivery development. This early Block 3.0 naming is distinct from later operational increments.

<a id="r77"></a>

### R77 — Boeing: F-22 Integrated Avionics Software Block 3.1, 6 February 2002

[Source](https://boeing.mediaroom.com/2002-02-06-Boeing-Delivers-F-22-Integrated-Avionics-Software)

Primary announcement reviewed. Radar/EW/CNI/GPS integration chronology; preserve the 2002 date and development context.

<a id="r78"></a>

### R78 — Boeing: Updated F-22 Avionics Software, 26 October 1999

[Source](https://boeing.mediaroom.com/1999-10-26-Boeing-Delivers-Updated-F-22-Avionics-Software)

Primary announcement indexed. EW/CNI and missile-launch-detector test development; full detailed technical implementation not published here.

<a id="r79"></a>

### R79 — Origins of the F-22 Raptor — Albert Piccirillo, 1998

[Source](https://saemobilus.sae.org/papers/origins-f-22-raptor-985566)

Publisher record and indexed abstract reviewed. Aircraft development provenance; full paper not reviewed.

<a id="r80"></a>

### R80 — Lockheed Martin: F-22 Infrared Defensive System integration, 22 January 2025

[Source](https://news.lockheedmartin.com/2025-01-22-Lockheed-Martin-to-Modernize-Air-Force-F-22-Raptor-with-Advanced-Infrared-Threat-Detection-Sensors)

Primary announcement reviewed. Distributed embedded TacIRST sensors/IRDS integration contract; not proof of fleet-wide completion or evidence for the mod external pod implementation.


## Further research: propulsion, actuation and stored energy

<a id="r81"></a>

### R81 — Development of the F-22 Propulsion System, AIAA 2002-3624

[Source](https://doi.org/10.2514/6.2002-3624)

Original propulsion-development paper located through publisher records. [Accessible original-paper transcription](https://www.academia.edu/16966139/Development_of_the_F_22_Propulsion_System) reviewed in this pass; figures not independently inspected. Deskin and Yankel describe EMD propulsion development, verification and test accomplishments. This is not a complete installed engine deck.

<a id="r82"></a>

### R82 — F-22 Actuator Dynamic Stiffness (Impedance) Testing, AIAA 2007-1792

[Source](https://doi.org/10.2514/6.2007-1792)

Bibliographic lead cross-checked against an author/publication record. Full paper not reviewed. Potential source for actuator/aeroelastic validation, with no numerical actuator model inferred here.

<a id="r83"></a>

### R83 — Curtiss-Wright: F-22 main and side weapons-bay door drives

[Source](https://actuation.curtisswright.com/en-gb/aerospace-products/actuation-systems)

Manufacturer page reviewed. Identifies F-22 bay-door drive systems among its applications; does not publish precise operating timings or control laws.

<a id="r84"></a>

### R84 — PCI Gases: Stored Energy System Servicing Cart

[Source](https://www.pcigases.com/aerospace-and-defense/products/sessc/)

Manufacturer page reviewed. Identifies F-22 stored-energy servicing and published cart characteristics. Cart pressure is not automatically the operating pressure of every onboard subsystem.

<a id="r85"></a>

### R85 — F-22 Environmental Control/Thermal Management Fluid Transport Optimization, SAE 2000-01-2266

[Source](https://www.researchgate.net/publication/296643928_F-22_Environmental_ControlThermal_Management_Fluid_Transport_Optimization)

Author/publication abstract and DOI located; full text not reviewed. Describes fluid transport and heat rejection to fuel/ram air; distinguish this from the separate downloadable-constants paper 2000-01-2265.

## DCS implementation study references

<a id="r86"></a>

### R86 — IGServal: DCS Basic EFM Template

[Source](https://github.com/IGServal/DCS-Basic-EFM-Template)

Repository README and MIT licence reviewed. An enhanced template derived from the Eagle Dynamics API example, with examples of force calculations, controls, fuel, damage and Lua parameter exchange. Useful for understanding the origins and structure of this mod's EFM. Its example aircraft model is not F-22 performance evidence.

<a id="r87"></a>

### R87 — Community A-4E: public implementation repository

[Source](https://github.com/Community-A-4E/community-a4e-c)

Repository README reviewed. A mature community implementation to study for EFM, cockpit and subsystem architecture. Its README explicitly prohibits redistribution without permission; public visibility does not establish permission to copy its code or assets into this project. Use as a reading reference and review the applicable terms before any reuse. It is not an F-22 accuracy source.

## Focused expansion: avionics, HUD and flight performance

Added 24 October 2026. These 60 entries include F-22-specific sources, prototype material, supporting engineering research and explicitly limited bibliographic leads. Read the access status before using any entry as implementation evidence.

## HUD, cockpit, HMD and display engineering — expanded references

<a id="r88"></a>

### R88 — BAE Systems — Digital Light Engine HUD product page and datasheet

[Source](https://www.baesystems.com/en-us/product/digital-light-engine-headup-display-hud)

[Manufacturer datasheet](https://www.baesystems.com/dam/jcr:d0c32fed-51e5-40fc-96ef-40c794a15a18/18-C41-02-DLE-HUD-datasheet-US-2025-w.pdf)

**Access/review:** Manufacturer product page and two-page datasheet retrieved and reviewed.

**Study use:** Current page explicitly lists F-22 use and describes form/fit/function digital replacement, night-vision compatibility and added image-source capability.

**Limits:** Generic datasheet field of view/resolution is not automatically the F-22 optical specification. Added projector capability does not establish changed mission-software symbology; pair with R04/R05.

<a id="r89"></a>

### R89 — Thales — Scorpion HMD capability sheet, retrieved revision 052026:V1

[Source](https://www.thalesdsi.com/wp-content/uploads/2024/08/Thales_Scorpion_Capabilities_Sheet.pdf)

[Manufacturer product page](https://www.thalesdsi.com/scorpion/)

**Access/review:** Four-page manufacturer PDF retrieved and relevant capabilities reviewed. Footer identifies May 2026 revision despite the /2024/08/ URL directory.

**Study use:** Full-colour conformal symbology, HObIT tracking, NVG use and modular integration background for R38's F-22 ROST-HD effort.

**Limits:** Generic Scorpion capabilities and brochure graphics do not define the F-22-specific HMD symbology or prove fleet-wide installation.

<a id="r90"></a>

### R90 — Hoh, Arencibia and Hislop — Development and Flight-Test of a Commercial Head-Up Display

[Source](https://hoh-aero.com/HUD/SETP_HUD_Paper.pdf)

**Access/review:** Accessible 21-page author-hosted paper; introduction and display/flight-test discussion reviewed.

**Study use:** Engineering background for conformal guidance, flight-path presentation, testing and differences between military and transport HUD requirements.

**Limits:** Commercial HUD study, not an F-22 mode/symbol specification.

<a id="r91"></a>

### R91 — Newman and the Tri-Service Flight Symbology Working Group — TRISTAR I, NASA TM-4665, February 1995

[Source](https://ntrs.nasa.gov/citations/19950017610)

[Full PDF](https://ntrs.nasa.gov/api/citations/19950017610/downloads/19950017610.pdf)

**Access/review:** 108-page NASA PDF retrieved; contents, experimental setup and relevant symbology sections reviewed.

**Study use:** Climb-dive marker/ladder alternatives, fixed/moving scales, quickening and caging equations; evaluates tracking, ILS and unusual-attitude tasks.

**Limits:** The simulator used an AV-8B mathematical model and generic fast-jet symbol alternatives. These equations are study/validation material, not confirmed F-22 drive laws.

<a id="r92"></a>

### R92 — Richard L. Newman — Improvement of Head-Up Display Standards, Volume I: Head-Up Display Design Guide, 1987

[Source](https://www.researchgate.net/publication/235122557_Improvement_of_Head-Up_Display_Standards_Volume_1_Head-Up_Display_Design_Guide_Appendix)

[Report copy](https://citeseerx.ist.psu.edu/document?doi=f388514f087746a413e17d309547d31928eeae85&repid=rep1&type=pdf)

**Access/review:** Author-uploaded publication abstract and indexed report cover reviewed; original full guide not reviewed.

**Study use:** AFWAL-TR-87-3055 Volume I: display, symbology, operational and primary-flight-reference design criteria.

**Limits:** Predates the F-22 cockpit. Suitable for evaluating HUD behaviour, not for claiming a particular Raptor symbol or mode.

<a id="r93"></a>

### R93 — FAA/Volpe — Issues and Knowledge Concerning the Use of Head-Up Displays in Air Transports, June 2003

[Source](https://rosap.ntl.bts.gov/view/dot/8746/dot_8746_DS1.pdf)

**Access/review:** 80-page DOT/FAA/AR-03/50 report retrieved; cover, executive summary and relevant conformality/clutter discussion reviewed.

**Study use:** HUD information placement, readability, attention trapping, conformal flight-path markers and eye-position constraints.

**Limits:** Transport-oriented human-factors evidence. It does not identify the F-22's display layout.

<a id="r94"></a>

### R94 — Prinzel and Risser — Head-Up Displays and Attention Capture, NASA/TM-2004-213000

[Source](https://ntrs.nasa.gov/api/citations/20040065771/downloads/20040065771.pdf)

**Access/review:** Corrected 37-page NASA report retrieved; HUD standardization and attention-capture sections reviewed.

**Study use:** Explains why HUD workload, clutter, scan behaviour and dynamics require evaluation beyond drawing the right symbols.

**Limits:** General human-factors synthesis; no F-22 symbol dictionary or operational procedures.

<a id="r95"></a>

### R95 — ONERA/DGAC — Head Up Displays symbology: a pre-normative study, June 2002

[Source](https://www.ecologie.gouv.fr/sites/default/files/documents/head_up_display_symbology.pdf)

**Access/review:** 84-page government-hosted report retrieved; relevant contents and research bibliography reviewed.

**Study use:** Extensive HUD symbology literature trail, including USAF control/performance standardization, attitude presentation and flight-guidance concepts.

**Limits:** Pre-normative civil-aviation research. Its bibliography is a source-discovery aid; cited papers are not automatically reviewed or aircraft-specific.

<a id="r96"></a>

### R96 — Hansen, Wood and Hartman — Aircraft head up display system, US6567014B1, 2003

[Source](https://patents.google.com/patent/US6567014B1/en)

**Access/review:** Published patent text and bibliographic record reviewed.

**Study use:** Original disclosure of normal/unusual-attitude display strategies, pitch/roll presentation and mode transitions.

**Limits:** No F-22 identification found in the text. A patent demonstrates a disclosed concept, not installation on a particular aircraft.

<a id="r97"></a>

### R97 — Eric Hehs — Cockpit Photo Collection, Code One Magazine

[Source](https://www.codeonemagazine.com/article.html?item_id=27)

**Access/review:** Manufacturer magazine article and F-22 image caption reviewed; linked original-resolution image remains a visual-study lead.

**Study use:** Cockpit geometry, display placement and hardware arrangement with named cockpit-design contributors.

**Limits:** Caption identifies a cockpit before ejection-seat installation. Static photographs do not establish active symbology or operational configuration.

<a id="r98"></a>

### R98 — BAE Systems — A World of Firsts: passive and active inceptors, 31 May 2015

[Source](https://www.baesystems.com/en/story/a-world-of-firsts)

**Access/review:** Manufacturer article full text reviewed.

**Study use:** Explicitly identifies the F-22 as using a passive inceptor and explains passive spring/damper feel versus active tactile feedback.

**Limits:** Input-device mechanics reference. Does not publish F-22 force/displacement curves or flight-control command gains.

<a id="r99"></a>

### R99 — Weinstein, Gillingham and Ercoline — USAF head-up display control and performance symbology evaluations, 1994

[Source](https://pubmed.ncbi.nlm.nih.gov/8018075/)

Aviation, Space, and Environmental Medicine 65(5 Suppl), A20–A30. Related 1993 Armstrong Laboratory standardization report is cited by R02.

**Access/review:** Original research abstract and citation indexed in PubMed reviewed; full article not reviewed.

**Study use:** Empirical basis for counter-pointer airspeed/altitude, asymmetric climb/dive ladders, ghost horizon, vertical velocity, energy-management cues and quickening.

**Limits:** USAF standardization research explains design rationale; it does not prove every proposed feature appears in every F-22 software mode.

<a id="r100"></a>

### R100 — Bailey and Landers — VISTA NF-16D programmable display system development, SPIE 3362, 1998

[Source](https://doi.org/10.1117/12.317428)

[Author-uploaded text/report](https://www.researchgate.net/publication/235091759_VISTA_NF-16D_programmable_display_system_development)

**Access/review:** Author-uploaded abstract and relevant original text reviewed; full figures not inspected.

**Study use:** Programmable HUD/HMD research platform using GEC F-22 display-development technology; useful for display dynamics and pilot-interface prototyping.

**Limits:** VISTA hardware/symbology is not an operational F-22 cockpit. Uploaded record mixes report and SPIE metadata; preserve their separate cover details.

## Avionics, radar, navigation and integration — expanded references

<a id="r101"></a>

### R101 — J. A. Malas — F-22 radar development, IEEE NAECON 1997

[Source](https://ieeexplore.ieee.org/document/622737/)

DOI: 10.1109/NAECON.1997.622737.

**Access/review:** Publisher indexed abstract reviewed; full-text retrieval blocked by verification page.

**Study use:** Original APG-77 systems-engineering paper covering radar hardware/software architecture, array technology and integration with the F-22 avionics concept.

**Limits:** The abstract supports architecture and design goals, not exact operational detection ranges, scan schedules or radar display formats.

<a id="r102"></a>

### R102 — Boeing — Begins Integrating F-22 Fighter's Advanced Avionics, 29 January 1998

[Source](https://boeing.mediaroom.com/1998-01-29-Boeing-Begins-Integrating-F-22-Fighters-Advanced-Avionics)

**Access/review:** Manufacturer announcement full text reviewed.

**Study use:** Names mission management, sensor control/tasking, track fusion, fire control, navigation, displays and flight-path management, with pilot-in-loop and closed-loop lab integration.

**Limits:** An EMD integration architecture reference, not a current software interface or a complete sensor-fusion algorithm.

<a id="r103"></a>

### R103 — Boeing — Avionics Help Guide F-22 Missile to Its Target, 24 September 2001

[Source](https://boeing.mediaroom.com/2001-09-24-Boeing-Avionics-Help-Guide-F-22-Missile-to-Its-Target)

**Access/review:** Manufacturer announcement full text reviewed.

**Study use:** Primary account linking a guided AMRAAM test to Block 3.0 avionics, target tracking and multisensor fusion.

**Limits:** A demonstrated test event does not publish radar range, engagement-zone equations or every later weapons-software configuration.

<a id="r104"></a>

### R104 — Northrop Grumman — F-22 CNI contracts and subsystem description, 23 April 2008

[Source](https://investor.northropgrumman.com/news-releases/news-release-details/northrop-grumman-receives-contracts-totaling-252-million-f-22)

**Access/review:** Manufacturer announcement reviewed.

**Study use:** Identifies 14 integrated CNI functions and software-defined radio architecture supporting voice, data links, navigation and identification.

**Limits:** No message formats, frequencies, emissions schedules or cockpit button mappings are disclosed.

<a id="r105"></a>

### R105 — Volk, Lincoln and Tazartes — Northrop Grumman's Family of Fiberoptic based Inertial Navigation Systems, PLANS 2006

[Source](https://www.ion.org/publications/abstract.cfm?articleID=6621)

DOI: 10.1109/PLANS.2006.1650627.

**Access/review:** Original ION publication abstract and citation reviewed; full paper requires access/download credit.

**Study use:** Manufacturer-authored LN-251/LN-260 family discussion: fibre-optic gyros, GPS integration, velocity noise and transfer alignment.

**Limits:** A navigator-family reference. Establish the installed F-22 variant independently before applying any specification; family-wide results are not automatic F-22 accuracy claims.

<a id="r106"></a>

### R106 — Northrop Grumman — LN-251 INS/GPS datasheet

[Source](https://cdn.northropgrumman.com/-/media/wp-content/uploads/ln-251-inertial-navigation-system-global-positioning-system-datasheet.pdf)

**Access/review:** Official indexed datasheet text reviewed; direct PDF retrieval unavailable.

**Study use:** Candidate component specifications for free-inertial versus GPS-aided navigation, environmental conditions and interfaces.

**Limits:** Verify PDF revision and aircraft installation before assigning drift or alignment characteristics to a simulated F-22.

<a id="r107"></a>

### R107 — Northrop Grumman — Resilient airborne navigation / EGI-M first production unit, 17 April 2026

[Source](https://news.northropgrumman.com/navigation-systems/northrop-grumman-delivers-resilient-airborne-navigation-system-resistant-to-gps-jamming)

**Access/review:** Primary dated announcement indexed; direct page returned 403.

**Study use:** Current navigation-modernization lead for EGI-M and operation in GPS-contested conditions.

**Limits:** Delivery of a first production unit is not evidence that every F-22 has been retrofitted. Verify the aircraft-specific installation state before choosing a mod baseline.

<a id="r108"></a>

### R108 — Lockheed Martin — Project Hydra fifth-generation communications demonstration, 3 May 2021

[Source](https://news.lockheedmartin.com/lockheed-martin-skunk-work-project-hydra-demonstrates-5th-gen-to-5th-gen-communications-across-domains)

**Access/review:** Manufacturer full announcement reviewed.

**Study use:** F-22 IFDL, F-35 MADL and U-2 gateway test; target information reached fighter avionics and pilot displays.

**Limits:** Gateway-enabled exchange is distinct from a native direct link between unlike aircraft. A demonstration does not establish fleet-wide installation.

<a id="r109"></a>

### R109 — USAF ACC Federal Laboratory — Combat apps on an F-22 using an open software stack, August 2022

[Source](https://www.acc.af.mil/News/Article/3143143/acc-federal-laboratory-flies-combat-apps-on-f-22-with-new-open-software-stack/)

[USAF republication](https://www.af.mil/News/Features/Article/3146566/acc-federal-laboratory-flies-combat-apps-on-f-22-with-new-open-software-stack/)

**Access/review:** Official indexed article reviewed; direct ACC page returned 403.

**Study use:** Primary account of third-party software and an open systems enclave in an F-22 flight test.

**Limits:** Modern software-integration architecture, not release of the mission computer's code or permission to assume every experimental app is operational.

<a id="r110"></a>

### R110 — Pamela A. Kowal-Swartout — Software Integration Options for the F-22 and F-35 Major Defense Acquisition Programs, June 2023

[Source](https://dair.nps.edu/bitstream/123456789/5008/1/NPS-AM-23-236.pdf)

**Access/review:** Official NPS-AM-23-236 PDF retrieved; cover, abstract and relevant software-integration discussion reviewed.

**Study use:** Focused research lead for avionics software integration constraints and upgrade options.

**Limits:** An acquisition/software-integration thesis, not source code, current mission-system behaviour or an operational avionics manual.

<a id="r111"></a>

### R111 — Defense Science Board — Tactical Air Warfare, November 1993, ADA275347

[Source](https://www.govinfo.gov/content/pkg/GOVPUB-D-PURL-LPS61208/pdf/GOVPUB-D-PURL-LPS61208.pdf)

**Access/review:** Officially hosted 91-page report retrieved; cover and F-22 risk-assessment sections reviewed.

**Study use:** Public-release record of integration risk, early engine/drag/weight trade-offs and the purpose of avionics flying testbeds. F-22 technical discussion is around PDF pp. 63–67.

**Limits:** A contemporary development assessment, not evidence that early deficiencies survived into production. Do not confuse it with the separate 1994 F-22 concurrency report.

<a id="r112"></a>

### R112 — Thedens — Modular Avionics: Taking Today's Aircraft into Tomorrow, SAE 931416, 1993

[Source](https://saemobilus.sae.org/papers/modular-avionics-taking-todays-aircraft-tomorrow-931416)

**Access/review:** Publisher abstract and metadata reviewed; full paper not reviewed.

**Study use:** Contemporary modular-avionics standards and life-cycle trade-offs naming the F-22 ATF programme.

**Limits:** Architecture background rather than detailed F-22 sensor or display behaviour.

<a id="r113"></a>

### R113 — Tracy Markie — JIAWG Compatible Development Boards for the i960, SAE 931596, 1993

[Source](https://saemobilus.sae.org/papers/jiawg-compatible-development-boards-i960-931596)

**Access/review:** Publisher abstract reviewed; full paper not reviewed.

**Study use:** Contemporary record of JIAWG commonality/interoperability requirements and i960MX processor selection for F-22/RAH-66.

**Limits:** Historical hardware architecture; do not infer current CPU fit or operational mission-software behaviour from a development-board paper.

<a id="r114"></a>

### R114 — Gaska, Watkin and Chen — Integrated modular avionics: Past, present, and future, IEEE, 2015

[Source](https://researchconnect.suny.edu/en/publications/integrated-modular-avionics-past-present-and-future/)

DOI: 10.1109/MAES.2015.150014.

**Access/review:** Author-institution abstract and publication record reviewed; full paper not reviewed.

**Study use:** Research review connecting F-22 JIAWG origins to later modular avionics and hardware/software partitioning.

**Limits:** Broader architectural history. Later ARINC 653 examples are not proof the F-22 uses the same implementation.

<a id="r115"></a>

### R115 — Boeing — Talon HATE airborne networking demonstration, 8 May 2017

[Source](https://boeing.mediaroom.com/2017-05-08-Boeing-Demonstrates-Airborne-Networking-System)

**Access/review:** Manufacturer announcement indexed text reviewed.

**Study use:** Demonstrated information exchange involving F-15C pods, F-22 intra-flight datalink capability, Link 16 and other network paths.

**Limits:** Records a pod/gateway test architecture; not native unrestricted Link 16 transmission by every F-22.

<a id="r116"></a>

### R116 — Lockheed Martin — Supersonic high-altitude JDAM test and Launch Acceptability Region, 12 June 2006

[Source](https://news.lockheedmartin.com/2006-06-12-F-22-Raptor-Scores-Direct-Hit-in-Testing-of-Supersonic-High-Altitude-JDAM-Drop)

**Access/review:** Manufacturer full announcement reviewed.

**Study use:** Explains displayed LAR computation using navigation, weather, target and weapon information, with pilot feedback in the development simulator.

**Limits:** Confirms display function and integration approach, not the released LAR algorithm, display geometry or complete JDAM envelope.

<a id="r117"></a>

### R117 — Air Force Test Center — F-22 Line in the Sky Auto GCAS mission, 18 July 2013

[Source](https://www.aftc.af.mil/News/On-This-Day-in-Test-History/Article-Display-Test-History/Article/2225358/july-18-2013-sky-automatic-ground-collision-avoidance-system/)

**Access/review:** Official historical article text reviewed; published 18 July 2020 about a 2013 test.

**Study use:** Primary history of F-22 collision-avoidance testing and relationships between navigation, terrain data, predicted performance and autonomous intervention.

**Limits:** The article includes programme-wide explanations. Its 2013 test date and generic recovery description do not establish a current F-22 operational control law or fielding date.

<a id="r118"></a>

### R118 — USAF — F-35s begin Auto GCAS test flights, 15 November 2018

[Source](https://www.acc.af.mil/News/Article/1692384/f-35s-begin-auto-gcas-test-flights/)

**Access/review:** Official indexed text reviewed.

**Study use:** Contemporary test-team statement referring to prior F-16/F-22 Auto GCAS work; useful cross-check of development chronology.

**Limits:** The article concerns F-35 testing. Do not turn a cross-programme statement into an F-22 symbol, fleet installation count or recovery-envelope specification.

<a id="r119"></a>

### R119 — Defense Science Board — Concurrency and Risk of the F-22 Program, 1994 interim / 1995 final report family

[Source](https://stib.cto.mil/products-dsb/)

[Indexed 1995 PDF lead](https://dsb.cto.mil/wp-content/uploads/2025/10/95-3_CONCURRENCY-AND-RISK-OF-THE-F-22-PROGRAM.pdf); [indexed 1994 interim lead](https://dsb.cto.mil/wp-content/uploads/2025/10/94-15_Concurrency-and-Risk-of-the-F-22-Program.pdf).

**Access/review:** Official catalogue and indexed covers/passages reviewed; both old PDF URLs returned 404 in direct retrieval.

**Study use:** Early sensor-control/fusion/pilot-interface integration risk and passive-sensor development context.

**Limits:** The current catalogue gives ADA301209 for both entries. Resolve edition/cover before attributing detailed findings; grouped here rather than inflating the count with two unresolved editions.

<a id="r120"></a>

### R120 — USAF Sustainment Center Software Directorate — Manned-Unmanned Teaming innovation / GRACE, 2026

[Source](https://www.wpafb.af.mil/News/Article-Display/Article/4418831/air-force-sustainment-center-software-directorate-demonstrates-manned-unmanned/)

**Access/review:** Official indexed article reviewed; direct page retrieval unsuccessful.

**Study use:** Government Reference Architecture Compute Environment, modular software and F-22-related teaming test context.

**Limits:** Experimental integration and preparation for future deployments are distinct from fleet fielding. Not a current F-22 tablet/HUD operating manual.

<a id="r121"></a>

### R121 — Kenneth A. Seeling — Reconfiguration in an integrated avionics design, IEEE DASC, 1996

[Source](https://ieeexplore.ieee.org/document/559202/)

DOI: 10.1109/DASC.1996.559202. [Publisher PDF lead](https://ieeexplore.ieee.org/iel3/4139/12182/00559202.pdf).

**Access/review:** Original publisher indexed abstract/title reviewed; full-text access blocked by verification page.

**Study use:** Direct F-22 core-processing paper on fault tolerance, failure detection, recovery/reconfiguration and return to operation.

**Limits:** One of the strongest architecture leads for degraded-avionics behaviour; exact timings and current implementation require the full paper and era checks.

<a id="r122"></a>

### R122 — Monaghan and colleagues — The advanced avionics subsystem technology demonstration program, IEEE DASC, 1994

[Source](https://ieeexplore.ieee.org/document/369451/)

[NASA bibliographic listing of related AGARD rendition](https://ntrs.nasa.gov/api/citations/19950021122/downloads/19950021122.pdf)

**Access/review:** Original publisher indexed abstract and NASA bibliographic entry reviewed; full original article not reviewed.

**Study use:** AAST fault-tolerance demonstration and validation of the F-22 Common Integrated Processor architecture.

**Limits:** Technology-demonstration/validation work, not a released operational mission computer. Related conference renditions should be grouped.

<a id="r123"></a>

### R123 — Thomas H. Robinson and Edward Trujillo — Advanced real time integrated processors, IEEE PLANS, 1992

[Source](https://ieeexplore.ieee.org/document/185837/)

[Publisher PDF lead](https://ieeexplore.ieee.org/iel2/610/4750/00185837.pdf)

**Access/review:** Publisher indexed abstract and author/title text reviewed; full original paper not reviewed.

**Study use:** Hughes Modular Processor development from the F-22 ATF, combining sensor, fusion and mission-processing requirements.

**Limits:** Historical architecture reference; do not treat its processor performance or configuration as the current aircraft fit.

<a id="r124"></a>

### R124 — Advanced avionics architecture-support challenges for the 21st century, IEEE

[Source](https://ieeexplore.ieee.org/iel2/502/5046/00197532.pdf)

**Access/review:** Original publisher indexed title and F-22/JIAWG passages located; full paper and complete bibliographic details not verified.

**Study use:** Further primary-paper retrieval lead for integrated-avionics architecture and supportability.

**Limits:** Title/index-only status. Confirm authors, publication date and full text before making implementation claims.

## Flight controls, thrust vectoring and performance — expanded references

<a id="r125"></a>

### R125 — Randy Gordon — F-22 Flight Controls, MIT OpenCourseWare

[Source](https://ocw.mit.edu/courses/16-687-private-pilot-ground-school-january-iap-2019/resources/special-lecture-f-22-flight-controls/)

[Lecture slides](https://ocw.mit.edu/courses/16-687-private-pilot-ground-school-january-iap-2019/47ccc87f2f60e12f3ed22e7f0d176d6a_MIT16_687IAP19_LecF-22.pdf)

**Access/review:** MIT course record and seven-page slide PDF reviewed; cockpit/synoptic and control-mode slide images inspected. Full lecture video not reviewed in this pass.

**Study use:** First-person test-pilot teaching material on pilot-command concepts, limiters, landing and air-refuelling modes, plus cockpit/synoptic illustrations.

**Limits:** The course is IAP 2019; the slide image carries 1/30/20. Record both rather than silently treating them as one date. Teaching slides are not executable control laws or a current flight manual.

<a id="r126"></a>

### R126 — W. H. Mason — High-Angle-of-Attack Aerodynamics, Virginia Tech

[Source](https://archive.aoe.vt.edu/mason/Mason_f/ConfigAeroHiAlphaNotes.pdf)

[Updated textbook chapter](https://pressbooks.lib.vt.edu/configurationaerodynamics/chapter/high-angle-of-attack-aerodynamics/)

**Access/review:** Accessible 17-page 2006 notes and relevant textbook text reviewed.

**Study use:** F-22 case study with Lockheed-supplied pitching-moment and lateral/directional illustrations; original notes pp. 9-11–9-13. Connects forebody, tails, leading-edge flaps and thrust vectoring to departure resistance.

**Limits:** Several F-22 plots intentionally omit numerical scales. They establish qualitative trends, not coefficient tables; the newer chapter includes YF-22-labelled material that must retain its prototype provenance.

<a id="r127"></a>

### R127 — Clifton, Ratcliff, Bodkin and Dean — Determining the Stability and Control Characteristics of High-Performance Maneuvering Aircraft Using High-Resolution CFD Simulation with and without Moving Control Surfaces, 2013

[Source](https://www.cobaltcfd.com/pdfs/AIAA_2013_ratcliff.pdf)

**Access/review:** Accessible 20-page author paper; relevant F-22 methodology and validation text reviewed.

**Study use:** USAF SEEK EAGLE work covering F-22 clean/external-tank cases, static/dynamic aerodynamics, system identification and comparisons with ATLAS/AVTEST data.

**Limits:** Most comparisons deliberately use unscaled or relative-error plots because underlying data were not released. They cannot be digitized into absolute F-22 coefficients; distinguish simulated J-turns from actual flight data.

<a id="r128"></a>

### R128 — Joseph R. Chambers — Partners in Freedom, NASA/SP-2000-4519

[Source](https://ntrs.nasa.gov/citations/20000115606)

[NASA PDF](https://ntrs.nasa.gov/api/citations/20000115606/downloads/20000115606.pdf)

**Access/review:** NASA record and complete PDF retrieved; relevant F-22 chapter text reviewed, printed pp. 159–165 (PDF pp. 172–178).

**Study use:** Langley contributions to F-22 nozzle/afterbody integration, high-alpha research and supersonic drag validation; locate printed p. 159 and surrounding aircraft discussion.

**Limits:** A 2000 historical publication; its early specification box is not a current production weight/performance specification.

<a id="r129"></a>

### R129 — Jeffrey W. Hamstra and Brent N. McCallum — Tactical Aircraft Aerodynamic Integration, 2010

[Source](https://onlinelibrary.wiley.com/doi/full/10.1002/9780470686652.eae490)

**Access/review:** Publisher full-text F-22 sections 6.1.1–6.1.2 reviewed.

**Study use:** Direct propulsion-integration engineering: fixed caret inlets, boundary-layer management, obscured ducts and two-dimensional convergent-divergent vectoring nozzles.

**Limits:** The authors explicitly distinguish studied thrust reversal from the production configuration. No complete inlet-recovery map or installed engine deck is provided.

<a id="r130"></a>

### R130 — Clark and Bernens — High Angle-of-Attack Flight Characteristics of the YF-22, AIAA 91-3194

[Source](https://archive.aoe.vt.edu/mason/Mason/ACiYF22.23.html)

**Access/review:** Bibliographic lead cross-checked in Virginia Tech's aircraft bibliography and high-alpha notes; full original paper not reviewed.

**Study use:** Original prototype high-alpha flight-test paper to obtain for handling, departure resistance and thrust-vectoring development.

**Limits:** YF-22 evidence, not production F-22 calibration. Use the exact title and paper number when requesting institutional access.

<a id="r131"></a>

### R131 — AFMAN 11-246 Volume 1 — Air Force Aircraft Demonstrations, 18 March 2022

[Source](https://static.e-publishing.af.mil/production/1/af_a3/publication/afman11-246v1/afman11-246.pdf)

**Access/review:** Official 176-page PDF retrieved; F-22 chapter and selected parameter tables reviewed.

**Study use:** Chapter 5, printed pp. 108–134: aircraft configuration/fuel requirements, density-altitude adjustments and parameter tables for high-alpha, pedal-turn, power-loop, loaded-roll, tail-slide and slow-speed demonstrations.

**Limits:** Demonstration target values and safety boundaries describe particular manoeuvres/configurations. They are not an energy-manoeuvrability chart or the aircraft's entire structural/operating envelope.

<a id="r132"></a>

### R132 — Daniel Ikaza, ITP — Thrust Vectoring Nozzle for Military Aircraft Engines, ICAS 2000

[Source](https://www.icas.org/icas_archive/ICAS2000/PAPERS/RESERVED/ICA0534.PDF)

**Access/review:** Ten-page manufacturer-authored paper accessible; relevant nozzle/control discussion reviewed.

**Study use:** Clear explanation of throat versus exit area, vector direction, trim benefits and nozzle/engine/control integration.

**Limits:** The actual design studied is ITP's three-dimensional nozzle, not the F119's two-dimensional nozzle. Use for mechanics and integration concepts, not F-22-specific performance constants.

<a id="r133"></a>

### R133 — Vinayagam and Sinha — An assessment of thrust vector concepts for twin-engine airplane, 2014

[Source](https://journals.sagepub.com/doi/10.1177/0954410013485697)

[Author publication record/full-text candidate](https://www.researchgate.net/publication/269920219_An_assessment_of_thrust_vector_concepts_for_twin-engine_airplane)

**Access/review:** Publisher abstract/indexed findings reviewed; full paper not reviewed.

**Study use:** Research comparison of pitch-only and multi-axis vectoring, including roll/yaw authority and nonlinear control allocation.

**Limits:** Simulations use an F-18/HARV model. This is a useful countercheck against assuming every thrust-vectoring aircraft has three-axis nozzles; it does not identify the F-22's actual allocation schedule.

<a id="r134"></a>

### R134 — NASA/TM-2005-213978 — Propulsion Control Technology Development in the United States: A Historical Perspective

[Source](https://ntrs.nasa.gov/api/citations/20050238468/downloads/20050238468.pdf)

**Access/review:** 27-page NASA report accessible; F119 control-history table and relevant discussion reviewed.

**Study use:** F119 dual-channel FADEC, two-dimensional vectoring, self-tuning onboard model and analytical sensor redundancy. See Table 8.4, printed p. 18.

**Limits:** The chronology groups the prototype-era 1990 flight with the F119 family. It is not a production FADEC software specification or a thrust-response map.

<a id="r135"></a>

### R135 — NASA — F-15 Flight Research Facility / HIDEC, FS-2000-02-022-DFRC

[Source](https://www.nasa.gov/wp-content/uploads/2023/06/fs-2000-02-022-dfrc.pdf)

**Access/review:** Five-page NASA fact sheet; performance-seeking-control and F119 transition passages reviewed.

**Study use:** Documents the transfer of self-tuning onboard engine-model technology into F119 controllers; explains integration and engine-condition estimation.

**Limits:** Most examples and numerical benefits concern the NASA F-15 testbed. Do not transfer those gains or its propulsion-only landing capability to the F-22.

<a id="r136"></a>

### R136 — Eric Hehs — F-22 Raptor Design Evolution, Part 2, Code One Magazine

[Source](https://www.codeonemagazine.com/f22_article.html?item_id=180)

**Access/review:** Manufacturer magazine article with designer interviews reviewed.

**Study use:** Aircraft configuration evolution, centre-of-gravity packaging, agility/supercruise trade-offs and division of flight-control/avionics responsibilities.

**Limits:** Historical programme/design account. Do not treat proposed systems or early design requirements as proof of production equipment.

<a id="r137"></a>

### R137 — National Museum of the USAF — Pratt & Whitney YF119-PW-100L augmented turbofan

[Source](https://www.nationalmuseum.af.mil/Visit/Museum-Exhibits/Fact-Sheets/Display/Article/196077/pratt-whitney-yf119-pw-100l-augmented-turbofan/)

**Access/review:** Official museum technical notes indexed and reviewed.

**Study use:** Prototype engine provenance, twin-spool counter-rotation, augmented operation, FADEC and two-dimensional vectoring nozzle.

**Limits:** The museum item is a YF119 prototype. Its listed dimensions and development figures must not silently replace production F119 specifications.

<a id="r138"></a>

### R138 — Sherman N. Mullin — The Evolution of the F-22 Advanced Tactical Fighter, AIAA 92-4188, 1992

[Source](https://arc.aiaa.org/doi/10.2514/6.1992-4188)

[Virginia Tech bibliographic cross-check](https://archive.aoe.vt.edu/mason/Mason/ACiYF22.23.html)

**Access/review:** Publisher record indexed and academic bibliography reviewed; full original lecture paper not reviewed.

**Study use:** First-person programme leader's explanation of configuration evolution and the design requirements behind the ATF.

**Limits:** Development-era goals and prototype choices must be separated from production F-22 equipment and later upgrades.

<a id="r139"></a>

### R139 — Sherman N. Mullin — Winning the ATF, Mitchell Paper 9, June 2012

[Source](https://secure.afa.org/Mitchell/reports/MP9_ATF_0612.pdf)

[Publisher-hosted copy](https://www.mitchellaerospacepower.org/app/uploads/2022/08/MP9_ATF_0612.pdf)

**Access/review:** 72-page first-person programme history retrieved; relevant configuration, simulation and avionics workshare sections reviewed.

**Study use:** Explains the YF-22 versus proposed production configuration, sensor deletions, mission/PVI software responsibilities and simulator-supported design.

**Limits:** Retrospective participant account. Use for provenance and era distinctions, not a current technical specification.

<a id="r140"></a>

### R140 — Aronstein, Hirschberg and Piccirillo — Advanced Tactical Fighter to F-22 Raptor, AIAA, 1998

[Source](https://arc.aiaa.org/doi/abs/10.2514/4.867910)

[Publisher engine-development chapter record](https://arc.aiaa.org/doi/10.2514/5.9781600867910.0203.0234)

**Access/review:** Publisher book/chapter records and author/academic bibliographic descriptions located; complete book not reviewed.

**Study use:** Programme-engineering reference spanning requirements, configuration, avionics, propulsion and demonstration/validation. Engine-development chapter is a focused retrieval lead.

**Limits:** Book access may require a library. Avoid treating later publication/upload metadata as a later aircraft configuration; this is a 1998 history.

<a id="r141"></a>

### R141 — Thomas Morgenfeld — YF-22A Prototype Advanced Tactical Fighter Demonstration/Validation Flight Test Program Overview, AIAA 92-1087

[Source](https://arc.aiaa.org/doi/10.2514/6.1992-1087)

[SFTE 1991 related overview listing](https://www.sfte.org/fixed_wing_jet_military.php)

**Access/review:** Original AIAA publisher title/author record indexed; related SFTE listing reviewed. Full papers not reviewed.

**Study use:** Original pilot's programme overview covering prototype flight demonstration, stores management and propulsion/control integration.

**Limits:** Related similarly titled Abrams/Ferguson SETP/SFTE and AGARD records exist. Do not silently merge their authors or count every conference rendition as independent evidence.

<a id="r142"></a>

### R142 — Neville, O'Flarity and Selvidge — Flight testing the prototype advanced tactical fighter engine, AIAA 92-1036

[Source](https://arc.aiaa.org/doi/10.2514/6.1992-1036)

**Access/review:** Original publisher bibliographic record/title indexed; full paper not reviewed.

**Study use:** Pratt & Whitney test-engineering paper on YF119 flight clearance and prototype engine testing.

**Limits:** YF119/ATF demonstration evidence; production F119 engine decks and transient schedules are not established by this bibliographic lead.

<a id="r143"></a>

### R143 — Radovcich and Layton — The F-22 structural/aeroelastic design process with MDO examples, AIAA 98-4732

[Source](https://arc.aiaa.org/doi/10.2514/6.1998-4732)

**Access/review:** Publisher author/title record indexed; full paper not reviewed.

**Study use:** Original aeroelastic-design process and multidisciplinary trade-study reference, complementing R23's later validation paper.

**Limits:** Lead for structural/flight-control interaction, not an available rigid-body coefficient database.

<a id="r144"></a>

### R144 — Mark Morton — Certification of the F-22 Advanced Tactical Fighter for High Cycle and Sonic Fatigue, AIAA 2007-1766

[Source](https://doi.org/10.2514/6.2007-1766)

[Publication record](https://www.researchgate.net/publication/268477802_Certification_of_the_F-22_Advanced_Tactical_Fighter_for_High_Cycle_and_Sonic_Fatigue)

**Access/review:** Title, year and DOI cross-checked in publication record and publisher conference index; full paper not reviewed.

**Study use:** F-22-specific high-cycle/sonic-fatigue qualification lead, relevant to cavity acoustics, buffet and structural response.

**Limits:** Title-level lead only. No fatigue-life, buffet amplitude or weapons-bay timing numbers extracted.

<a id="r145"></a>

### R145 — Morton, Hampson and Alexander — Final Vibration and Acoustic Loads Development for Certification of the F-22 Advanced Tactical Fighter, AIAA 2008-1901

[Source](https://doi.org/10.2514/6.2008-1901)

[Publication record](https://www.researchgate.net/publication/268477986_Final_Vibration_and_Acoustic_Loads_Development_for_Certification_of_the_F-22_Advanced_Tactical_Fighter)

**Access/review:** Publication metadata/DOI reviewed; full paper not reviewed.

**Study use:** Follow-on F-22 loads/certification paper to pursue for vibration and aeroacoustic modelling.

**Limits:** Distinct from the 2007 certification paper, but related work is not independent validation of every shared result.

<a id="r146"></a>

### R146 — Atakan Kırkar — An aircraft design and analysis tool for a fifth-generation fighter jet: a flight mechanics perspective, METU thesis, 2025

[Source](https://open.metu.edu.tr/handle/11511/113380)

[Institutional PDF](https://open.metu.edu.tr/bitstream/handle/11511/113380/10692260.pdf)

**Access/review:** Institutional abstract and metadata reviewed; complete thesis not reviewed.

**Study use:** Modern conceptual modelling workflow using OpenVSP, analytical methods, Digital DATCOM, stability derivatives, relaxed static stability and reduced-order trim.

**Limits:** The abstract describes a designed conceptual aircraft, not an experimentally validated F-22 model. Do not import its coefficients as Raptor measurements.

<a id="r147"></a>

### R147 — Stoliker, Bosworth and Georgie — Linearized Poststall Aerodynamic and Control Law Models of the X-31A Aircraft and Comparison with Flight Data, NASA/TM-97-206318

[Source](https://ntrs.nasa.gov/citations/19980004669)

[NASA PDF](https://ntrs.nasa.gov/api/citations/19980004669/downloads/19980004669.pdf)

**Access/review:** NASA abstract and metadata reviewed; complete report not reviewed.

**Study use:** Reproducible poststall models and time/frequency-domain validation for a thrust-vectoring research aircraft.

**Limits:** X-31A, not F-22. Study the modelling/validation method; its vane geometry, coefficients, controller gains and 70-degree test envelope do not transfer to the Raptor.

## Standalone DCS implementation and additional performance evidence

<a id="r148"></a>

### R148 — Community DCS Modding Documentation — avSimpleRadar

[Source](https://modding.caffeinesimulations.com/Aircraft/Lua/Devices/avSimpleRadar/)

**Access/review:** Community-maintained device documentation reviewed, including initialization and parameter descriptions. Not an official ED compatibility promise.

**Study use:** Describes basic RWS/STT operation, the electric-device prerequisite, scan controls and contact/lock data. This is a candidate integration path for an independent radar prototype.

**Limits:** Explicitly lacks native TWS; search returns are unavailable in STT. A return slot represents a return instance, not necessarily a persistent aircraft ID. Prototype against a pinned DCS build before relying on the interface or inferring supported multi-target missile guidance.

<a id="r149"></a>

### R149 — Community DCS Modding Documentation — avSimpleWeaponSystem

[Source](https://modding.caffeinesimulations.com/Aircraft/Lua/Devices/avSimpleWeaponSystem/)

**Access/review:** Community-maintained device documentation reviewed. Some functions are marked unverified by the documentation itself.

**Study use:** Core-device station inventory, selection, launch, jettison, chaff/flare and ECM interfaces; documents zero-based station indexing.

**Limits:** A launch API does not by itself establish a guided-weapon targeting/support interface. Check actual behavior and native radio/radar/device linkage on the target DCS build.

<a id="r150"></a>

### R150 — Sérvalpilot — List of modding capabilities and limitations, January 2024

[Author's ED forum post](https://forum.dcs.world/topic/342798-list-of-modding-capabilities-and-limitations/)

**Access/review:** First-person modder observations and follow-up discussion reviewed. This is implementation testimony, not an ED SDK specification.

**Study use:** Reports radar-guided missile support via the simple radar, and discusses radio/core-device integration obstacles.

**Limits:** Dated January 2024. Reported close-range sensing and lock-loss limitations need reproduction; it does not prove native TWS, AESA behavior or a currently working independent F-22 combat stack.

<a id="r151"></a>

### R151 — FC3 avionics preload for third-party mods, ED forum exchange, 23 May 2025

[Source](https://forum.dcs.world/topic/373950-fc3-avionics-pre-load-for-3rd-party-mods/)

**Access/review:** Mod developer request and ED Team response reviewed.

**Study use:** Historical primary discussion of FC avionics preload changes, the base-install edit workaround and resulting integrity-check concern. ED declined the requested default change at that time.

**Limits:** Not a current universal statement about every mod or server. Independence removes this specific inherited-avionics dependency; it does not guarantee server admission or integrity-check acceptance.

<a id="r152"></a>

### R152 — Luiz Renault and contributors — A-29B community module

[Project](https://github.com/luizrenault/a-29b-community)

[Inspected revision](https://github.com/luizrenault/a-29b-community/tree/1f632f004e28ef13a5f3404528de4c3fc982a0e2)

[Device declarations](https://github.com/luizrenault/a-29b-community/blob/1f632f004e28ef13a5f3404528de4c3fc982a0e2/Cockpit/Scripts/device_init.lua)

**Access/review:** README, registration and device source inspected from a read-only checkout; no runtime testing.

**Study use:** Independent HUD, navigation, system and stores architecture; use of `avSimplest*` devices and custom cockpit indicators.

**Limits:** Includes compiled `avSimplest.dll` and `avSimplestRadio.dll`; the inspected tree does not supply corresponding C++ source. README allows Lua-system reuse in non-paid DCS modules and describes C++ reuse on request under stated conditions. Do not assume a permissive blanket license or copy binaries as a shortcut. No source or binaries were imported.

<a id="r153"></a>

### R153 — USAF Air Combat Command — F-22 Raptor Demo Team Media Kit, 2019

[Official PDF](https://www.acc.af.mil/Portals/92/AE/F-22%20Demo/F-22%20Media%20Kit%202019.pdf?ver=2019-08-01-143047-813)

**Access/review:** Official PDF indexed with specification excerpts; direct retrieval returned 403. Complete document not reviewed.

**Study use:** Indexed official summary lists +9 g and internal fuel of approximately 18,000 lb / 8,200 kg. Useful as a high-level cross-check against inconsistent mod constants.

**Limits:** A 2019 media summary, not a full flight manual, limiter schedule or structural-loads specification. Do not use it to infer transient overshoot, override logic or the complete performance envelope.
