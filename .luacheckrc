-- Lua 5.1, luacheck 1.2.0. Vehicle device host entry points and DCS globals.
std = "lua51"
max_line_length = 120
globals = {"post_initialize", "CockpitEvent", "SetCommand", "update",
    "need_to_be_closed", "createExternal", "playSoundOnce", "stopSound",
    "createExternalLoop", "stopLoopSound", "updateLoopSoundParameters",
    "playSoundOnceFromParam", "playLoopingSound", "playLoopingSoundFromParam",
    "sound", "sound_apu"}
read_globals = {"GetSelf", "LockOn_Options", "make_default_activity",
    "get_param_handle", "get_base_data", "Keys", "device_commands",
    "get_cockpit_draw_argument_value", "get_aircraft_draw_argument_value",
    "set_aircraft_draw_argument_value", "dispatch_action",
    "create_sound_host", "get_clickable_element_reference", "print_message_to_user",
    "updateSoundParameters"}
