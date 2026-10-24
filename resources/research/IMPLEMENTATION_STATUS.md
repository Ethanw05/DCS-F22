# Overhaul implementation change log — 24 October 2026

Changes are committed to **`main`**, the repository's active development branch. This is not an independent release or fully in-game-tested build.

## Implemented (build verified, DCS runtime unverified)

- Historical counter-pointer HUD with synthesized analog pointers, pitch ladder, flight-path marker and intentionally C-130-inspired heading tape. Model HUD connectors/VR optics and inherited HUD conflict still open.
- Actor/actuator rate update now uses `dt`; approximate old tuning normalized from 0.006-s expectation, not measured hardware schedules.
- EFM thrust vector now rotates the full net engine thrust with sine/cosine, and uses current frame force rather than stale engine values.
- Fixed damage array size/index bound through enumerator index 136.
- Tank callbacks store supplied actual fuel and coordinates. During burn, tank map and total remain synchronized; mass callback represents actual removed/added fuel only. External-first feed and per-station refuel limits are open approximations.
- Engine combustion feedback represents RUNNING vs stopped state.
- Ground speed uses earth-relative velocity, not air-relative wind subtraction.
- Cockpit quantity data sourced from EFM state, not inferred from a fixed 18,078 lb internal full quantity. Barometric and radar altitude intended in feet. Symmetric hydraulic fault inhibit restored to both displayed circuits.
- Pinned Visual Studio 2022 runner instead of `windows-latest`, which migrated to VS 2026.

## Still not implemented or authenticated

- Standalone radar, weapon launch and external guided-weapon integration (F-15C/FC3 remains required).
- Verified cockpit EDM HUD connector, VR conformality, brightness/clipping and suppression of inherited HUD.
- Suspension feedback wired to on-ground state, **but** callback availability, sign conventions and wheel compression must be checked inside DCS; 2-m fallback remains when no feedback is supplied.
- Fully integrated vehicle buses/hydraulics/ECS, engine spool/temperature and calibrated flight-control gain maps.
- Exact late-service HUD tactical cues, F119 engine deck, APG-77 fusion and aircraft aerodynamic coefficients.

## Validation record

GitHub Windows build, modified Lua parsing, and experimental DLL upload passed at [Actions run 40087211369](https://github.com/Ethanw05/DCS-F22/actions/runs/40087211369). In-game and VR verification are still outstanding. Build alone does not validate runtime behavior.

## First in-game tests

1. Run cold, hot, and air starts. Check HUD appears on glass, no doubled inherited HUD, and no error in `dcs.log`.
2. Smooth 90°, 180°, 359° -> 000° turns; verify heading tape continues/wraps and attitude ladder rotates correctly.
3. IAS 99->100 knots and altitude 999->1000 ft pointer rotations; compare moving readouts vs FC/mission sensors.
4. Station partial fill, two tanks, burner consumption and aerial refueling; compare fuel visual state and mass/performance.
5. Hydraulic fault on both engines and battery/generator transitions. EFM still has no physical hydraulic constraints, so instruments are not proof of physical failure handling.

**No CFD or geometry-based aerodynamic fitting was performed.**
