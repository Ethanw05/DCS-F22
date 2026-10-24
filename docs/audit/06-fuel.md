# 06 — Fuel, mass, tanks and refueling

## Applicable resources

| Reference | Application | Limit |
| --- | --- | --- |
| [R29](../RESOURCES.md#r29), [R153](../RESOURCES.md#r153) | Official approximate internal capacity. | Summary values, not tank geometry, usable-fuel or transfer schedules. |
| [R81](../RESOURCES.md#r81), [R125](../RESOURCES.md#r125) | Engine integration and pilot perspective on refueling configuration. | No detailed fuel plumbing, pump logic or inertia model. |
| [R86](../RESOURCES.md#r86) and bundled EFM API | Implementation examples and mass-change callback contract. | Example code is not evidence of aircraft behavior. |

## Code scope and findings

Reviewed internal/external callbacks, consumption, mass-change queue, refueling permission, tank loadout and cockpit quantity derivation. Fuel is in kg internally; cockpit quantities require explicit conversion and source identification.

- **FUEL01 — C/R:** [Refueling](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/EFM/source/RAPTOR.cpp#L1589) limits a callback with a hardcoded 0.006-second step, adds ten times the calculated internal amount, but queues mass for only the unmultiplied amount. With internal fuel 8199.8 kg, capacity 8200 and callback amount 0.6, unchanged expressions produce **8201.8 kg**, while only **0.2 kg** is queued as added mass. Clamp the accepted amount once and use that same amount everywhere.
- **FUEL02 — C/R:** [External initialization](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/EFM/source/RAPTOR.cpp#L1246) replaces the first positive station quantity with 1850 kg. A callback reporting 100 kg therefore stores 1850. Respect the host quantity and distinguish initialization from updates; an empty station is also a valid state.
- **FUEL03 — C/R:** External burning changes the aggregate without decrementing individual station quantities or emitting matching fuel mass changes. Starting at 1850, a 1.5 kg burn gives aggregate 1848.5 while its station remains 1850. Rebuilding the aggregate when another station arrives can restore consumed fuel. Keep a single tank ledger and derive totals.
- **FUEL04 — C/R:** Near exhaustion, requested consumption and actual removed quantity differ. Internal quantity 0.1 kg and a 1.5 kg demand can queue a 1.5 kg mass loss although only 0.1 kg exists. Engine starvation and mass callbacks must use actual supplied fuel.
- **FUEL05 — C/R:** `reset_fm_state()` leaves the mass-change queue populated. An isolated callback check queued one event and still found it after reset. Explicitly clear pending events on the appropriate lifecycle boundary and test that resetting does not create or remove fuel twice.
- **FUEL06 — C:** Tanker-acceptance export is always true, separate from Lua door/readiness indications. External refueling ignores supplied station coordinates in initialization and does not add corresponding external mass events in its refuel branch. Host ownership must be established before choosing which callback owns mass, CG and inertia changes.
- **FUEL07 — C/I:** [Tank definition](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/VLO%20Fuel%20Tank.lua) implies approximately 1865.8 kg from 605 US gallons and its density conversion; EFM assumes 1850 kg/station. Document usable fuel, density, adapter/dry mass and station numbering together. This discrepancy alone does not establish the real tank capacity.
- **FUEL08 — C:** [Avionics](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/Cockpit/Scripts/Systems/Avionics.lua#L196) derives external fuel by subtracting a fixed full-internal quantity from total fuel, rather than using tank quantities. Partial internal fuel invalidates that assumption and can yield negative external indications. Unlimited-fuel mode skips consumption updates and needs a separate truthful flow indication policy.

## Proposed rewrite and future acceptance

Build one conservative fuel ledger: actual accepted supply, actual burn, tank quantities/positions and queued mass/inertia changes. Define DCS ownership explicitly so native tank changes are not counted twice. Physical transfer logic remains an openly documented approximation until supported by reliable aircraft evidence.

Later check partial tanks, two-station callback order, empty tanks, jettison, refueling at capacity, repeated callbacks, external-to-internal supply, near-empty shutdown, unlimited fuel and aircraft respawn. Assert quantity/mass conservation and cockpit agreement. Existing numbers above are isolated callback reproductions, not in-DCS refueling tests.
