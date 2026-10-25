# A/G point-mass impact estimator for HUD testing

## Research actually applied

- [NASA ballistic equations](https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/ballistic-flight-equations/): x(t)=vₓt and h(t)=h₀+vᵥt−(1/2)gt² under constant gravity and **zero aerodynamic drag**.
- [NASA aerodynamic drag equations](https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/flight-equations-with-drag/): explains why an unguided gravity-only estimate will differ from a real bomb and cannot be used as a combat solution.
- [US Navy T-45C CCIP weapons-training illustration](https://navyflightmanuals.tpub.com/P-1209/Figure-17-Hud-A-G-Ccip-Bomb-Display-Typical-31.htm): CCIP presentation uses the weapon's own parameters, atmospheric conditions, drift and aiming line. This simulated cue is **not that certified solution**.
- [DCS cockpit terrain API](https://modding.caffeinesimulations.com/Aircraft/Lua/Modules/Terrain/): `require("terrain")`, `GetHeight(x,z)` meters, world-coordinate convention.

## What the code actually does

The `AG_Ballistic_Computer.lua` cockpit device estimates north/east/up **ground velocity** from successive real DCS ownship coordinates, rejects invalid/discontinuous samples, then finds where a hypothetical object released at that velocity would intersect the game map under constant standard g=9.80665 m/s². `Ballistic_Point_Mass.lua` samples trajectory at 0.25-s steps, bisection-refines impact time, returns predicted terrain intersection and fall time. HUD only draws the on-screen cue during A/G submode 2, and labels it **CCIP SIM / SIM NO DRAG**; no release consent, launch automation or target coordinate uplink occurs.

This does not know selected weapon, drag, aerodynamic tumbling, ballistics, station release impulse, altitude/temperature profile, wind drift, radar ranging errors, GPS weapon guidance, JDAM steering or target laser state. Thus it is **not** a valid F-22 production CCIP or guided-bomb trajectory. The F-22A stock GBU-32 remains experimental. If terrain/velocity isn't available, the HUD displays EST UNAVAILABLE and never invents a point.

## Test plan

- Pure Lua 5.1 impact solver numerics for flat ground, rising terrain and invalid input.
- In DCS: positive altitude and forward speed, maneuvering aircraft, crosswind, under/over shallow dive; compare simulated CCIP *qualitatively* with simple gravity trajectories. DO NOT compare this gravity-only predictor to precision-guided JDAM accuracy or declare it weapons-ready.
- Verify submode and power gating. Check performance of terrain queries and frame rate; solver runs 10Hz with <=200 terrain probes per solution.
