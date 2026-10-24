# Vehicle power, APU and engine-clam ownership

## References before implementation

- [Boeing 1998 initial avionics integration announcement](https://boeing.mediaroom.com/1998-01-29-Boeing-Begins-Integrating-F-22-Fighters-Advanced-Avionics): vehicle management, power controls, cockpit displays and simulated engine integration are separate coordinated subsystems.
- [Boeing 1999 Block 1.2 integration announcement](https://boeing.mediaroom.com/1999-12-13-Boeing-Delivers-Updated-F-22-Integrated-Avionics-Package): includes vehicle management, subsystems/utilities and engine run integration; no disclosed production APU auto-off timer, ignition ramp or bus electrical diagram.
- [Project 08-vehicle audit](../../docs/audit/08-vehicle-systems.md): documented interrupted APU timer, competing engine-clam animation writers and stale power publications.
- [Project 05-engine audit](../../docs/audit/05-engines.md): mixed cutoff animated throttle failure.

## Direct corrections

1. A common throttle axis (command 2004) now independently updates the left and right lever according to its own cutoff. This eliminates the both-on/both-off assumption.
2. APU RPM proxy is clamped [0,4] and updates with elapsed `dt`. The old nominal 0.01/0.024 s ramp is retained as a **mod approximation**, not validated F-22 APU data.
3. `APU_POWER` and `APU_RPM_STATE` now publish the model's current-tick state after the update rather than relying only on the prior-tick snapshot.
4. APU auto-off requires an uninterrupted 60 s while both engines are above the local readiness threshold and at least one generator is supplying power. Interruptions reset the timer. This 60-s delay is an **existing mod gameplay choice**, not derived from Boeing's press releases.
5. Engine-clam animations 610 (right) / 611 (left) are no longer driven from `Engine_System.lua` updates; EFM `ed_fm_set_draw_args_v2` is their single writer. The cold-start initializer still sets a compatible starting state.
6. Clickable connector updates are guarded against an unavailable reference, preventing an unnecessary Lua runtime exception.

## Not accomplished

The cockpit model still has simplified battery/APU/generator availabilities, **not** a physically modeled electrical bus, ECS/oil/hydraulic system or native independent engine start controller. EFM engine start conditions are separately owned and should eventually share a contract with this device.

**DCS tests required**: cold/hot/air starts; mixed cutoff, dual throttle; APU interruption before auto-off; one/two generator supply; battery loss mid-spool; gun/bay/gear actuator effect on available power; EFM/EDM clamshell visuals; clickable control missing/reloaded.
