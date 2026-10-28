# NAV-WP04 — flight/landing source integration

The HUD consumes the owned measured CAS/TAS sample after EFM_POWER_OWNER latches. It never recomputes a healthy sensor from physics truth after that point. Frozen and biased health are explicitly degraded; stale samples withdraw the speed indication independently of pressure altitude and ground-velocity FPM. The 250 ms age / 50 ms future tolerance are adapter policies on spawn-relative F22_AP_CLOCK.

Landing cues consume coherent achieved down/up/unsafe scalar proxies and suspension WOW. These proxies are not independent leg-lock sensors. A conservative shared-ADC dependency withdraws AoA bracket/indexer cues when air data is degraded; an independent production AoA health model remains unqualified. Historical normal center remains12 degrees;11.5/12.5 edges remain estimates. Existing HUD geometry, styling and recorded audio are preserved.

The E-bracket now uses linear reference-minus-measured AoA, correcting the former
reversed `tan(AoA-12)` displacement. Its center prong is above FPM below12° AoA,
aligned at12°, and below FPM above12°. Sideways spacing stays fixed; moving AoA
continuously moves the complete bracket vertically. Put FPM on the intended
flight path and adjust toward center-prong alignment for on-speed AoA. This cue
does not measure runway alignment or glideslope.

Native comparison,28October2026: IDA MCP inspected `FA18C-unpacked.dll`, image
base0x180000000, SHA256
`0bd15061bdb6b126c87b51a7a0baa4d4ad3c9f3da7985a9539ec2b9b58ce7baa`.
Producer0x1803E4D00 computes8.1-minus-AoA and publishes bus69/70; constructor
0x1804665F0 at0x18046721D/0x18046723E binds those to HUD34/35. Transfer
0x1804793D0 uses the HUD accessor0x180477D40 and setter0x1804641B0.
Registered `HUD_E_bracket` callback0x1804E0220 reads34/35 and translates along
local Y with51.33321329395087 DI/degree. Callback0x1804E0360 applies the
10-degree radial displacement limit declared in installed Hornet `HUD_common.lua`.
The adopted limit accounts for the existing60-DI lateral offset,1DI=0.34mrad.
These are Hornet presentation analogues; the F-22 target remains12°, supported
for the historical normal EMD configuration by the
[Rainey/Kohn flight-test account](https://man.fas.org/dod-101/sys/ac/docs/f-22-emd-paper.htm).
Neither Hornet8.1° nor a selected single-engine EMD test law is imposed here.
Focused actual Lua tests check recovered comparison vectors, both native unit
scales, center alignment, direction, continuous motion, saturation and invalid/
stale ADC/gear/contact withdrawal. Post-install DCS flight appearance remains
unverified; existing logs contain no valid airborne gear-down approach sample.

Actual Lua owner tests exercise biased/frozen/invalid samples, gear transit/unsafe, publication epoch changes, stale frames, restoration and independent barometry. 2D/VR angular calibration, dedicated AoA health, native cage/ghost appearance remain separate qualification work.

NAV-mode10723 now routes only to HUD11840; weapon master modes retain only seeker10805. The existing held-input owner suppresses duplicate presses. Computed FPM validity, drawing validity and off-glass status are distinct. Caged lateral FPM retains a compact uncaged ghost on the same existing plane; an off-glass measurement displays FPM LIMIT, not a sensor failure. Geometry and ghost dimensions are mod presentation estimates; flight glyph/font/green/projection and recordings are retained. Actual Combat_Logic and HUD owner tests cover exclusive routing, repeated-down, computed/off-glass distinction and cage/ghost behavior.
# HUD ground designation and edge indication

HUD sensor focus is indicated by a filled dot inside the valid flight-path marker when SCS selects the HUD. At the user's request, its diameter is tripled (radius 0.009 layout units) for clearer selection feedback. The former separate HUD focus label is removed; the dot follows the existing marker and uses its power/validity gates. Size remains a mod presentation choice.

Chuck's F/A-18C guide, Part 9 and Part 10 (including p. 444), describes
HUD/FLIR target designation as a sensor-owned point with a HUD cue. This
mod's SCS-up HUD focus and TDC depress now issue a terrain line-of-sight
designation in NAV as well as A/G, with a complete press/release per action.
Confirmed waypoint, HUD and ground-radar designations share the existing
ground-target owner. When outside the glass, a flashing square of the same
size as the radar target box is drawn at the glass edge; on-screen markers
retain their existing diamond. The 0.5-second blink cycle is a mod estimate.
The target survives master-mode changes; power loss and explicit clear still
withdraw it. Dedicated FLIR/LITENING target-provider integration is not yet
implemented, and the HUD optics and behavior require DCS flight verification.
