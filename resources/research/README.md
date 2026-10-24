# F-22 avionics and flight-model research (24 October 2026)

This directory is the **implementation-facing supplement** to [the existing 176-source study catalogue](../../docs/RESOURCES.md) and [system audits](../../docs/audit/README.md). It distinguishes direct military/manufacturer evidence from secondary simulator work and from engineering approximations.

## Priority and provenance

1. **F-22-authenticated visual evidence**: US Air Force *Flying Safety* June 2002, F-22 HUD Figure 1 (reproduced as Fig. 3 in Aiba, 2008); the user's provided copies; attributed real aircraft photographs for HUD physical structure.
2. **Comparative human-factors evidence**: K. Aiba's 2008 JASDF counter-pointer study; historical HUD work, DoD display handbooks and standards. The JASDF paper reproduces the same F-22 illustration; do not count it as a second independent F-22 flight capture.
3. **F-22 manufacturer, aviation and test evidence**: cockpit-avionics integration, historical TVC and propulsion publications, public DoD operational reports.
4. **MIL-STD (Richard Carter) P3D/F-22A Advanced Avionics**: comparison implementation and leads, **not** primary evidence of real symbology, exact flight control laws or reuse permission.
5. **Non-F-22 military engineering**: assumptions for generic rates/filters/control-model structure; explicitly mark parameters provisional.

## Entries

- [BIBLIOGRAPHY.md](BIBLIOGRAPHY.md) — clickable primary resources, public links and attribution.
- [HUD_SYMBOL_LEDGER.md](HUD_SYMBOL_LEDGER.md) — trace the user's F-22 display illustration without guessing tactical semantics.
- [IMPLEMENTATION_RULES.md](IMPLEMENTATION_RULES.md) — evidence to code to verification and limitations.
- The original user-provided screenshot is not replicated as a new third-party binary. The original 2002 figure is accessible via the listed publisher/JASDF sources.

**No CFD** is authorized for this pass; the exact geometry and measured coefficient datasets are not verified. Do not represent generic HUD standards or FSX/P3D avionics as leaked/official F-22 operational software. No exact APG-77/ALR-94 implementation parameters, F119 engine deck, or classified data are claimed.

## Integration gate

Baseline `Cockpit/Scripts/device_init.lua` has no own HUD indicator and still relies on the legacy F-15C/FC3 avionics chain. A new stand-alone HUD must bind to a real cockpit EDM HUD connector, maintain conformality and correct eye position, and be checked **inside DCS** (including VR). HUD Lua alone cannot certify geometry or eliminate the legacy radar/weapon dependencies.
