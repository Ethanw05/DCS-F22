# Install and test the experimental overhaul

This is an **overlay for an existing, complete Grinnelli F-22A installation** with its required F-15C/Flaming Cliffs avionics already working. It is not standalone and does not include the aircraft's large model/texture/audio assets. No DCS runtime is available in the build environment; simulator loading and flight testing remain pending.

1. Back up your working F-22A mod folder and saved input bindings.
2. Close DCS. Extract the overlay. Copy the **contents of its `F-22A` directory** into your existing F-22A mod directory (the directory containing `entry.lua`), replacing matching files. Do not accidentally nest `F-22A/F-22A`.
3. Confirm `bin/F22.dll` and `Cockpit/Scripts/HUD/page.lua` are present. `BUILD_INFO.txt` records the exact source commit and DLL hash. Install the DLL and Lua from the same overlay.
4. Start a new single-player mission. Rebind **F-22A HUD** controls, **F-22A Systems → Master Caution Acknowledge**, and the custom **F-22A HOTAS → Weapons: Release / Trigger** controls. Existing saved native bindings can bypass the new release interlock. Check brake-axis inversion in Controls.

## First test sequence

| Test | Expected behavior / what to report |
| --- | --- |
| Hot start, NAV | Green counter-pointer flight HUD. Report screenshot, eye position/FOV, resolution and VR status if blank/misaligned. Compare IAS/altitude/heading with native HUD and known conditions. |
| HUD switch and modes | Bind **Custom NAV HUD / Native HUD**. Check native visibility, then BVR/VS/BORE/FLOOD/GUN and return to NAV. Native combat cues must remain usable. Native brightness restoration may need manual adjustment. |
| Pitch, bank, crosswind | Check horizon direction, bank pointer, FPM displacement and heading wrap. Check both eyes in VR. FPM X denotes caged projection; low/rearward-speed invalid marker hides. |
| Cold start | Battery on, generator switches on, APU start/release, wait for ready, engine starts. Verify supplies, display power and hydraulic rise. APU should stop after about 60 s with both generators continuously available. |
| Controls and handling | Taxi with left/right pedals and digital brakes separately, parking brake, takeoff, cruise and approach. Compare nozzle/surface motion with pitch/roll inputs. Record fuel/mass, altitude, speed, weather and exact input for handling issues. |
| Display transitions | Cycle all MFD pages, day/night and zero brightness, then restore. No stale overlay pages. A fault should survive display-off; master-caution acknowledge should not repair it. |
| Custom gun/release | In flight, select the native weapon and combat mode, master arm, use custom trigger/pickle. Doors should clear before native firing. Custom missile pickle opens all bays because native selected-store mapping is unverified. Test release, safe, mode change and electrical loss stopping held commands. |
| Radar/RWR | Test native keyboard controls as well as PMFD. Check RWS/TWS, ranges, antenna elevation release, lock/launch and RWR modes. These remain F-15 capabilities; command estimates are not verified radar status. |
| ICP/HSI | Course/altitude reference entries accept CKE, reject invalid values and clear with UNDO. These entries do not command AP/route. Native AP, waypoint and HSI/ILS behavior needs separate testing; use native HUD for guidance. |
| AAR, repair and reload | Check actual refuel-door movement, tanker acceptance/quantity, repair, respawn and repeated mission load. These cross the host boundary and cannot be validated by local Lua tests. |

## Known changes and limits

- Seven active cockpit devices rewritten; original NAV HUD added; original assets retained. The full evidence/assumption table is in [OVERNIGHT_OVERHAUL.md](OVERNIGHT_OVERHAUL.md).
- Invalid legacy GBU-32-as-AAM and MAKO ARM offerings/presets are removed. Other custom missiles say `[APPROX]`; use native AIM-9/AIM-120 loadouts for the first compatibility tests. Existing missions using quarantined stores may need editing.
- Countermeasure defaults now fit the declared 240-unit budget: 120 chaff and 60 two-unit flares. This mix is a simulator assumption.
- Baseline OLS-27/TADS registrations removed; optional legacy IRST pod remains unvalidated. No new APG-77, ALR-94, IFDL, JDAM guidance, OBOGS/ECS or autopilot model is claimed.
- Aerodynamic/engine/control coefficients remain an uncalibrated public-source approximation. No CFD was performed. No complete real F-22 performance database was obtained.
- Restore the backed-up **whole mod folder** to roll back. Mixing an old DLL with new Lua is not a supported rollback. Multiplayer/server integrity and licensing/installation prerequisites remain those of the existing mod/DCS environment.
