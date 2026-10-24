# 15 — Navigation, autopilot and communications

## Applicable resources

| Reference | Application | Limit |
| --- | --- | --- |
| [R09](../RESOURCES.md#r09), [R104](../RESOURCES.md#r104) | Integrated navigation/CNI roles and software-defined CNI context. | Not complete radio waveforms, INS error specifications or actual software interfaces. |
| [R20](../RESOURCES.md#r20), [R125](../RESOURCES.md#r125) | Flight-control command/mode behavior. | No full production autopilot gains or complete mode priority table. |
| [R148–R152](../RESOURCES.md#r148) | Independent DCS device integration and limits. | Examples can contain compiled components and reuse restrictions; not a supported complete SDK. |
| [R154–R155](../RESOURCES.md#r154) | Mission/vehicle computation boundaries. | Architecture studies do not provide an aircraft navigation implementation. |

## Code scope and findings

Reviewed ICP handler, HSI pages and MFD source reads, native navigation/autopilot dispatch, custom EFM input declarations, `comm.lua`, input profiles and view/kneeboard integration.

- **NAV01 — C:** HSI values come from legacy cockpit draw arguments including 27/28/32/35/36/140/141/267–270/275–278/501. These are a dependency on inherited instrument state, not own navigation solutions. Record each argument's current meaning before replacing the data source; animations are not stable avionics interfaces.
- **NAV02 — C:** There is no own waypoint database, route sequencing, coordinate-entry transaction, INS alignment/drift or navigation validity model. STPT opens the kneeboard and numeric ICP keys do not implement entry. An independent navigation stack needs a bounded first scope rather than promising the entire production mission computer.
- **NAV03 — C:** ICP altitude/attitude/cancel controls dispatch native autopilot commands. EFM custom autopilot identifiers exist without active command cases; associated bindings are commented. These are different paths, and neither constitutes an independent active autopilot implementation in this source.
- **NAV04 — I:** Mode status should come from the engaged controller, not from a brief menu/selection flag. Define command acceptance, trim interaction, manual override, disengagement/fault behavior, saturation and integrator resets before adding new holds.
- **NAV05 — C:** COM1 opens the native radio menu; COM2 opens rearm. `comm.lua` and aircraft radio settings do not create independent powered/tunable radios with devices, audio and multiplayer behavior. Replacing inherited avionics must include the native communications boundary, not only a frequency text field.
- **NAV06 — C/U:** Native waypoint and autopilot commands can change state outside local menu handlers. Later verify keyboard/HOTAS/clickable synchronization, heading conventions, true versus magnetic reference, geographic transformations and the host APIs available to independent radios/navigation. Avoid guessing `get_base_data()` units from variable names.

## Proposed rewrite and future acceptance

Own navigation should publish position/velocity/attitude validity, route state and guidance, with a deliberately documented sensor-error scope. An autopilot should consume those signals and the established FCS command model, with annunciations reflecting actual engagement. Radio integration must be proven separately using permitted native interfaces or properly licensed components.

Later tests: waypoint edit/undo/sequence, wrap and geographic boundaries, navigation loss/restoration, mode capture versus hold, trim/manual override, power and hydraulic loss, route guidance with wind, radio menu/transmit/audio and multiplayer interoperability with FC disabled. Accurate production INS drift, classified waveform behavior and complete real F-22 CNI management remain outside the evidence collected here. No autopilot or radio implementation was added.
