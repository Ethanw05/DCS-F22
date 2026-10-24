# Avionics, HUD and flight-performance reading guide

Research pass: 24 October 2026. The [main catalogue](RESOURCES.md) contains **181 numbered entries**. The expanded aircraft pass added 60: 13 HUD/cockpit/display references, 24 avionics/integration references and 23 flight-control/performance references. The first overhaul assessment added six sources, R148–R153. The first Chinese-language pass adds 18 records, R154–R171; R172 adds official JDAM descriptions. The forum follow-up adds R173–R176 and improves text access to R65. These include explicitly labelled supporting research on other aircraft and bibliographic leads; they are not 181 complete F-22 technical manuals. Companion links and unresolved report editions are grouped.

For implementation, read the [code assessment](OVERHAUL_ASSESSMENT.md), [standalone design](STANDALONE_DESIGN.md) and [roadmap](OVERHAUL_ROADMAP.md). The assessment separates reproduced numerical defects from fidelity gaps and untested DCS integration assumptions.

The expanded [16-system audit](audit/README.md) is the current review record and keeps implementation deferred. The [Chinese research report](CHINESE_RESEARCH.md) explains source selection and manual-search outcomes. Each system review identifies applicable references and their limits.

The [Chinese forum follow-up](CHINESE_FORUM_RESEARCH.md) records community leads separately from primary evidence. Read the [system evidence addendum](audit/RESEARCH_ADDENDUM.md) for the implications of the new source trails.

## Start here

| Study goal | Read first | What to look for |
| --- | --- | --- |
| Actual F-22 HUD appearance | [R02](RESOURCES.md#r02), [R03](RESOURCES.md#r03), historical corroboration [R01](RESOURCES.md#r01) | Published F-22 illustration is the main appearance reference; R03 reproduces R02. Manufacturer rig footage is not the principal reference. |
| Why the flight symbology looks that way | [R99](RESOURCES.md#r99), [R91](RESOURCES.md#r91), [R92](RESOURCES.md#r92) | Counter-pointers, attitude references and display dynamics; general research does not establish exact F-22 modes. |
| Cockpit/display responsibilities | [R09](RESOURCES.md#r09), [R06](RESOURCES.md#r06), [R07](RESOURCES.md#r07), [R125](RESOURCES.md#r125) | Architecture, controls, displays and synoptics. Two original cockpit papers still need full-text access. |
| Radar and integrated avionics | [R101](RESOURCES.md#r101), [R121](RESOURCES.md#r121), [R104](RESOURCES.md#r104) | APG-77 development, core-processing recovery and CNI. |
| Flight-control behaviour | [R20](RESOURCES.md#r20), [R125](RESOURCES.md#r125) | Control-law design, pilot-command concepts and configuration transitions. |
| Vectoring and aerodynamic integration | [R126](RESOURCES.md#r126), [R129](RESOURCES.md#r129), [R25](RESOURCES.md#r25), [R65](RESOURCES.md#r65) | Public design figures, inlet/nozzle integration and the distinction between YF-22 and F-22. |
| Real-aircraft performance checkpoints | [R131](RESOURCES.md#r131), [R21](RESOURCES.md#r21), [R22](RESOURCES.md#r22) | Conditions, configuration and test-era limits; keep demonstration profiles separate from full performance envelopes. |
| CFD/model validation | [R127](RESOURCES.md#r127), [R147](RESOURCES.md#r147), [R146](RESOURCES.md#r146) | Distinguish flight measurements, simulation output, relative-error plots and conceptual estimates. |
| Later avionics configurations | [R108](RESOURCES.md#r108), [R109](RESOURCES.md#r109), [R107](RESOURCES.md#r107), [R38](RESOURCES.md#r38), [R80](RESOURCES.md#r80) | Record whether each source describes a test, contract, first delivery or operational installation. |
| Removing the paid-aircraft prerequisite | [R86](RESOURCES.md#r86), [R87](RESOURCES.md#r87), [R148–R152](RESOURCES.md#r148) | Core device capability, compiled-component boundaries, reuse terms and the need to prove actual missile support separately from display tracks. |
| Chinese architecture/control studies | [R154–R155](RESOURCES.md#r154), [R159–R161](RESOURCES.md#r159), [R168–R169](RESOURCES.md#r168) | Integrated computing, allocation and nozzle-state separation; methods do not supply production F-22 gains or F119 schedules. |
| Chinese HUD evaluation studies | [R156–R158](RESOURCES.md#r156) | Character readability, workload and civil projection concepts; not a Raptor symbol handbook. |
| Chinese aero/sensor modeling | [R162–R167](RESOURCES.md#r162), [R170–R171](RESOURCES.md#r170) | Model provenance, limited conditions, timestamps and assumed scenarios; reconstructed aircraft are not measured F-22 data. |
| Pilot testimony and architecture follow-up | [R173–R176](RESOURCES.md#r173) | Keep original-presentation leads, selected interview text, general methods and actual aircraft measurements distinct. |

## Useful page and figure pointers

- **R125, MIT slides:** PDF p. 3 shows cockpit/synoptic illustrations; p. 4 covers landing and air-refuelling modes; p. 5 covers limiters and pilot-command concepts. The course page is IAP 2019 while the slides carry a 2020 date. The lecture has not been fully reviewed in this pass.
- **R126, original Virginia Tech notes:** printed pp. 9-11–9-14, especially Figure 9-12 (control-surface rates/deflections), Figure 9-13 (pitch control), Figure 9-14 (lateral/directional effects), and Figure 9-15 (roll comparison). Rates are labelled **no-load**. Some plots omit scales. The newer textbook explicitly describes prototype data in several figures; cross-check its narrative against the originals.
- **R129, publisher full text:** sections 6.1.1 and 6.1.2 cover the F-22 inlet and nozzle.
- **R131, 2022 USAF demonstration manual:** Chapter 5, printed pp. 108–134. Start with configuration, fuel and density-altitude conditions before using any manoeuvre table.
- **R127, CFD paper:** PDF pp. 4–6 explain validation data and plot conventions; pp. 10–13 contain F-22 clean/tank and J-turn discussion. Most plotted results withhold absolute scales. The J-turn input was generated from ATLAS when digital flight-test data were unavailable.
- **R128, NASA history:** printed pp. 159–165, PDF pp. 172–178, cover F-22 research, tunnel testing and buffet.
- **R91, TRISTAR I:** printed pp. 4–6 introduce the symbol alternatives, quickening/caging and ILS presentation; figures and appendices provide experimental examples. The research simulator used an AV-8B model.
- **R110, NPS thesis:** abstract and printed p. 27/PDF p. 41 discuss integration and legacy-versus-modern software pathways.

## Keep these distinctions in our notes

1. **Airframe and era.** Tag YF-22 prototype, F-22 EMD, production baseline, operational increment and later experimental upgrade separately. An EMD software block name is not automatically a later operational increment.
2. **Evidence type.** Mark measurements, author explanations, manufacturer capabilities, simulator predictions and conceptual estimates. A model resembling an F-22 is not a measured Raptor aerodynamic database.
3. **Performance conditions.** Keep weight, fuel/stores, atmosphere, altitude, airspeed definition, power setting and configuration with every numerical claim. A manoeuvre limit, an actuator no-load rate and a sustained performance value describe different things.
4. **Display evidence.** A projector specification, generic symbol study, simulator screenshot and operational HUD image establish different facts. Brochure image-source resolution/field of view should not override the installed aircraft's optical geometry.
5. **Access and revision.** Record the actual cover/footer. For example, R89's URL says /2024/08/ but the retrieved brochure identifies revision 052026:V1.

## Still unresolved

The collection does **not** establish a complete, verified operational F-22 HUD/MFD symbol dictionary, all HOTAS/ICP mappings, current radar/EW mode logic, a full installed F119 engine deck or full-envelope aerodynamic coefficient tables. Exact gains, schedules and unmeasured values must remain explicitly assumed in any future implementation.

Priority full-text retrieval leads are **R06/R07** (cockpit integration), **R101/R121** (radar/core processing), **R130/R141/R142** (prototype flight/propulsion testing), and **R143–R145** (aeroelastic/loads work). R65 now has readable original-paper text via a public mirror; a clean original with figures is still preferable.

Search results also produced misleading matches: commercial F-22 game manuals presented as flight manuals, Fairchild F-22 material unrelated to the Raptor, WVU scale-model YF-22 research, and a NASA conference volume indexed under a HUD section title. These were not promoted into aircraft-accuracy references. Patent concepts and generic research retained in the catalogue are labelled accordingly.

Access was checked during this pass; some official PDFs still returned 403, publisher verification pages or dead legacy URLs. The catalogue distinguishes those leads from retrieved text. External papers remain linked to their hosts; only our study notes are added to the repository.

## Implementation follow-up

[FLIGHT_MODEL.md](FLIGHT_MODEL.md) maps each replacement physics system to evidence and assumed values. R177 is a visual simulator comparison, R178–R179 provide primary equation references, and R180–R181 add standalone combat-mod precedents. See [STANDALONE_FOLLOWUP.md](STANDALONE_FOLLOWUP.md) for what those precedents actually establish.
