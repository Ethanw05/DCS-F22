# Hybrid C-130J-inspired heading design

The user explicitly selected the C-130J/Hercules horizontal navigation heading presentation as a **design reference**, while retaining the documented F-22 counter-pointer flight information.

- [NASA public C-130 ANVIS/HUD study, Figure 4.31](https://ntrs.nasa.gov/api/citations/19980018292/downloads/19980018292.pdf): moving horizontal heading tape, numeric heading and waypoint caret, with separate nav data. This is an ANVIS/HUD study, **not definitive evidence of a present-day C-130J implementation**.
- [Lockheed Martin C-130J Pocket Guide](https://www.sikorskyaircraft.com/content/dam/lockheed-martin/aero/documents/C-130J/C130JPocketGuide.pdf): real C-130J displays and two HUDs.
- [F-22 HUD symbol ledger](HUD_SYMBOL_LEDGER.md): baseline aircraft appearance.

HUD page uses a continuous scrolling 10-degree heading tape with independent central readout, and the F-22-era counter-pointers. **Waypoint caret is not implemented**, since the current nav solution has no verified waypoint bearing/validity interface. Do not fake steering cues.

Notes: DCS HUD collimate/align, clip and update semantics and 3D EDM connector names need in-simulator verification. This initial HUD also coexists with the inherited FC3 HUD until independently suppressed; double-image possible. Do not claim F-22 historical authenticity for the C-130 navigation overlay.
