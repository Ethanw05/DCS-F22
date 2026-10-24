# Hydraulic display pressure proxy: elapsed-time and hot-start corrections

Read [original 08 vehicle audit](../../docs/audit/08-vehicle-systems.md) and [Boeing F-22 avionics integration statement](https://boeing.mediaroom.com/1998-01-29-Boeing-Begins-Integrating-F-22-Fighters-Advanced-Avionics). The source supports integrated vehicle management, not an exposed F-22 hydraulic plumbing/pressure deck.

## Confirmed direct code defects
- `MFD_System.lua` assigned startup `L_HYD_VALUE` and `R_HYD_VALUE` = 3950 for hot starts but left the local `l_hyd_value`/`r_hyd_value` at 0. Next frame overwrote the indications with zero.
- Pressure ramp changed exactly 5 units/callback regardless of elapsed time. Other systems use time-based rates.
- Original right hydraulic engine branch ignored the shared fault flag; that was corrected in the previous overhaul pass. This pass keeps both channels symmetrical and bounded.
- Local pressure was written to parameters before computing its update, causing a one-frame stale indication.

## Implemented
Initialize local and published pressure to 3950 in hot start, 0 for cold; integrate toward 3950 or zero with `maxChange=(5/0.006)*update_time_step`, clamp to [0,3950], and publish after integration. Pressures are **display proxies**, not modeled pumps/accumulators. The 3950 and rates reflect existing mod settings, *not* a validated production F-22 hydraulic system.

## Still required
- Real physical hydraulic subsystem owning independent left/right pressure, fluid quantity/leakage, pump and actuator load; EFM surfaces, flight controls, TVC, gear, bay and gun-door effects coupled to availability.
- Host failures and engine RPM units validated in DCS. Battery/APU recovery and alternate hydraulic power not simulated.
- Test hot-start initialization, left/right engine spool-up, asymmetric engine shutdown, fault flag while both RPM>45, callback cadence changes and zero/maximum saturation. Confirm `HYD_LIGHT` and failure annunciators persist when screens dim.
