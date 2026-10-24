# Chinese-language research and manual search

Search/review date: **24 October 2026**. This supplements the existing public-source collection and the [system-by-system audit](audit/README.md). Original Chinese titles are retained in [R154–R171](RESOURCES.md#r154); translations identify subject matter, not official aircraft terminology.

## Result

The search found useful Chinese-language journal and university material on avionics architecture, high-angle-of-attack modeling, integrated thrust-vector control and HUD human factors. It did **not** locate an authenticated public F-22 technical-order flight manual, complete HUD symbol/mode handbook, production aerodynamic database or installed F119 engine deck.

“Not located” is a bounded search outcome. It does not establish that every Chinese site, archive or document has been searched. The strongest new material provides research methods and historical architecture analysis. F-22-like CFD models remain reconstructed aircraft, not released manufacturer data.

## Search scope

Both web search services were used, with follow-up on publishers, university repositories and CAAC material. Searches covered simplified and traditional Chinese and English designations. Representative query families:

| Topic | Search terms used |
| --- | --- |
| Manuals | `F-22 飞行手册`, `F22 飞行手冊`, `F-22 操纵手册`, `F-22 flight manual`, `TO 1F-22A-1` |
| HUD/cockpit | `F-22 平视显示 符号`, `F22 座舱 显示 论文`, `抬頭顯示器`, `平显`, `HUD 符号 飞行航迹` |
| Flight/TVC | `F22 大迎角 气动 参数辨识`, `似F-22 模型 襟翼`, `综合飞行 推力矢量`, `二元 矢量喷管 控制` |
| Avionics/sensors | `F-22 综合航空电子 CIP`, `先进战斗机 飞行控制计算机`, `雷达 电子支援 异步 航迹关联` |

The queries above describe subject coverage, not a reproducible exhaustive database crawl. Site access varied: abstracts, indexed excerpts, complete public HTML and selected downloadable PDFs were treated differently.

## Accepted material by system

| References | Original publication/repository | Applicable audit systems | Review depth and caution |
| --- | --- | --- | --- |
| [R154](RESOURCES.md#r154) | 航空学报, 1997, advanced avionics core processor | Integration, mission avionics | Publisher abstract/metadata; historical analysis based on F-22 CIP, not manufacturer implementation. |
| [R155](RESOURCES.md#r155) | 航空学报, 2007, advanced fighter flight-control computers | FCS, vehicle systems, avionics | Public eight-page PDF retrieved; architecture sections and references inspected. Separates vehicle/mission computing. |
| [R156](RESOURCES.md#r156) | 北京航空航天大学学报, 2013, character coding | HUD, displays/lighting | Publisher abstract; general human-factors experiment, not F-22 typography. |
| [R157](RESOURCES.md#r157) | 沈阳航空航天大学学报, 2023, GA HUD workload | HUD, displays | Eight-page PDF retrieved; methods/results inspected. Cessna-based simulator, not Raptor HUD. |
| [R158](RESOURCES.md#r158) | CAAC, HUD technology presentation | HUD | Public page reviewed; civil guidance/projection concepts, not military symbol shapes. |
| [R159–R161](RESOURCES.md#r159) | Integrated flight/TVC and failed-effector studies | FCS, TVC, damage | Publisher abstracts; methods and aircraft layouts differ. Three-dimensional vectoring concepts must not become F119 yaw-vector authority. |
| [R162](RESOURCES.md#r162) | 清华大学学报, 2017, unsteady identification | Aerodynamics/performance | Publisher record/indexed abstract; model identification results do not establish real F-22 coefficients. |
| [R163–R164](RESOURCES.md#r163) | National Cheng Kung University theses | Aerodynamics, control configuration | Institutional abstracts and contents; full theses not inspected. Reconstructed F-22-like CFD and alternative geometry. |
| [R165](RESOURCES.md#r165) | NCKU institutional RCS thesis record | Radar/signature assumptions | Abstract/record; simplified material/geometry/frequency assumptions, not operational signatures. |
| [R166](RESOURCES.md#r166) | 空气动力学学报, 2022, high-alpha review | Aerodynamics, validation | Publisher abstract and indexed selected material. Follow each reused F-22 figure to its original source. |
| [R167](RESOURCES.md#r167) | 航空学报, 2020, intake behavior in post-stall maneuvers | Aerodynamics, engines | Public HTML; selected methods/validation sections reviewed. Aircraft is not established as F-22. |
| [R168](RESOURCES.md#r168) | 航空学报, 2024, airframe/engine integration review | Engines, TVC | Public HTML; selected nozzle/integration sections, including F119 illustration, reviewed. No production engine schedules. |
| [R169](RESOURCES.md#r169) | 液压与气动, 2023, 2D nozzle control | TVC, hydraulics | Publisher metadata and indexed abstract. Unnamed engine, not an F119 control manual. |
| [R170](RESOURCES.md#r170) | 系统工程与电子技术, 2021, asynchronous radar/ESM association | Radar, EW, fusion | Publisher-indexed abstract/citation; direct article retrieval failed. General method only. |
| [R171](RESOURCES.md#r171) | 指挥控制与仿真, 2023, cooperative sensor simulation | Sensor architecture/test design | Public HTML, selected sections; hypothetical carrier fighter and assumed ranges. Do not import those numbers as APG-77 performance. |

These **18 catalogue additions** are independent numbered study records, not 18 newly discovered F-22 manuals. R172 adds official JDAM descriptions for checking the existing bomb declaration; it is not Chinese-language material.

## Manual leads and material excluded from calibration

| Lead/result | Disposition |
| --- | --- |
| Public AFMAN 11-2F-22A training, evaluation and operation documents | Already catalogued as [R48–R50](RESOURCES.md#r48), with edition/access limitations. These are not a detailed aircraft technical-order flight manual. |
| AOA X-Plane and Top Mach MSFS F-22 manuals; Chinese simulator release/tutorial pages | Simulator documentation. Useful only for comparison of other simulations, not evidence of the real aircraft's systems or performance. |
| *F-22 Total Air War*, *Air Dominance Fighter*, *Lightning 3* and other old game manuals | Rejected as aircraft-authority sources. Search engines often surface their detailed HUD chapters for real-manual queries. |
| A user-uploaded document labelled `TO 1F22A1.pdf` and translated discussions asking whether it is genuine | Provenance/authenticity not established. No figures, procedures or numeric data from it used in this audit. A filename and military-looking cover are insufficient. |
| Chinese general-interest cockpit/F-22 articles, including regional-government encyclopedia hosting | Secondary reporting. Official hosting does not establish manufacturer authorship or traceable calibration data. Prefer cited originals. |
| Auto-translated Reddit, social video, unattributed “manual” downloads and media claims | Not promoted into technical references. Repetition across sites is not independent corroboration. |
| CAAC PDF `P020240110537776228169.pdf` | Search-index HUD excerpts found; retrieval failed and document identity/content was not sufficiently verified. Retained only as a follow-up lead, not counted among accepted references. |
| AGARD AR-343, *Integrated Flight and Propulsion Control* | Bibliographic trail from R155 and a public mirror located. Original report not reviewed in this pass; follow up through an authoritative archive before citing its technical details. |

## How this changes the audit

The new material strengthens the case for separating physical systems, control allocation, mission state and presentation; for testing high-alpha continuity; and for distinguishing actual vector angle from nozzle area/animation. Those are study directions. The confirmed defects in the audit were established from the mod's code and isolated execution, independently of whether any Chinese paper modeled a similar aircraft.

For HUD reconstruction, R02/R03 remain the main published appearance reference in this collection. The Chinese HUD sources help design evaluation criteria, not fill missing F-22 tactical symbols. For performance, fit no real-aircraft claim to an unvalidated CFD thesis or an unspecified scenario. Every future parameter should retain its source, aircraft era, conditions, confidence and explicit assumption status.

All 16 systems have a documented source review. Implementation and simulator validation remain deferred, as requested.
