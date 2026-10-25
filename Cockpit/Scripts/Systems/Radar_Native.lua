-- GPL-3.0-or-later. DCS shared sensor backend, not an APG-77 performance model.
-- Configuration keys verified in the installed CockpitBase initialize routine.
export_prefix = "F22N_"
link_to_target_responder = true
power_bus_handle = "F22_RADAR_SUPPLY"
render_debug_info = false
perfomance = {
    tracking_azimuth={math.rad(-60),math.rad(60)},
    roll_compensation_limits={math.rad(-70),math.rad(70)},
    pitch_compensation_limits={math.rad(-8),math.rad(25)},
    scan_volume_azimuth=math.rad(60),scan_volume_elevation=math.rad(20),
    scan_beam=math.rad(3),max_available_distance=160*1852,
}
need_to_be_closed=true
