-- GPL-3.0-or-later. Main-display data and one shared four-display router.
dofile(LockOn_Options.script_path..'devices.lua')
dofile(LockOn_Options.script_path..'command_defs.lua')
local dev=GetSelf()
local decode=dofile(LockOn_Options.script_path..'Systems/Input_Value.lua')
local routing=dofile(LockOn_Options.script_path..'Systems/Display_Routing.lua')
local sensor_data=get_base_data()
local update_time_step=.006;make_default_activity(update_time_step)
local parameters = {
    APU_RPM_STATE		      = get_param_handle("APU_RPM_STATE"),
    MAIN_POWER		          = get_param_handle("MAIN_POWER"),
    MFD_OPACITY		          = get_param_handle("MFD_OPACITY"),
    GROUND_ORIDE              = get_param_handle("GROUND_ORIDE"),
    BAY_OPTION                = get_param_handle("BAY_OPTION"), 
    COORD                     = get_param_handle("COORD"),
    ADI_PITCH                 = get_param_handle("ADI_PITCH"),
    FPM                       = get_param_handle("FPM"),
    FUELT                     = get_param_handle("FUELT"),
    FUEL                      = get_param_handle("FUEL"),
    TANK_OPACITY              = get_param_handle("TANK_OPACITY"),
    FCS_RA                    = get_param_handle("FCS_RA"),
    FCS_LA                    = get_param_handle("FCS_LA"),
    FCS_RR                    = get_param_handle("FCS_RR"),
    FCS_LR                    = get_param_handle("FCS_LR"),
    FCS_RE                    = get_param_handle("FCS_RE"),
    FCS_LE                    = get_param_handle("FCS_LE"),
    FCS_LF                    = get_param_handle("FCS_LF"),
    FCS_RF                    = get_param_handle("FCS_RF"),
    FCS_SB                    = get_param_handle("FCS_SB"),
    FCS_LEF                   = get_param_handle("FCS_LEF"),
    LMFD_ENG_PAGE             = get_param_handle("LMFD_ENG_PAGE"),
    LMFD_MENU_PAGE            = get_param_handle("LMFD_MENU_PAGE"),
    LMFD_FCS_PAGE             = get_param_handle("LMFD_FCS_PAGE"),
    LMFD_FUEL_PAGE            = get_param_handle("LMFD_FUEL_PAGE"),
    LMFD_ADI_PAGE             = get_param_handle("LMFD_ADI_PAGE"),
    LMFD_BAY_PAGE             = get_param_handle("LMFD_BAY_PAGE"),
    LMFD_CHECKLIST_PAGE       = get_param_handle("LMFD_CHECKLIST_PAGE"),
    LMFD_SMS_PAGE             = get_param_handle("LMFD_SMS_PAGE"),
    LMFD_HSI_PAGE             = get_param_handle("LMFD_HSI_PAGE"),
    LMFD_PAGE                 = get_param_handle("LMFD_PAGE"),
    RMFD_ENG_PAGE             = get_param_handle("RMFD_ENG_PAGE"),
    RMFD_MENU_PAGE            = get_param_handle("RMFD_MENU_PAGE"),
    RMFD_FCS_PAGE             = get_param_handle("RMFD_FCS_PAGE"),
    RMFD_FUEL_PAGE            = get_param_handle("RMFD_FUEL_PAGE"),
    RMFD_ADI_PAGE             = get_param_handle("RMFD_ADI_PAGE"),
    RMFD_BAY_PAGE             = get_param_handle("RMFD_BAY_PAGE"),
    RMFD_CHECKLIST_PAGE       = get_param_handle("RMFD_CHECKLIST_PAGE"),
    RMFD_RWR_PAGE             = get_param_handle("RMFD_RWR_PAGE"),
    RMFD_HSI_PAGE             = get_param_handle("RMFD_HSI_PAGE"),
    RMFD_PAGE                 = get_param_handle("RMFD_PAGE"),
    CMFD_PAGE                 = get_param_handle("CMFD_PAGE"),
    LMFD_MASK                 = get_param_handle("LMFD_MASK"),
    RMFD_MASK                 = get_param_handle("RMFD_MASK"),
    CMFD_MASK                 = get_param_handle("CMFD_MASK"),
    BAY_STATION               = get_param_handle("BAY_STATION"),
    CMFD_ENG_PAGE             = get_param_handle("CMFD_ENG_PAGE"),
    CMFD_MENU_PAGE            = get_param_handle("CMFD_MENU_PAGE"),
    CMFD_FCS_PAGE             = get_param_handle("CMFD_FCS_PAGE"),
    CMFD_FUEL_PAGE            = get_param_handle("CMFD_FUEL_PAGE"),
    CMFD_ADI_PAGE             = get_param_handle("CMFD_ADI_PAGE"),
    CMFD_BAY_PAGE             = get_param_handle("CMFD_BAY_PAGE"),
    CMFD_CHECKLIST_PAGE       = get_param_handle("CMFD_CHECKLIST_PAGE"),
    CMFD_HSI_PAGE             = get_param_handle("CMFD_HSI_PAGE"),
    DOGFIGHT			      = get_param_handle("DOGFIGHT"),
    CABINPRESS			      = get_param_handle("CABINPRESS"),
    HUD_MODE			      = get_param_handle("HUD_MODE"),
    FCS_AUTO                  = get_param_handle("FCS_AUTO"),
    FCS_MODE                  = get_param_handle("FCS_MODE"),
    FCS_STATE                 = get_param_handle("FCS_STATE"),
    DAY_NIGHT	              = get_param_handle("DAY_NIGHT"),
}

local ground_oride_state=1
local bay_select,left_select_mode,right_select_mode=2,0,0
local PlaneModeBVR,PlaneModeVS,PlaneModeBore,PlaneModeFI0,PlaneRadarOnOff=Keys.PlaneModeBVR,Keys.PlaneModeVS,Keys.PlaneModeBore,Keys.PlaneModeFI0,86
local ui=dofile(LockOn_Options.script_path..'Systems/MFD_Controller.lua').new(get_param_handle,
 function(owner,command,value)dispatch_action(devices[owner],command,value)end,
 function()if sensor_data.getWOW_NoseLandingGear()==1 then ground_oride_state=1-ground_oride_state end end)
local supply_handles={}
local function supply_value(key)
 if not supply_handles[key]then supply_handles[key]=get_param_handle(key)end
 return supply_handles[key]:get()
end
local Supply=dofile(LockOn_Options.script_path..'Systems/Physical_Snapshot.lua')
local display_supply=Supply.new(supply_value,{'MAIN_POWER','BATTERY_POWER','APU_RPM_STATE'})
local function update_display_supply()
 display_supply:update()
 local v=display_supply.values
 local main=display_supply.valid and v.MAIN_POWER==1
 local limited=display_supply.valid and v.MAIN_POWER==0 and v.BATTERY_POWER==1
  and Supply.finite(v.APU_RPM_STATE)and v.APU_RPM_STATE>=2
 ui:update(main,limited)
end
for c=10000,10005 do dev:listen_command(c)end
for _,base in ipairs({10060,10090,10110})do for b=1,20 do dev:listen_command(base+b)end end
for c=10820,10825 do dev:listen_command(c)end
for c=11201,11222 do dev:listen_command(c)end
function post_initialize()
   -- print_message_to_user("MFD SYSTEM POST INIT")
    local bay_option_state = get_aircraft_property("BAY_DOOR_OPTION")--ME Option Box
    local birth_place = LockOn_Options.init_conditions.birth_place

    if birth_place == "GROUND_COLD" then
        parameters.BAY_OPTION:set(bay_option_state) -- Unchecked = 0 Checked = 1
        --lmfd_current_page = 1
		--dev:performClickableAction(right_UFD_swap, 1, false)
    elseif birth_place == "GROUND_HOT" or birth_place == "AIR_HOT" then
        ground_oride_state = 0
        set_aircraft_draw_argument_value(600,0)
		set_aircraft_draw_argument_value(601,0)
		set_aircraft_draw_argument_value(602,0)
		--UFD_KNOB:set(0.5)
		--dispatch_action(nil,Battery)
        --lmfd_current_page = 1
		--print_message_to_user("HOT START")
    end
    --Option Checkbox
    if bay_option_state == 1 then
        ground_oride_state = 0
        --print_message_to_user("OPTIONSET")
	end
end
function SetCommand(command,value)
 local down=decode(value,devices.MFD_SYSTEM)>0
 update_display_supply()
 if command>=11201 and command<=11220 then ui:button(4,command-11200,down);return end
 if command==11221 then if down then ui:select(4,routing.pages.menu)end;return end
 if command==11222 then return end
 for panel,base in ipairs({10060,10090,10110})do
  for b=1,20 do
   if command==base+b or command==device_commands['Button_'..((panel-1)*20+b)]then
    ui:button(panel,b,down)
    if command==base+b and value==1 then ui:button(panel,b,false)end -- down-only legacy input alias
    return
   end
  end
 end
 if not down then return end
 if command==10820 or command==10821 then ui:cycle(command==10820 and 1 or 2);return
 elseif command==10822 then ui:select(3,routing.pages.stores);return
 elseif command==10823 then ui:select(3,routing.pages.nav);return
 elseif command==10824 then ui:select(1,routing.pages.menu);return
 elseif command==10825 then ui:select(4,routing.pages.tsd);return end
 -- Master-mode changes preserve the pilot's display arrangement.
    --Bay Select : BAY STATION 1-left 2-center 3-right 4-all --MFD PAGES   0=MENU, 1=ENG, 2=FCS, 3=FUEL, 4=ADI, 5=BAY, 6=CHKLIST, 7=SMS, 8=HSI
        if command == 10004 and bay_select < 4 then
            bay_select = (bay_select + 1)
        elseif command == 10004 and bay_select == 4 then
            bay_select = 1
        end
    --Left Bay Multi Modes
        if command == 10000 and bay_select ~= 1 then --Left Bay select
            bay_select = 1
            left_select_mode = 1
            right_select_mode = 0
            dispatch_action(nil,PlaneModeFI0)--FC3 Keybind press 6
            dispatch_action(nil,PlaneRadarOnOff)
        elseif command == 10000 and bay_select == 1 and left_select_mode == 1 then --Left Bay select
            bay_select = 1
            left_select_mode = 2 --bore
            dispatch_action(nil,PlaneModeBore)--FC3 Keybind press 4
            --dispatch_action(nil,PlaneRadarOnOff)--FC3 Keybind press I
        elseif command == 10000 and bay_select == 1 and left_select_mode == 2 then --Left Bay select
            bay_select = 1
            left_select_mode = 3 --VS
            dispatch_action(nil,PlaneModeVS)--FC3 Keybind press 3
            --dispatch_action(nil,PlaneRadarOnOff)--FC3 Keybind press I
        elseif command == 10000 and bay_select == 1 and left_select_mode == 3 then --Left Bay select
            bay_select = 1
            left_select_mode = 1 --Flood
            dispatch_action(nil,PlaneModeFI0)--FC3 Keybind press 6
            dispatch_action(nil,PlaneRadarOnOff)--FC3 Keybind press I
    --Right Bay Multi Modes       
        elseif command == 10001 and bay_select ~= 3 then
            bay_select = 3
            left_select_mode = 0
            right_select_mode = 1
            dispatch_action(nil,PlaneModeFI0)--FC3 Keybind press 6  
            dispatch_action(nil,PlaneRadarOnOff)
        elseif command == 10001 and bay_select == 3 and right_select_mode == 1 then
            bay_select = 3
            right_select_mode = 2
            dispatch_action(nil,PlaneModeBore)--FC3 Keybind press 4
            --dispatch_action(nil,PlaneRadarOnOff)
        elseif command == 10001 and bay_select == 3 and right_select_mode == 2 then
            bay_select = 3
            right_select_mode = 3
            dispatch_action(nil,PlaneModeVS)--FC3 Keybind press 3
            --dispatch_action(nil,PlaneRadarOnOff)
        elseif command == 10001 and bay_select == 3 and right_select_mode == 3 then
            bay_select = 3
            right_select_mode = 1
            dispatch_action(nil,PlaneModeFI0)--FC3 Keybind press 6  
            dispatch_action(nil,PlaneRadarOnOff)
    --Center Bay        
        elseif command == 10002 and bay_select ~= 2 then
            bay_select = 2
            dispatch_action(nil,PlaneModeBVR)--FC3 Keybind press 2
            --dispatch_action(nil,PlaneRadarOnOff)  
        elseif command == 10003 and bay_select ~= 4 then
            bay_select = 4
            dispatch_action(nil,PlaneModeBVR)--FC3 Keybind press 2
            --dispatch_action(nil,PlaneRadarOnOff)  
        end

end
function update()
 update_display_supply()
 local now
 if type(get_model_time)=='function'then
  local ok,value=pcall(get_model_time)
  if ok and Supply.finite(value)then now=value end
 end
 local stamp=get_param_handle('F22_DEF_OV_TIME'):get()
 local fresh=ui.powered and Supply.finite(now)and Supply.finite(stamp)
  and get_param_handle('F22_DEF_OV_VALID'):get()==1 and now>=stamp and now-stamp<=.25
 get_param_handle('F22_DEF_OV_CURRENT'):set(fresh and 1 or 0)
    local cabin_pressure = get_cockpit_draw_argument_value(114)
    parameters.GROUND_ORIDE:set(ground_oride_state)
    parameters.BAY_STATION:set(bay_select)
    parameters.CABINPRESS:set(cabin_pressure)
------------------------------------------------------------------FCS PAGE UPDATE---------------------------------------------------------------------------------------------------
    local right_flap                = get_aircraft_draw_argument_value(9)
    local left_flap                 = get_aircraft_draw_argument_value(10)
    local right_aileron             = get_aircraft_draw_argument_value(11)
    local left_aileron              = get_aircraft_draw_argument_value(12)
    local right_elevator            = get_aircraft_draw_argument_value(15)
    local left_elevator             = get_aircraft_draw_argument_value(16)
    local right_rudder              = get_aircraft_draw_argument_value(17)
    local left_rudder               = get_aircraft_draw_argument_value(18)
    local speed_brake               = get_aircraft_draw_argument_value(182)
    local lef                       = get_aircraft_draw_argument_value(603)

    parameters.FCS_RA:set(right_aileron)
    parameters.FCS_LA:set(left_aileron)
    parameters.FCS_RE:set(right_elevator)
    parameters.FCS_LE:set(left_elevator)
    parameters.FCS_RR:set(right_rudder)
    parameters.FCS_LR:set(left_rudder)
    parameters.FCS_RF:set(right_flap)
    parameters.FCS_LF:set(left_flap)
    parameters.FCS_SB:set(speed_brake)
    parameters.FCS_LEF:set(lef)
------------------------------------------------------------------FUEL PAGE UPDATE---------------------------------------------------------------------------------------------------
------------------------------------------------------------------ADI PAGE UPDATE---------------------------------------------------------------------------------------------------
    -- Route navigation is owned by Navigation_System; no inherited HSI arguments.
------------------------------------------------------------------FCS PAGE LOGIC---------------------------------------------------------------------------------------------------------

    if parameters.FUEL:get() >= 13456 then
        parameters.TANK_OPACITY:set(1)
    else
        parameters.TANK_OPACITY:set(0)
    end
------------------------------------------------------------------FUEL PAGE LOGIC--------------------------------------------------------------------------------------------------------
------------------------------------------------------------------ADI PAGE LOGIC---------------------------------------------------------------------------------------------------------
------------------------------------------------------------------HSI PAGE LOGIC---------------------------------------------------------------------------------------------------------
------------------------------------------------------------------BAY PAGE LOGIC---------------------------------------------------------------------------------------------------------
end
need_to_be_closed=false
