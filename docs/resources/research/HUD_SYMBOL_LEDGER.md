# Historical F-22 HUD symbol ledger — user's Figure 1

The submitted blue/green image is explicitly labeled **F-22 HUD Figure 1** in USAF *Flying Safety*, June 2002; also Fig. 3 in Aiba (2008). It is a **published illustration** (not metrically calibrated HUD optics). The user's second image is a training **Figure 4** explaining counter-pointer behavior; not a different operational mode.

Coordinates below are conceptual and must be retuned against real HUD/EDM projection, **not** treated as pixel-to-milliradian calibration.

| ID | Figure 1 observation | Implementable representation | Evidence/confidence | Limit |
|---|---|---|---|---|
| H01 | Counter-pointer round indicator left of center; numeric `442` | IAS numeric in knots and rotating speed pointer; ring/dots stay fixed | N01/N02: high for form | Moving pointer tick calibration illustrated generically in N02, not aircraft production calibration. |
| H02 | Counter-pointer round indicator right; numeric `1600` | Pressure altitude numeric in feet and rotating altitude pointer | N01/N02: high for form | Do not equate 1600-ft depiction with radio altitude. |
| H03 | Horizontal split line from left to right around center | Horizon reference, roll-dependent with pitch | N01: high for appearance | Conformal collimation requires external eye-point calibration. |
| H04 | Center ring with three radial/stem bars | Flight-reference-like marker; preserve shape | N01: high shape; medium interpretation | Distinguish true flight path from aircraft boresight; semantics not proven by screenshot alone. |
| H05 | Pitch angle bracket lines above/below center; markings 5/10 etc. | Pitch ladder with signed angular labels | N01: high shape; medium spacing | Correct form means pitch labels rotate with roll, vertical offset with pitch. |
| H06 | W-shaped cue above central flight symbol | Maintain as documented visual anchor (not auto-wire combat meaning) | N01: high shape; low semantics | Needs operating-mode corroboration. |
| H07 | Lower semicircular tick arc and central triangular indicator | Roll-angle scale/marker approximation | N01: high form; medium semantics | Whether arc is fixed or rotating needs external validation. |
| H08 | Heading box at top `150` | Heading numerics normalized to 000..359 | N01: high appearance | True vs magnetic heading source not established. |
| H09 | Left block `T`, Mach, G, alpha | Four text readouts with unit discipline | N01: medium text interpretation | Defer exact label text to higher-resolution original. |
| H10 | Right-side lower navigation/readout block | Conservative placeholder only until label/data semantics sourced | N01: low legibility | Never invent coordinates, route, tactical cues. |

### Independently supported comparison reference

Aiba 2008 Fig. 1(B) explicitly illustrates **10-kt marks/100-kt revolution** for speed and **100-ft marks/1000-ft revolution** for altitude (N02, page 22). These are appropriate *provisional generic counter-pointer choices*, **not authenticated unique F-22 parameters**.

### Implementation acceptance

1. HUD is a dedicated cockpit indicator with an actual EDM anchor and DCS-rendered conformal/horizon geometry; don't copy a head-down MFD transform.
2. Counters show plausible continuous values and independently rotate their pointers, test at `99→100` knots and `999→1000` feet and when values decrease.
3. Attitude ladder/horizon use radians and DCS units correctly; test upright, 30°/90° bank, climb/descent, unusual attitudes.
4. IAS/TAS, barometric/radar altitude, heading, AoA and Mach have explicit units; invalid sensors blank/flag.
5. Power gating, daylight/night brightness, clipping, VR both eyes and native legacy HUD double-drawing must be tested **in DCS**.
6. Do not claim full tactical HUD realism until actual underlying sensor/weapon modes exist.
