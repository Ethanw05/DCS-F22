# NAV-WP04 — flight/landing source integration

The HUD consumes the owned measured CAS/TAS sample after EFM_POWER_OWNER latches. It never recomputes a healthy sensor from physics truth after that point. Frozen and biased health are explicitly degraded; stale samples withdraw the speed indication independently of pressure altitude and ground-velocity FPM. The 250 ms age / 50 ms future tolerance are adapter policies on spawn-relative F22_AP_CLOCK.

Landing cues consume coherent achieved down/up/unsafe scalar proxies and suspension WOW. These proxies are not independent leg-lock sensors. A conservative shared-ADC dependency withdraws AoA bracket/indexer cues when air data is degraded; an independent production AoA health model remains unqualified. Historical normal center remains12 degrees;11.5/12.5 edges remain estimates. Existing HUD geometry, styling and recorded audio are preserved.

Actual Lua owner tests exercise biased/frozen/invalid samples, gear transit/unsafe, publication epoch changes, stale frames, restoration and independent barometry. 2D/VR angular calibration, dedicated AoA health, contextual cage and off-glass presentation remain separate work.
