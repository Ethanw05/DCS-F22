# Experimental flight HUD

Original geometry and Lua data drive; see [picture comparison](HUD_REFERENCE_COMPARISON.md) and [system evidence/assumptions](OVERNIGHT_OVERHAUL.md). R03 Fig.1 defines the adopted counter scales: 100 kt and 1,000 ft per revolution, clockwise with increasing value. Fig.3 supplies a broad F-22 layout reference; the C-130J photograph cross-checks the shared layout family. Neither is a complete operational mode specification.

The custom HUD is the default in **NAV**. Other modes restore the native tactical HUD so target/weapon cues continue to come from the retained F-15 backend. The keyboard/joystick control category **F-22A HUD** includes:

| Action | Command |
| --- | --- |
| Custom NAV HUD / Native HUD | 10680 |
| Custom HUD brightness increase/decrease | 10681 / 10682 |

The ICP wheel changes the visible custom NAV HUD brightness; otherwise it sends native HUD brightness commands. Switching to native restores it toward full brightness, not the previous user setting. Adjust native brightness as necessary.

Speed is indicated knots; barometric and radar altitudes are feet; AoA is degrees. The flight-path marker uses body-axis **ground velocity**, not air-relative velocity. It hides without valid body state or usable forward motion; an X flags the bounded/caged projection. This is not a full velocity-vector display at arbitrary rearward/high-alpha attitudes. Heading labels wrap through north; positive/negative pitch lines use different line styles. Layout and clipping are approximations.

`HUD/config.lua` holds the **unverified** optical origin and dimensions. Test at the normal eye point and in VR before interpreting placement as conformal accuracy. No native steering, ILS, target, missile or bomb guidance is synthesized on the custom NAV page. Use the native HUD for those functions.

`hud_test.lua` checks math and lifecycle; `indicator_test.lua` constructs the real page. Neither test can determine whether the collimator aligns with the EDM glass, whether both eyes see it correctly, or whether native suppression works in the installed DCS version.
