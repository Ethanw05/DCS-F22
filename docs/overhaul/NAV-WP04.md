# NAV-WP04 — flight/landing source integration

The HUD consumes the owned measured CAS/TAS sample after EFM_POWER_OWNER latches. It never recomputes a healthy sensor from physics truth after that point. Frozen and biased health are explicitly degraded; stale samples withdraw the speed indication independently of pressure altitude and ground-velocity FPM. The 250 ms age / 50 ms future tolerance are adapter policies on spawn-relative F22_AP_CLOCK.

Landing cues consume coherent achieved down/up/unsafe scalar proxies and suspension WOW. These proxies are not independent leg-lock sensors. A conservative shared-ADC dependency withdraws AoA bracket/indexer cues when air data is degraded; an independent production AoA health model remains unqualified. Historical normal center remains12 degrees;11.5/12.5 edges remain estimates. Existing HUD geometry, styling and recorded audio are preserved.

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
