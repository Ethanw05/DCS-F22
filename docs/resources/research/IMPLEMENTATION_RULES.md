# Evidence-led implementation sequence and validation

For **each** subsystem:

1. Read the exact live source files and DCS contract (not the last audit alone); identify active vs unregistered code.
2. Re-open the *applicable* official or military source(s), record exact claim, page/figure, aircraft configuration and limitations.
3. Write an acceptance test or executable invariant first (e.g., fuel mass conservation across a sequence, timed actuator rate, or pointer wrap).
4. Implement one coherent change, preserve existing GPL attribution and DCS API compatibility.
5. Run repeatable tests/syntax/static checks. If DCS execution is unavailable, say so; never label a runtime-dependent change 'verified'.
6. Update the audit finding status, document assumptions and list remaining test scenarios before moving to the next system.

| System | Source order | Minimum check |
|---|---|---|
| HUD and displays | N01/N02 → N09/N10 → N11/N15 → existing R sources | Distinct circular counters; real cockpit anchor; readable/VR, dynamic horizon, valid units and power |
| Flight controls/TVC | Existing R65/R126 and primary F-22 sources → Allerton generic controller methods | dt-independent actuation; vector norm; asymmetric failure; smooth control response |
| Fuel/propulsion | Current API and official fuel capacity/integration sources → generic conservation | quantity/mass agreement for every tank, engine fuel-supply availability, no negative fuel |
| Electrical/APU/vehicle systems | Boeing N13 and project engine/electrical audits | hot/cold/air starts, power transitions, coherent annunciation |
| Sensors/weapons | N14 program era only; DCS host API primary; no speculative radar performance | capability truthfulness, no nonfunctional target/launch labels |
| Build/integration | DCS bundled EFM headers and existing CI | compile, load, no missing cockpit connectors/parameter handles |

No CFD or fit to an inaccurate 3D mesh. Avoid hardcoding prohibited/unpublished or invented F-22 characteristics. The external F-15C/FC3 avionics requirement is an independent integration task: do not remove the dependency until replacement sensor and guided-weapon integration passes DCS testing.
