--[[
    Grinnelli Designs F-22A Raptor
    Copyright (C) 2024, Joseph Grinnelli
    
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    
    You should have received a copy of the GNU General Public License
    along with this program.  If not, see https://www.gnu.org/licenses.
--]]


local dev = GetSelf()
local sensor_data = get_base_data()
local EngineIndications = dofile(LockOn_Options.script_path..'Systems/Engine_Indications.lua')
local engine_indications = EngineIndications.new(get_param_handle)
local left_rpm_valid = get_param_handle('F22_ENGINE_L_RPM_VALID')
local right_rpm_valid = get_param_handle('F22_ENGINE_R_RPM_VALID')
local fault_registry_ready = get_param_handle('F22_FAULT_REGISTRY_READY')
local master_attention = get_param_handle('F22_MASTER_ATTENTION')
local reference_handles={}
local function reference_handle(key)
 if not reference_handles[key]then reference_handles[key]=get_param_handle(key)end
 return reference_handles[key]
end
local attitude_references=dofile(LockOn_Options.script_path..'Systems/Attitude_References.lua').new(
 function(key)return reference_handle(key):get()end,
 function(key,value)reference_handle(key):set(value)end)
local function altitude_read(key)return reference_handle(key):get()end
local Side=dofile(LockOn_Options.script_path..'Systems/Side_Indications.lua')
local side=Side.new(altitude_read,function(key,value)reference_handle(key):set(value)end,sensor_data)
local altitude_physical=dofile(LockOn_Options.script_path..'Systems/Physical_Snapshot.lua').new(altitude_read,Side.fields)
local Altitude=dofile(LockOn_Options.script_path..'Systems/Altitude_Snapshot.lua')
local altitude_frame=Altitude.new(altitude_read)
local baro_current=get_param_handle('F22_SIDE_BARO_VALID')
baro_current:set(0)

dofile(LockOn_Options.script_path.."devices.lua")
dofile(LockOn_Options.script_path.."command_defs.lua")

local update_rate = 0.006 --0.006
make_default_activity(update_rate)

local parameters =
{
	-- Engine
	APU_POWER			 = get_param_handle("APU_POWER"),
	APU_RPM_STATE		 = get_param_handle("APU_RPM_STATE"),
	BATTERY_POWER		 = get_param_handle("BATTERY_POWER"),
	MAIN_POWER		     = get_param_handle("MAIN_POWER"),
	L_GEN_POWER			 = get_param_handle ("L_GEN_POWER"),
	R_GEN_POWER			 = get_param_handle ("R_GEN_POWER"),

	-- Indicator
	UFD_OPACITY		     = get_param_handle("UFD_OPACITY"),
	MFD_OPACITY		     = get_param_handle("MFD_OPACITY"),
	ICP_OPACITY		     = get_param_handle("ICP_OPACITY"),
	R_ADI_OPACITY     	 = get_param_handle("R_ADI_OPACITY"),
	R_WAR_OPACITY 		 = get_param_handle("R_WAR_OPACITY"),
	L_ADI_OPACITY     	 = get_param_handle("L_ADI_OPACITY"),
	L_WAR_OPACITY 		 = get_param_handle("L_WAR_OPACITY"),
	ADI_PITCH 		     = get_param_handle("ADIPITCH"),
	ADI_ROLL			 = get_param_handle("ADIROLL"),
	BARO 				 = get_param_handle("BAROALT"),
	RPM_L                = get_param_handle("RPM_L"),
	RPM_R                = get_param_handle("RPM_R"),
	EGT_L                = get_param_handle("EGT_L"),
	EGT_R                = get_param_handle("EGT_R"),
	FUELL                = get_param_handle("FUELL"),
	FUEL                 = get_param_handle("FUEL"),
	FUELT                = get_param_handle("FUELT"),
	FUELTANK             = get_param_handle("FUELTANK"),
	FLOOD_LIGHT 		 = get_param_handle("FLOOD_LIGHT"),
	PANEL_LIGHT 		 = get_param_handle("PANEL_LIGHT"),	
	CANOPY_LIGHT 		 = get_param_handle("CANOPY_LIGHT"),	
	SPD_BRK_LIGHT 	     = get_param_handle("SPD_BRK_LIGHT"),	
	BINGO_LIGHT   	     = get_param_handle("BINGO_LIGHT"),	
	FLAPS_MOVE 		     = get_param_handle("FLAPS_MOVE"),	
	FLAPS_DOWN		     = get_param_handle("FLAPS_DOWN"),	
	AAR_LIGHT 		     = get_param_handle("AAR_LIGHT"),	
	L_FIRE_LIGHT 		 = get_param_handle("L_FIRE_LIGHT"),	
	R_FIRE_LIGHT 		 = get_param_handle("R_FIRE_LIGHT"),	
	L_GEN_OUT 		     = get_param_handle("L_GEN_OUT"),	
	R_GEN_OUT 		     = get_param_handle("R_GEN_OUT"),	
	HYD_LIGHT 		     = get_param_handle("HYD_LIGHT"),	
	CAUTION_LIGHT		 = get_param_handle("CAUTION_LIGHT"),	
	OIL_LIGHT			 = get_param_handle("OIL_LIGHT"),
	APU_READY			 = get_param_handle("APU_READY"),
	APU_SPOOL			 = get_param_handle("APU_SPOOL"),
	L_OIL_COLOR	     	 = get_param_handle("L_OIL_COLOR"),
	R_OIL_COLOR	     	 = get_param_handle("R_OIL_COLOR"),
	L_HYD_COLOR			 = get_param_handle("L_HYD_COLOR"),
	R_HYD_COLOR			 = get_param_handle("R_HYD_COLOR"),

	LMFD_MENU_PAGE       = get_param_handle("LMFD_MENU_PAGE"),
	LMFD_FCS_PAGE        = get_param_handle("LMFD_FCS_PAGE"),
	LMFD_FUEL_PAGE       = get_param_handle("LMFD_FUEL_PAGE"),
	LMFD_ADI_PAGE        = get_param_handle("LMFD_ADI_PAGE"),
	LMFD_BAY_PAGE        = get_param_handle("LMFD_BAY_PAGE"),
	LMFD_CHECKLIST_PAGE  = get_param_handle("LMFD_CHECKLIST_PAGE"),
	LMFD_SMS_PAGE        = get_param_handle("LMFD_SMS_PAGE"),
	LMFD_HSI_PAGE        = get_param_handle("LMFD_HSI_PAGE"),
 	LMFD_PAGE            = get_param_handle("LMFD_PAGE"),
	LMFD_MASK            = get_param_handle("LMFD_MASK"),
	RMFD_MASK            = get_param_handle("RMFD_MASK"),
	PMFD_MASK            = get_param_handle("PMFD_MASK"),
	DAY_NIGHT	         = get_param_handle("DAY_NIGHT"),
    EFM_INTERNAL_FUEL_KG = get_param_handle("EFM_INTERNAL_FUEL_KG"),
    EFM_EXTERNAL_FUEL_KG = get_param_handle("EFM_EXTERNAL_FUEL_KG"),
	HUD_POWER = get_param_handle("HUD_POWER"),
}

local day_night = 0
local mfd_brightness_knob = 1
local ufd_brightness_knob = 1
local startup_diagnostic_ticks = 0

-- Clickable data
local MFD_KNOB_mouse   = device_commands.Button_3 -- Track mouse scroll
local UFD_KNOB_mouse   = device_commands.Button_4  -- Track mouse scroll
local day_night_switch = device_commands.Button_8  -- Track mouse clicks
local right_UFD_swap   = device_commands.Button_9  -- Track mouse clicks
local left_UFD_swap    = device_commands.Button_10 -- Track mouse clicks
local eject_handle     = device_commands.Button_11 -- Track mouse clicks
local swap_held={}
local decode_swap=dofile(LockOn_Options.script_path.."Systems/Input_Value.lua")

dev:listen_command(UFD_KNOB_mouse)
dev:listen_command(MFD_KNOB_mouse)
dev:listen_command(day_night_switch)
dev:listen_command(right_UFD_swap)
dev:listen_command(left_UFD_swap)
dev:listen_command(10910)
dev:listen_command(83)

dev:listen_command(10017)--DAY NIGHT
dev:listen_command(10018)--DAY NIGHT T

dev:listen_command(10027)--swap bind ufd

function post_initialize()
	swap_held={}
    side:reset()
	mfd_brightness_knob = 1
	ufd_brightness_knob = 1
	--print_message_to_user("AVIONICS SYSTEM POST INIT")
	
	local birth_place = LockOn_Options.init_conditions.birth_place

	if birth_place == "GROUND_COLD" then
		--dev:performClickableAction(right_UFD_swap, 1, false)
		dev:performClickableAction(UFD_KNOB_mouse, 1, false)--remove for release?
		dev:performClickableAction(MFD_KNOB_mouse, 1, false)--remove for release?
	elseif birth_place == "GROUND_HOT" or birth_place == "AIR_HOT" then
		--UFD_KNOB:set(0.5)
		--dispatch_action(nil,Battery)
		dev:performClickableAction(UFD_KNOB_mouse, 1, false)
		dev:performClickableAction(MFD_KNOB_mouse, 1, false)
		dev:performClickableAction(device_commands.Button_5, 0.25, false)
        dev:performClickableAction(device_commands.Button_6, 0.3, false)
		--dev:performClickableAction(right_UFD_swap, 1, false)
		--print_message_to_user("HOT START")
	end
end
local R_UFD_ADI = 1 
local R_UFD_WAR = 0
local function day_night_input(command,value)
    if command~=day_night_switch and command~=10017 and command~=10018 then return end
    if type(value)~='number' or value~=value or math.abs(value)==math.huge then return end
    local position=decode_swap(value,devices.AVIONICS)
    if command==10018 then
        if position>.5 and position<=1 then day_night=1-day_night end
    elseif position==0 or position==1 then day_night=position end
end
function SetCommand(command,value)
	if command == MFD_KNOB_mouse then
		mfd_brightness_knob = math.max(0, math.min(1, value))
	elseif command == UFD_KNOB_mouse then
		ufd_brightness_knob = math.max(0, math.min(1, value))
	end
	--Eject handle
	if command == eject_handle then
		dispatch_action(nil,83)
		print_message_to_user("EJECT!!!")
	end
    day_night_input(command,value)
    if command==left_UFD_swap or command==right_UFD_swap or command==10027 or command==10910 then
        if type(value)~='number' or value~=value or math.abs(value)==math.huge then return end
        local down=decode_swap(value,devices.AVIONICS)>.5
        local old=swap_held[command];swap_held[command]=down
        if down and not old then
            R_UFD_ADI=1-R_UFD_ADI;R_UFD_WAR=1-R_UFD_ADI
        end
        return
    end
end

function update()
    engine_indications:update()
    altitude_physical:update()
    altitude_frame:update(altitude_physical.generation,altitude_physical.valid,Altitude.clock())
    baro_current:set(altitude_frame.sources.BARO.valid and 1 or 0)
    local side_current=side:update(altitude_physical,altitude_frame,Altitude.clock())
	startup_diagnostic_ticks = startup_diagnostic_ticks + 1
	--print_message_to_user(parameters.FLAPS_DOWN:get())

	--Fix for flaps down light
	local flapPosL = get_aircraft_draw_argument_value(10)
	local flapPosR = get_aircraft_draw_argument_value(9)
	if ((flapPosL + flapPosR) > 1.98) then
		parameters.FLAPS_DOWN:set(1)	
	else
		parameters.FLAPS_DOWN:set(0)	
	end

    -- External and internal quantities come directly from EFM state.
    local fuel_internal_kg = math.max(0.0, parameters.EFM_INTERNAL_FUEL_KG:get())
    local fuel_external_kg = math.max(0.0, parameters.EFM_EXTERNAL_FUEL_KG:get())
    parameters.FUELTANK:set(fuel_external_kg * 2.20462262)

	local MFD_KNOB          = mfd_brightness_knob
	local UFD_KNOB          = ufd_brightness_knob
	local CONSOLE_KNOB      = get_cockpit_draw_argument_value(706)
	local FLOOD_KNOB        = get_cockpit_draw_argument_value(707)
	local CANOPY_ARG        = get_cockpit_draw_argument_value(251)
	local SPD_BRK_ARG       = get_cockpit_draw_argument_value(200)
	local BINGO_ARG         = get_cockpit_draw_argument_value(225)
	local FLAPS_MOVE_ARG    = get_cockpit_draw_argument_value(42)
	local FLAPS_DOWN_ARG    = get_cockpit_draw_argument_value(43)
	local AAR_ARG           = get_cockpit_draw_argument_value(0)
	local L_FIRE_ARG        = get_cockpit_draw_argument_value(126)
	local R_FIRE_ARG        = get_cockpit_draw_argument_value(256)
	local L_GEN_ARG         = get_cockpit_draw_argument_value(207)
	local R_GEN_ARG         = get_cockpit_draw_argument_value(219)
	local HYD_ARG           = get_cockpit_draw_argument_value(208) 
	local OIL_ARG           = get_cockpit_draw_argument_value(220)

	--parameters.UFD_OPACITY  :set(UFD_KNOB)
	--parameters.MFD_OPACITY  :set(MFD_KNOB)
	attitude_references.update()
    local supply=altitude_physical.values
    parameters.HUD_POWER:set(side_current and supply.MAIN_POWER==1 and supply.BATTERY_POWER==1 and 1 or 0)
	if altitude_frame.sources.BARO.valid then parameters.BARO:set(altitude_frame.sources.BARO.value)end
	parameters.FUELL        :set(sensor_data.getTotalFuelWeight() * 0.01 ) -- Working, don't change: 0.36622 
	parameters.FUEL         :set(sensor_data.getTotalFuelWeight() * 2.20462 ) -- Working, don't change: 0.36622
	parameters.FUELT        :set(fuel_external_kg * 2.20462262) -- Working, don't change: 0.36622 **25725 - 17500 = 8225**

	parameters.CANOPY_LIGHT :set(CANOPY_ARG)
	parameters.SPD_BRK_LIGHT:set(SPD_BRK_ARG)	
	parameters.BINGO_LIGHT  :set(BINGO_ARG)	
	-- parameters.FLAPS_DOWN   :set(FLAPS_DOWN_ARG)	
	parameters.FLAPS_MOVE   :set(FLAPS_MOVE_ARG)	
	parameters.AAR_LIGHT    :set(AAR_ARG)	
	parameters.L_FIRE_LIGHT :set(L_FIRE_ARG)	
	parameters.R_FIRE_LIGHT :set(R_FIRE_ARG)	
	parameters.L_GEN_OUT    :set(L_GEN_ARG)	
	parameters.R_GEN_OUT    :set(R_GEN_ARG)

	parameters.OIL_LIGHT    :set(OIL_ARG)
	parameters.HYD_LIGHT    :set(HYD_ARG)
	parameters.DAY_NIGHT    :set(day_night)

    -- Physical alert data and presentation are distinct. MIL-HDBK-87213
    -- guidance distinguishes legibility/brightness from warning content.
    -- Night mode is a bounded gain, NOT subtraction of a fixed 0.9 level.
    local function clamp01(v) return math.max(0, math.min(1, v)) end
    local apu=supply.APU_RPM_STATE
    local apu_available=type(apu)=='number' and apu==apu and apu>=2 and apu<=4
    local electrical_available=side_current and supply.BATTERY_POWER==1
        and (supply.MAIN_POWER==1 or apu_available)
    local night_factor = day_night == 1 and 0.18 or 1.0
    local ufd_brightness = electrical_available and clamp01(UFD_KNOB) * night_factor or 0
    local mfd_brightness = electrical_available and clamp01(MFD_KNOB) * night_factor or 0
    parameters.UFD_OPACITY:set(ufd_brightness)
    get_param_handle('F22_UFD_EW_PAGE'):set(0)
    get_param_handle('F22_UFD_STATUS_PAGE'):set(1)
    parameters.MFD_OPACITY:set(mfd_brightness)
    -- The original UFD pages test these as binary format selectors. Brightness
    -- is applied separately by UFD_OPACITY; dimming the selectors hides alerts.
    parameters.L_WAR_OPACITY:set(electrical_available and R_UFD_ADI == 1 and 1 or 0)
    parameters.R_WAR_OPACITY:set(electrical_available and R_UFD_ADI == 0 and 1 or 0)
    parameters.FLOOD_LIGHT:set(electrical_available and clamp01(FLOOD_KNOB) or 0)
    parameters.PANEL_LIGHT:set(electrical_available and clamp01(CONSOLE_KNOB) or 0)

	-- Day/Night lights
	-- if day_night == 1 then
	-- 	parameters.UFD_OPACITY:set(UFD_KNOB - 0.9)
	-- 	parameters.MFD_OPACITY:set(MFD_KNOB - 0.9)
	-- end	
	-- if parameters.MAIN_POWER:get() == 1 and day_night == 0 then
	-- 	parameters.UFD_OPACITY:set(UFD_KNOB)
	-- 	parameters.MFD_OPACITY:set(MFD_KNOB)
	-- 	parameters.FLOOD_LIGHT:set(FLOOD_KNOB)
	-- 	parameters.PANEL_LIGHT:set(CONSOLE_KNOB)
	-- elseif parameters.MAIN_POWER:get() == 1 and day_night == 1 then
	-- 	parameters.UFD_OPACITY:set(UFD_KNOB - 0.9)
	-- 	parameters.MFD_OPACITY:set(MFD_KNOB - 0.9)
	-- 	parameters.FLOOD_LIGHT:set(FLOOD_KNOB)
	-- 	parameters.PANEL_LIGHT:set(CONSOLE_KNOB)
	-- end

	-- ADI page
	if parameters.MAIN_POWER:get() == 1 and R_UFD_ADI == 1 then
		parameters.R_ADI_OPACITY:set(1)
		parameters.L_ADI_OPACITY:set(0)
	elseif parameters.MAIN_POWER:get() == 1 and R_UFD_ADI == 0 then
		parameters.R_ADI_OPACITY:set(0)
		parameters.L_ADI_OPACITY:set(1)
	elseif  parameters.MAIN_POWER:get() == 0 then
		parameters.R_ADI_OPACITY:set(0)
		parameters.L_ADI_OPACITY:set(0)
		parameters.PMFD_MASK:set(0)
		parameters.LMFD_MASK:set(0)
		parameters.RMFD_MASK:set(0)
	end	

	--APU SPOOL
	if parameters.APU_POWER:get() == 0 and parameters.APU_RPM_STATE:get() > 0.10 and parameters.APU_RPM_STATE:get() < 3.80 then
		parameters.APU_SPOOL:set(1)
		parameters.APU_READY:set(0)
		--print_message_to_user("APU SPOOLING UP")
	elseif parameters.APU_POWER:get()==1 and parameters.APU_RPM_STATE:get()>.10
        and parameters.APU_RPM_STATE:get()<3.80 then
		parameters.APU_SPOOL:set(1)
		parameters.APU_READY:set(0)
		--print_message_to_user("APU SPOOLING DOWN")			
	elseif parameters.APU_POWER:get() == 1 then
		parameters.APU_SPOOL:set(0)	
		parameters.APU_READY:set(1)
		--print_message_to_user("APU READY")
	else 
		parameters.APU_SPOOL:set(0)
		parameters.APU_READY:set(0)
	end
	--GEN OUT LIGHT FORCE
	if left_rpm_valid:get()==1 and parameters.L_GEN_POWER:get() == 0
        and parameters.RPM_L:get() >= 40 and sensor_data.getWOW_NoseLandingGear() == 1 then
		parameters.L_GEN_OUT:set(1)

	end
	--GEN OUT LIGHT FORCE
	if right_rpm_valid:get()==1 and parameters.R_GEN_POWER:get() == 0
        and parameters.RPM_R:get() >= 40 and sensor_data.getWOW_NoseLandingGear() == 1 then
		parameters.R_GEN_OUT:set(1)

	end
	--HYD LIGHT FORCE
	if parameters.L_HYD_COLOR:get() == 1 or parameters.R_HYD_COLOR:get() == 1 then
		parameters.HYD_LIGHT:set(1)

	end
	--OIL LIGHT FORCE
	if parameters.L_OIL_COLOR:get() == 1 or parameters.R_OIL_COLOR:get() == 1 then
		parameters.OIL_LIGHT:set(1)

	end
    local attention = fault_registry_ready:get()==1 and master_attention:get()==1
    parameters.CAUTION_LIGHT:set(attention and 1 or 0)
    -- Turning the UFD brightness to zero must never erase fault/alert state.
    -- The display and annunciator surfaces observe the state through opacity.
    if ufd_brightness <= 0 then
        parameters.R_WAR_OPACITY:set(0)
        parameters.L_WAR_OPACITY:set(0)
        parameters.R_ADI_OPACITY:set(0)
        parameters.L_ADI_OPACITY:set(0)
    end

	if MFD_KNOB == 0 then
		parameters.LMFD_MASK:set(0)
		parameters.RMFD_MASK:set(0)
		parameters.PMFD_MASK:set(0)
	end
	if parameters.BATTERY_POWER:get() == 0 then
		parameters.R_ADI_OPACITY:set(0)
		parameters.R_WAR_OPACITY:set(0)
		parameters.L_ADI_OPACITY:set(0)
		parameters.L_WAR_OPACITY:set(0)
		parameters.UFD_OPACITY:set(0)
		parameters.MFD_OPACITY:set(0)
		parameters.FLOOD_LIGHT:set(0)
		parameters.PANEL_LIGHT:set(0)
		parameters.ICP_OPACITY:set(0)
	end
	if startup_diagnostic_ticks == 100 and log and log.write then
		log.write("F22_DISPLAYS", log.INFO, string.format(
			"startup battery=%.0f main=%.0f efm_valid=%.0f rpm_l=%.1f rpm_r=%.1f hud=%.0f mfd=%.2f ufd=%.2f",
			parameters.BATTERY_POWER:get(), parameters.MAIN_POWER:get(),
			get_param_handle("EFM_ENGINE_VALID"):get(),
			get_param_handle("EFM_ENGINE_LEFT_RPM_PCT"):get(),
			get_param_handle("EFM_ENGINE_RIGHT_RPM_PCT"):get(),
			parameters.HUD_POWER:get(), parameters.MFD_OPACITY:get(), parameters.UFD_OPACITY:get()))
	end
end

need_to_be_closed = false
