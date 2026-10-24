# 03 — Flight controls and allocation

## Applicable resources

| Reference | Application | Limit |
| --- | --- | --- |
| [R20](../RESOURCES.md#r20), [R125](../RESOURCES.md#r125) | Pilot-command behavior, smooth transitions and handling-quality evaluation. | Development descriptions/lecture material do not publish complete production gains. |
| [R126](../RESOURCES.md#r126), [R22](../RESOURCES.md#r22) | Effector authority and distributed speedbraking. | Historical no-load bounds and EMD configuration. |
| [R155](../RESOURCES.md#r155), [R159–R161](../RESOURCES.md#r159) | Vehicle-management boundaries, integrated controls, allocation and fault reconfiguration. | Supporting methods; some studies use aircraft/nozzle arrangements unlike the F-22. |

## Code scope and findings

Reviewed [RAPTOR.cpp:390–653](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/EFM/source/RAPTOR.cpp#L390), input/trim cases, mode state, actuator schedules and the inactive Lua FCS.

- **FCS01 — C/I:** Pitch uses squared stick input, rate damping and trim plus an after-the-fact g correction. Roll and yaw use separate nonlinear shaping/damping. This is a custom simplified law, not recovered F-22 flight-control software. Define pilot-command meaning and response targets before selecting new gains.
- **FCS02 — C/R:** [Roll/yaw trim commands](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/EFM/source/RAPTOR.cpp#L1064) change `roll_trim`/`yaw_trim`, but neither enters the active control or force path. The extracted callback experiment stored +0.001 roll/-0.001 yaw trim with **zero change in all three moments** under otherwise identical initialized conditions. Restore real control behavior or label unsupported inputs; do not leave a functional-looking binding inert.
- **FCS03 — C:** [Flap commands](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/EFM/source/RAPTOR.cpp#L1190) change `flaps_switch`, but the automatic schedule reads ground/gear/speed state instead. Manual command semantics are therefore disconnected. Decide whether the intended interface is automatic-only, override or a scheduled manual request.
- **FCS04 — C/I:** Positive/negative g constants (+11/-4) disagree with the AI definition and indexed official +9 g headline. Full transient limits are not public here. Define a documented approximation with verified normal-acceleration convention and configuration/weight effects.
- **FCS05 — C/I:** Normal/approach/refueling modes are not explicit controller states. Gear-dependent TV correction and trim fades substitute for a full command/mode contract. Blend transitions with hysteresis and preserve integrator state deliberately; do not impose prototype-era transition behavior on production F-22 handling.
- **FCS06 — C/I:** The same roll command is mixed into differential elevons and used for additional aileron forces without a centralized allocation target. Surface saturation can change combined pitch/roll authority. Use one allocation stage with physical position/rate/health limits and anti-windup.
- **FCS07 — C:** [`Systems/FCS.lua`](https://github.com/Ethanw05/DCS-F22/blob/9c5d03ee822323591dbf259d09b5022ced3e3d4f/Cockpit/Scripts/Systems/FCS.lua#L119) is not created by `device_init.lua`; its name does not establish an active second controller. Retire or document the dormant file during implementation, rather than repairing it as though it governs current flight.

## Proposed rewrite and future acceptance

Separate input conditioning, pilot-command model, mode logic, envelope protection, control allocation, actuators and airframe response. Track commanded and achieved authority, including engine-out/TVC limitations. Use source-informed handling goals rather than promising a specific control-law algorithm is authentic.

Validate trim release, small/large doublets, stick centering, roll reversals, command saturation/recovery, gear/refueling transitions and failed effectors. Evaluate latency and PIO susceptibility under demanding tracking tasks. Test the controller and aerodynamic model together after fuel/thrust bookkeeping is corrected; avoid adding arbitrary gain until a symptom disappears.
