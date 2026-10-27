# Hot-start electrical switches and generator qualification

Read [vehicle power audit](../../audit/README.md#retired-report-a08) with [Boeing's 1998 public F-22 avionics integration announcement](https://boeing.mediaroom.com/1998-01-29-Boeing-Begins-Integrating-F-22-Fighters-Advanced-Avionics). Boeing confirms integrated vehicle/power control roles; the release does not disclose production generator trip/RPM thresholds or electrical diagrams.

- Hot initialization previously dispatched `PowerOnOff` directly, then performed a battery clickable that also dispatches `PowerOnOff`. The direct duplicate dispatch is removed; the clickable owns it.
- Generator proxy is controlled by switch and measured engine RPM with on ≥61%, off <59% hysteresis. Values are **mod approximations**, not authenticated F-22 protection schedules.
- The `createExternalLoop` helper now uses local variables for start/loop/end sound objects to avoid reusing global Lua state.
- See [previous APU/state-owner work](ENGINE_VEHICLE_APU_OWNER.md).

In-DCS tests still necessary: hot/cold/air initialization, independent generators, RPM transitions, battery loss, simultaneous keyboard/clickable commands, APU interruption and audio.
