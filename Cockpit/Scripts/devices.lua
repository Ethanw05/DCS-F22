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


local count = 0
local function counter()
	count = count + 1
	return count
end
-------DEVICE ID-------
devices = {}
devices["AVIONICS"]				= counter()--01
devices["ELECTRICAL_SYSTEM"]	= counter()--02
devices["ENGINE_SYSTEM"]		= counter()--03
devices["WEAPON_SYSTEM"]		= counter()--04
devices["MFD_SYSTEM"]			= counter()--05
devices["PMFD_SYSTEM"]			= counter()--06
devices["ICP_SYSTEM"]			= counter()--07
devices["NAV_SYSTEM"]           = counter()--08: mission route / HUD steering
devices["AG_MARK_SYSTEM"]       = counter()--09: terrain-backed designated markpoint
devices["RADAR_DATA_BRIDGE"]     = counter()--10: compatible, read-only STT telemetry bridge
devices["AG_BALLISTIC_COMPUTER"] = counter()--11: non-authoritative point-mass impact estimate
devices["HUD_FLIGHT_DATA"] = counter()--12: independent flight/velocity HUD producer
devices["RADAR_NATIVE"] = counter()--13: dedicated clock for owned C++ AESA scene sensor
devices["RADAR_COMPUTER"] = counter()--14: own radar mode, cursor and track files
devices["WEAPON_NATIVE"] = counter()--15: DCS shared payload, cannon and seeker
devices["COMBAT_SYSTEM"] = counter()--16: single HOTAS/master-mode router
devices["RWR_NATIVE"] = counter()--17: independent shared DCS passive receiver
devices["RWR_SYSTEM"] = counter()--18: warnings, threat memory and fusion exports

devices["ENGAGEMENT_SYSTEM"] = counter()--19: per-target launch zones and native missile flyout
devices["EW_SYSTEM"] = counter()--20: own countermeasure and ECM controls
devices["MWS_NATIVE"] = counter()--21: common optical missile detector
devices["MWS_SYSTEM"] = counter()--22: independent missile warning and audio
devices["TACAN_NATIVE"] = counter()--23: common TACAN receiver
devices["ILS_NATIVE"] = counter()--24: common ILS receiver
devices["FLIGHT_GUIDANCE"] = counter()--25: navigation/AFCS control and annunciation
devices["NAV_POWER_NATIVE"] = counter()--26: common native navigation electrical buses
devices["ALTITUDE_SYSTEM"] = counter()--27: native altimetry request and warning-floor settings
devices["PILOT_WARNING_SYSTEM"] = counter()--28: terrain/floor/control cautions and original voice

devices["GUN_SYSTEM"] = counter()--29: independent fire-control aiming cadence
