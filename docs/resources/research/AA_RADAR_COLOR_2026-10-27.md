# A/A radar native color correction — 27 October 2026

Status: installed in the actual Saved Games mod and verified in the dedicated native DCS mission. The test session is closed and its temporary hook removed.

The A/A format authored light-blue geometry as sRGB `(113,188,240)` and supplied those byte values directly to DCS. The offline renderer used them as final image RGB. In an existing native capture, the dominant range-ring color is `(172,202,213)`, close to white symbology at `(213,214,214)`, which explains the pale/white appearance. This capture predates this change and is not evidence that the correction has passed in-game.

Read-only IDA examination of CockpitBase.dll confirms:

- `ccIndicatorPage::reg_in_script`, around `0x18039684e`, registers `MakeMaterial` to `sub_180395D70`.
- `sub_180395D70`, `0x1803961cb` through `0x1803961ea`, normalizes RGBA by 255 without an sRGB transfer before calling `cockpit::ConstructMaterialEx`.
- `ceSMultiLine::set_mat_params` at `0x1803bdd70` uses the common element material path before applying stroke parameters.

DCS's material/shader pipeline and tone mapping do not match the offline renderer's direct byte-color rasterization. The correction explicitly decodes authored sRGB for the A/A native line/font resources. Light-blue native input becomes approximately `(42.06,128.24,222.04)`. Alpha remains unchanged. Dedicated registered material/font names keep this change within the A/A format. The upper displays, neutral-gray backgrounds, HUD, MFD geometry and sensor owners are unchanged.

Files: `MFD_COMMON/radar_palette.lua`, `materials.lua`, `PMFD_CENTER/radar_format.lua`. The radar preview tool uses the authored display colors rather than treating native linear values as sRGB. It now handles the existing conditional-color controller when traversing inactive A/G elements.

Validation: new actual-resource/element-binding test, display startup, LCD typography, common MFD workflow and tactical identity palette all pass. The resource test checks registration, font/geometry agreement, sRGB round trip, unchanged alpha and every A/A line/font binding. Native verification completed after installation: all four main display format parameters reported A/A TSD, and a real screenshot shows blue range rings, compass and blue labels distinct from white reference symbology. Dominant corrected blue is approximately `(111,193,218)` versus white `(218,220,220)`. DCS exposure/tone mapping still affects exact output RGB; the correction is not a promise of byte-identical preview pixels.

Development and installed files were identical before staging these three files. Evidence and guarded installer: `D:/Codex-F22-Overhaul-2026-10-25/mfd-color-20261027/`.

Native evidence: [full screenshot](mfd-color-2026-10-27/F22-AA-Color-Corrected.png), [control acknowledgements](mfd-color-2026-10-27/native-results.txt), [color samples](mfd-color-2026-10-27/native-color-samples.json), [installed file hashes](mfd-color-2026-10-27/install-receipt.json).
